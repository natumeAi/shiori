import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/core/config/server_key.dart';
import 'package:shiori/core/config/server_endpoint.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/core/config/session_publication_guard.dart';
import 'package:shiori/core/storage/app_directories.dart';
import 'package:shiori/core/storage/cache_budget.dart';
import 'package:shiori/core/storage/sqlite_store.dart';
import 'package:shiori/core/storage/sqlite_store_test_hooks.dart';
import 'package:shiori/core/storage/stored_publication.dart';
import 'package:shiori/features/library/data/publications/download_result.dart';
import 'package:shiori/features/library/data/publications/publication_cache.dart';
import 'package:shiori/features/library/data/publications/publication_cache_exception.dart';
import 'package:shiori/features/library/data/publications/publication_cache_hooks.dart';
import 'package:shiori/features/library/data/publications/publication_staging.dart';

import '../../../../core/storage/store_test_support.dart';

export '../../../../core/storage/store_test_support.dart'
    show serverA, serverB, testTime;

TypeMatcher<PublicationCacheException> cacheFailure(
  PublicationCacheFailure value,
) =>
    isA<PublicationCacheException>().having((e) => e.failure, 'failure', value);

final class CacheFixture implements AppDirectories {
  CacheFixture._(this.root, this.database);
  final Directory root;
  final StoreFixture database;
  late SqliteStore store;
  late PublicationStaging staging;
  late PublicationCache cache;
  final guard = SessionPublicationGuard();
  late ServerSession session;
  DateTime time = testTime;
  int limit = 512 * 1024 * 1024;

  static Future<CacheFixture> create({
    int limit = 512 * 1024 * 1024,
    PublicationCacheHooks? hooks,
    SqliteStoreTestHooks? storeHooks,
  }) async {
    final root = await Directory.systemTemp.createTemp('publication-cache-');
    final fixture = CacheFixture._(
      root,
      StoreFixture(await Directory('${root.path}/support').create()),
    );
    fixture.limit = limit;
    await Directory('${root.path}/caches').create();
    fixture.store = await fixture.database.open(hooks: storeHooks);
    await fixture.store.commitActivation(record(serverA), snapshot(7));
    await fixture.store.upsertServer(record(serverB));
    await fixture.store.replaceSnapshot(serverB, snapshot(8));
    fixture.staging = PublicationStaging(fixture);
    fixture.select(serverA);
    await fixture.openCache(hooks: hooks);
    return fixture;
  }

  void select(ServerKey key) {
    guard.retire();
    session = guard.createSession(
      ServerEndpoint.parse(key.canonicalRoot).endpoint!,
    );
    guard.select(session);
  }

  Future<void> openCache({PublicationCacheHooks? hooks}) async {
    cache = await PublicationCache.open(
      store: store,
      staging: staging,
      guard: guard,
      budget: CacheBudget(limit: limit),
      now: () => time,
      hooks: hooks,
    );
  }

  Future<StagedDownload> stage(BookKey key, String text) async {
    final file = await staging.create();
    final bytes = utf8.encode(text);
    final writer = await file.open();
    await writer.write(bytes);
    await writer.flush();
    await writer.close();
    return StagedDownload(
      key: key,
      file: file,
      byteLength: bytes.length,
      digest: sha256.convert(bytes).toString(),
      etag: 'W/"exact"',
      lastModified: null,
    );
  }

  Future<StoredPublication> publish(BookKey key, String text) async {
    final attempt = await cache.beginPreparation(session, key);
    try {
      return await cache.publish(
        attempt,
        await stage(key, text),
        parserVersion: 2,
        canonicalVersion: 1,
      );
    } finally {
      attempt.close();
    }
  }

  File file(StoredPublication p) =>
      File('${root.path}/caches/${p.relativePath}');
  Future<void> dispose() async {
    cache.dispose();
    await database.dispose();
    await root.delete(recursive: true);
  }

  @override
  Future<Directory> applicationSupport() async => database.support;
  @override
  Future<Directory> caches() async => Directory('${root.path}/caches');
  @override
  Future<Directory> documents() => throw StateError('Never resolve Documents');
}
