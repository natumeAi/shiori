import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/storage/sqlite_store.dart';
import 'package:shiori/core/storage/sqlite_store_test_hooks.dart';
import 'package:shiori/core/storage/storage_exception.dart';
import 'package:sqlite3/sqlite3.dart';

import 'store_test_support.dart';

void main() {
  late StoreFixture fixture;
  setUp(() async {
    fixture = StoreFixture(
      await Directory.systemTemp.createTemp('shiori-store-'),
    );
    addTearDown(fixture.dispose);
  });

  test('fresh create and reopen retain configuration and snapshot', () async {
    final store = await fixture.open();
    expect(await store.runsOffRootForTesting(), isTrue);
    expect(await store.readActiveServer(), isNull);
    await store.commitActivation(record(serverA), snapshot(7));
    await store.close();
    expect(fixture.file.existsSync(), isTrue);
    fixture.inspect((db) {
      expect(db.userVersion, SqliteStore.schemaVersion);
      expect(db.select('PRAGMA journal_mode').single.values.single, 'delete');
      expect(db.select('PRAGMA synchronous').single.values.single, 2);
      expect(
        db.select('SELECT schema_version FROM app_state').single.values.single,
        SqliteStore.schemaVersion,
      );
      expect(
        db
            .select("SELECT name FROM sqlite_schema WHERE type = 'table'")
            .map((row) => row['name']),
        unorderedEquals([
          'servers',
          'app_state',
          'library_snapshots',
          'cached_publications',
          'book_cache_heads',
        ]),
      );
    });
    final reopened = await fixture.open();
    expect((await reopened.readActiveServer())!.key, serverA);
    expect(
      (await reopened.readSnapshot(serverA))!.payload,
      snapshot(7).payload,
    );
    expect((await reopened.readSnapshot(serverA))!.etag, 'W/"opaque"');
  });

  test('v0 migration preserves unrelated sentinel table and rows', () async {
    fixture.inspect((db) {
      db.execute('CREATE TABLE sentinel (value TEXT)');
      db.execute('INSERT INTO sentinel VALUES (?)', ['preserve']);
    });
    await (await fixture.open()).close();
    fixture.inspect((db) {
      expect(db.userVersion, SqliteStore.schemaVersion);
      expect(
        db.select('SELECT value FROM sentinel').single['value'],
        'preserve',
      );
    });
  });

  test(
    'injected failure rolls back DDL and version bump, permits retry',
    () async {
      fixture.inspect((db) {
        db.execute('CREATE TABLE sentinel (value TEXT)');
        db.execute('INSERT INTO sentinel VALUES (?)', ['preserve']);
      });
      await expectLater(
        fixture.open(hooks: const SqliteStoreTestHooks(failMigration: true)),
        throwsA(failure(StorageFailure.migration)),
      );
      fixture.inspect((db) {
        expect(db.userVersion, 0);
        expect(
          db
              .select("SELECT name FROM sqlite_schema WHERE type = 'table'")
              .map((row) => row['name']),
          ['sentinel'],
        );
        expect(
          db.select('SELECT value FROM sentinel').single['value'],
          'preserve',
        );
      });
      await (await fixture.open()).close();
      fixture.inspect(
        (db) => expect(db.userVersion, SqliteStore.schemaVersion),
      );
    },
  );

  test('real migration SQL failure rolls back without resetting v0', () async {
    fixture.inspect((db) {
      db.execute('CREATE TABLE app_state (sentinel TEXT)');
      db.execute('INSERT INTO app_state VALUES (?)', ['untouched']);
    });
    await expectLater(
      fixture.open(),
      throwsA(failure(StorageFailure.migration)),
    );
    fixture.inspect((db) {
      expect(db.userVersion, 0);
      expect(
        db.select('SELECT sentinel FROM app_state').single['sentinel'],
        'untouched',
      );
      expect(
        db.select("SELECT name FROM sqlite_schema WHERE name = 'servers'"),
        isEmpty,
      );
    });
  });

  for (final journal in ['delete', 'wal']) {
    test('future $journal schema refused with identical bytes', () async {
      fixture.inspect((db) {
        db.execute('PRAGMA journal_mode = $journal');
        db.execute('CREATE TABLE sentinel (value TEXT)');
        db.execute('INSERT INTO sentinel VALUES (?)', ['preserve']);
        db.userVersion = 42;
      });
      final before = fixture.file.readAsBytesSync();
      final filesBefore = fixture.file.parent
          .listSync()
          .map((file) => file.path)
          .toList();
      await expectLater(
        fixture.open(),
        throwsA(
          failure(StorageFailure.newerSchema)
              .having((error) => error.schemaVersion, 'version', 42),
        ),
      );
      expect(fixture.file.readAsBytesSync(), orderedEquals(before));
      expect(
        fixture.file.parent.listSync().map((file) => file.path),
        unorderedEquals(filesBefore),
      );
    });
  }

  test('corrupt open preserves file and exposes no native cause', () async {
    fixture.file.parent.createSync(recursive: true);
    fixture.file.writeAsBytesSync(List.filled(200, 17));
    final before = fixture.file.readAsBytesSync();
    await expectLater(fixture.open(), throwsA(failure(StorageFailure.open)));
    expect(fixture.file.readAsBytesSync(), orderedEquals(before));
  });

  test(
    'newer version committed only in WAL preserves main and WAL bytes',
    () async {
      _seedRetainedWal(fixture, version: 42);
      final wal = File('${fixture.file.path}-wal');
      final before = fixture.file.readAsBytesSync();
      final walBefore = wal.readAsBytesSync();
      final entries = fixture.file.parent
          .listSync()
          .map((entry) => entry.path)
          .toList();
      await expectLater(
        fixture.open(),
        throwsA(
          failure(StorageFailure.newerSchema)
              .having((error) => error.schemaVersion, 'version', 42),
        ),
      );
      expect(fixture.file.readAsBytesSync(), orderedEquals(before));
      expect(wal.readAsBytesSync(), orderedEquals(walBefore));
      expect(
        fixture.file.parent.listSync().map((entry) => entry.path),
        unorderedEquals(entries),
      );
    },
  );

  test('supported retained WAL recovers before v0 migration', () async {
    _seedRetainedWal(fixture, version: 0);
    await (await fixture.open()).close();
    fixture.inspect((db) {
      expect(db.userVersion, SqliteStore.schemaVersion);
      expect(db.select('PRAGMA journal_mode').single.values.single, 'delete');
      expect(
        db.select('SELECT value FROM sentinel').single.values.single,
        'retained WAL',
      );
    });
  });

  test(
    'malformed current schema fails open without recreating missing tables',
    () async {
      await (await fixture.open()).close();
      fixture.inspect((db) => db.execute('DROP TABLE library_snapshots'));
      final before = fixture.file.readAsBytesSync();
      await expectLater(fixture.open(), throwsA(failure(StorageFailure.open)));
      expect(fixture.file.readAsBytesSync(), orderedEquals(before));
    },
  );
  test(
    'schema enforces singleton, parents and validated cache heads',
    () async {
      final store = await fixture.open();
      await store.commitActivation(record(serverA), snapshot(7));
      await store.close();
      fixture.inspect((db) {
        db.execute('PRAGMA foreign_keys = ON');
        expect(
          () => db.execute(
            'INSERT INTO app_state (id, schema_version) VALUES (?, ?)',
            [2, 1],
          ),
          throwsA(isA<SqliteException>()),
        );
        expect(
          () => db.execute('DELETE FROM servers WHERE server_key = ?', [
            serverA.value,
          ]),
          throwsA(isA<SqliteException>()),
        );
        final digest = 'a' * 64;
        db.execute(
          '''INSERT INTO cached_publications
        (server_key, book_id, byte_digest, relative_path, actual_bytes,
         parser_version, validation_status, accessed_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
          [serverA.value, 1, digest, 'a/content.epub', 12, 1, 'invalid', 0],
        );
        expect(
          () => db.execute(
            '''INSERT INTO book_cache_heads
        (server_key, book_id, byte_digest) VALUES (?, ?, ?)''',
            [serverA.value, 1, digest],
          ),
          throwsA(isA<SqliteException>()),
        );
        db.execute(
          'UPDATE cached_publications SET validation_status = ? WHERE server_key = ?',
          ['validated', serverA.value],
        );
        db.execute(
          '''INSERT INTO book_cache_heads
        (server_key, book_id, byte_digest) VALUES (?, ?, ?)''',
          [serverA.value, 1, digest],
        );
        expect(
          () => db.execute(
            'DELETE FROM cached_publications WHERE server_key = ?',
            [serverA.value],
          ),
          throwsA(isA<SqliteException>()),
        );
        expect(db.select('PRAGMA foreign_key_check'), isEmpty);
        expect(
          db
              .select('SELECT revision FROM library_snapshots')
              .single
              .values
              .single,
          7,
        );
      });
    },
  );
}

void _seedRetainedWal(StoreFixture fixture, {required int version}) {
  final seed = File.fromUri(fixture.support.uri.resolve('seed.db'));
  final db = sqlite3.open(seed.path);
  try {
    db.execute('PRAGMA journal_mode = WAL');
    db.execute('PRAGMA wal_autocheckpoint = 0');
    db.execute('CREATE TABLE sentinel (value TEXT)');
    db.execute('INSERT INTO sentinel VALUES (?)', ['retained WAL']);
    db.userVersion = version;
    fixture.file.parent.createSync(recursive: true);
    // Copy before closing/checkpointing the seed to simulate a retained WAL.
    seed.copySync(fixture.file.path);
    File('${seed.path}-wal').copySync('${fixture.file.path}-wal');
  } finally {
    db.close();
  }
}
