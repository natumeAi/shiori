import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/storage/storage_exception.dart';
import 'package:shiori/core/storage/sqlite_store.dart';
import 'package:sqlite3/sqlite3.dart';

import 'store_test_support.dart';

void main() {
  late StoreFixture fixture;
  setUp(() async {
    fixture = StoreFixture(
      await Directory.systemTemp.createTemp('shiori-recovery-'),
    );
    addTearDown(fixture.dispose);
  });

  test(
    'hot rollback journal refuses recovered future schema without mutation',
    () async {
      _seedHotJournal(fixture, committedVersion: 42, pendingVersion: 0);
      final before = _files(fixture);
      await expectLater(
        fixture.open(),
        throwsA(
          failure(StorageFailure.newerSchema)
              .having((error) => error.schemaVersion, 'version', 42),
        ),
      );
      final after = _files(fixture);
      expect(after.keys, unorderedEquals(before.keys));
      for (final path in before.keys) {
        expect(after[path], orderedEquals(before[path]!));
      }
    },
  );

  test(
    'uncommitted future version rolls back before supported migration',
    () async {
      _seedHotJournal(fixture, committedVersion: 0, pendingVersion: 42);
      await (await fixture.open()).close();
      fixture.inspect((db) {
        expect(db.userVersion, SqliteStore.schemaVersion);
        expect(
          db.select('SELECT value FROM sentinel').single.values.single,
          'committed',
        );
        expect(db.select('SELECT COUNT(*) FROM spill').single.values.single, 0);
      });
    },
  );
}

Map<String, List<int>> _files(StoreFixture fixture) => {
  for (final file in fixture.file.parent.listSync().whereType<File>())
    file.path: file.readAsBytesSync(),
};

void _seedHotJournal(
  StoreFixture fixture, {
  required int committedVersion,
  required int pendingVersion,
}) {
  final seed = File.fromUri(fixture.support.uri.resolve('journal-seed.db'));
  final db = sqlite3.open(seed.path);
  try {
    db.execute('PRAGMA journal_mode = DELETE');
    db.execute('PRAGMA synchronous = FULL');
    db.execute('PRAGMA cache_size = 1');
    db.execute('CREATE TABLE sentinel (value TEXT)');
    db.execute('CREATE TABLE spill (value TEXT)');
    db.execute('INSERT INTO sentinel VALUES (?)', ['committed']);
    db.userVersion = committedVersion;
    db.execute('BEGIN IMMEDIATE');
    db.userVersion = pendingVersion;
    db.execute('UPDATE sentinel SET value = ?', ['uncommitted']);
    // Force dirty pages out to the main file and a synced journal header.
    for (var i = 0; i < 20; i++) {
      db.execute('INSERT INTO spill VALUES (?)', ['x' * 10000]);
    }
    fixture.file.parent.createSync(recursive: true);
    seed.copySync(fixture.file.path);
    final journal = File('${seed.path}-journal');
    expect(journal.readAsBytesSync().take(8), [
      217,
      213,
      5,
      249,
      32,
      161,
      99,
      215,
    ]);
    journal.copySync('${fixture.file.path}-journal');
  } finally {
    db.execute('ROLLBACK');
    db.close();
  }
}
