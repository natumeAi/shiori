import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/server_endpoint.dart';
import 'package:shiori/core/config/server_key.dart';
import 'package:shiori/core/storage/app_directories.dart';
import 'package:shiori/core/storage/server_record.dart';
import 'package:shiori/core/storage/sqlite_store.dart';
import 'package:shiori/core/storage/sqlite_store_test_hooks.dart';
import 'package:shiori/core/storage/storage_exception.dart';
import 'package:shiori/core/storage/stored_snapshot.dart';
import 'package:sqlite3/sqlite3.dart';

TypeMatcher<StorageException> failure(StorageFailure value) =>
    isA<StorageException>().having((error) => error.failure, 'failure', value);

final testTime = DateTime.utc(2026, 10, 26, 12);
final serverA = ServerKey(
  ServerEndpoint.parse('https://a.example.test/').endpoint!,
);
final serverB = ServerKey(
  ServerEndpoint.parse('https://b.example.test/Reader/').endpoint!,
);

ServerRecord record(ServerKey key, {DateTime? at}) =>
    ServerRecord(key: key, createdAt: testTime, lastUsedAt: at ?? testTime);

StoredSnapshot snapshot(
  int revision, {
  String? etag = 'W/"opaque"',
}) => StoredSnapshot(
  payload:
      '{"snapshot":{"schemaVersion":1,"version":$revision,"books":[],"folders":[],"shelf":[],"recent":[]}}',
  schemaVersion: 1,
  revision: revision,
  fetchedAt: testTime,
  etag: etag,
);

final class StoreFixture implements AppDirectories {
  StoreFixture(this.support);

  final Directory support;
  final stores = <SqliteStore>[];
  File get file => File.fromUri(support.uri.resolve(SqliteStore.relativePath));

  Future<SqliteStore> open({SqliteStoreTestHooks? hooks}) async {
    final store = await SqliteStore.open(this, testHooks: hooks);
    stores.add(store);
    return store;
  }

  // Fixture inspection uses a connection only before opening/after closing the
  // store. Product commands are always exercised through the worker's ports.
  void inspect(void Function(Database db) action) {
    file.parent.createSync(recursive: true);
    final db = sqlite3.open(file.path);
    try {
      action(db);
    } finally {
      db.close();
    }
  }

  Future<void> dispose() async {
    for (final store in stores) {
      await store.close();
    }
    await support.delete(recursive: true);
  }

  @override
  Future<Directory> applicationSupport() async => support;
  @override
  Future<Directory> documents() =>
      throw StateError('Documents must not be used');
  @override
  Future<Directory> caches() => throw StateError('Caches must not be used');
}
