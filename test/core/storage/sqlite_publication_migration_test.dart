import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/core/storage/sqlite_store.dart';
import 'package:shiori/core/storage/sqlite_store_test_hooks.dart';
import 'package:shiori/core/storage/storage_exception.dart';

import 'sqlite_publication_commands_test.dart' show generation;
import 'store_test_support.dart';

void main() {
  late StoreFixture fixture;
  final key = BookKey(serverA, 1);
  setUp(() async {
    fixture = StoreFixture(await Directory.systemTemp.createTemp('cache-v1-'));
    addTearDown(fixture.dispose);
    final store = await fixture.open();
    await store.commitActivation(record(serverA), snapshot(7));
    await store.publishGeneration(generation(key, 'a'));
    await store.close();
    // Reconstruct the exact v1 shape using the real migrated schema, retaining
    // its rows, FK constraints and indexes; only v2's added column is removed.
    fixture.inspect((db) {
      db.execute(
        'ALTER TABLE cached_publications DROP COLUMN canonical_version',
      );
      db.userVersion = 1;
      db.execute('UPDATE app_state SET schema_version = 1');
      db.execute('CREATE TABLE reader_state_sentinel (value TEXT)');
      db.execute("INSERT INTO reader_state_sentinel VALUES ('preserve')");
    });
  });

  test(
    'v1 to v2 preserves heads, generations and all durable sentinel rows',
    () async {
      final store = await fixture.open();
      final head = (await store.readPublicationHead(key))!;
      expect(head.sha256, 'a' * 64);
      expect(head.canonicalVersion, 1);
      expect(head.parserVersion, 2);
      expect((await store.readActiveServer())!.key, serverA);
      expect((await store.readSnapshot(serverA))!.payload, snapshot(7).payload);
      await store.close();
      fixture.inspect((db) {
        expect(db.userVersion, SqliteStore.schemaVersion);
        expect(
          db.select('SELECT value FROM reader_state_sentinel').single['value'],
          'preserve',
        );
        expect(db.select('PRAGMA foreign_key_check'), isEmpty);
      });
    },
  );

  test(
    'v1 migration failure rolls back column and schema metadata together',
    () async {
      final before = fixture.file.readAsBytesSync();
      await expectLater(
        fixture.open(hooks: const SqliteStoreTestHooks(failMigration: true)),
        throwsA(failure(StorageFailure.migration)),
      );
      expect(fixture.file.readAsBytesSync(), before);
      fixture.inspect((db) {
        expect(db.userVersion, 1);
        expect(
          db
              .select('PRAGMA table_info(cached_publications)')
              .map((row) => row['name']),
          isNot(contains('canonical_version')),
        );
        expect(
          db
              .select('SELECT schema_version FROM app_state')
              .single['schema_version'],
          1,
        );
        expect(
          db.select('SELECT value FROM reader_state_sentinel').single['value'],
          'preserve',
        );
      });
      await (await fixture.open()).close();
    },
  );
}
