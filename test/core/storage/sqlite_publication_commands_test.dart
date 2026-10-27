import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/core/storage/sqlite_store_test_hooks.dart';
import 'package:shiori/core/storage/storage_exception.dart';
import 'package:shiori/core/storage/stored_publication.dart';

import 'store_test_support.dart';

StoredPublication generation(BookKey key, String digest, {DateTime? at}) =>
    StoredPublication(
      key: key,
      sha256: digest * 64,
      byteLength: 10,
      parserVersion: 2,
      canonicalVersion: 3,
      accessedAt: at ?? testTime,
      etag: 'W/"opaque"',
      lastModified: 'unchanged',
    );

void main() {
  late StoreFixture fixture;
  final a = BookKey(serverA, 7);
  final b = BookKey(serverB, 7);
  setUp(() async {
    fixture = StoreFixture(await Directory.systemTemp.createTemp('cache-sql-'));
    addTearDown(fixture.dispose);
  });

  test(
    'atomic generation/head, same digest metadata and durable isolation',
    () async {
      final store = await fixture.open();
      await store.commitActivation(record(serverA), snapshot(7));
      await store.upsertServer(record(serverB));
      await store.replaceSnapshot(serverB, snapshot(8));
      final p = generation(a, 'a');
      await store.publishGeneration(p);
      expect((await store.readPublicationHead(a))!.sha256, p.sha256);
      final read = (await store.readGeneration(a, p.sha256))!;
      expect(read.relativePath, p.relativePath);
      expect(read.canonicalVersion, 3);
      expect(read.parserVersion, 2);
      expect(read.lastModified, 'unchanged');
      await store.publishGeneration(p);
      await store.publishGeneration(generation(a, 'b'));
      expect((await store.listPublicationCandidates()).length, 2);
      expect(await store.readGeneration(b, p.sha256), isNull);
      await store.clearPublicationHead(a, p.sha256); // Conditional stale clear.
      expect((await store.readPublicationHead(a))!.sha256, 'b' * 64);
      await store.deleteGeneration(a, 'a' * 64);
      await store.deleteGeneration(a, 'b' * 64);
      expect(await store.readPublicationHead(a), isNull);
      expect(await store.listPublicationCandidates(), isEmpty);
      expect((await store.readActiveServer())!.key, serverA);
      expect((await store.readServer(serverA))!.lastUsedAt, testTime);
      expect((await store.readSnapshot(serverA))!.payload, snapshot(7).payload);
      expect((await store.readSnapshot(serverB))!.payload, snapshot(8).payload);
    },
  );

  test(
    'cross-server LRU, protected paths, touch and head-only clear',
    () async {
      final store = await fixture.open();
      await store.upsertServer(record(serverA));
      await store.upsertServer(record(serverB));
      final first = generation(a, 'a');
      final second = generation(
        b,
        'b',
        at: testTime.add(const Duration(seconds: 1)),
      );
      await store.publishGeneration(first);
      await store.publishGeneration(second);
      expect((await store.listPublicationCandidates()).map((p) => p.key), [
        a,
        b,
      ]);
      await store.touchGeneration(
        a,
        first.sha256,
        testTime.add(const Duration(seconds: 2)),
      );
      expect((await store.listPublicationCandidates()).map((p) => p.key), [
        b,
        a,
      ]);
      expect(
        (await store.listPublicationCandidates(
          protectedPaths: {second.relativePath},
        )).map((p) => p.key),
        [a],
      );
      await store.clearPublicationHead(b, second.sha256);
      expect(await store.readPublicationHead(b), isNull);
      expect(await store.readGeneration(b, second.sha256), isNotNull);
    },
  );

  test('real COMMIT failure rolls back insert and old head', () async {
    final store = await fixture.open(
      hooks: SqliteStoreTestHooks(failPublicationCommitDigest: 'b' * 64),
    );
    await store.commitActivation(record(serverA), snapshot(7));
    await store.publishGeneration(generation(a, 'a'));
    await expectLater(
      store.publishGeneration(generation(a, 'b')),
      throwsA(failure(StorageFailure.command)),
    );
    expect((await store.readPublicationHead(a))!.sha256, 'a' * 64);
    expect(await store.readGeneration(a, 'b' * 64), isNull);
    // Worker and transaction remain usable after rollback.
    await store.publishGeneration(generation(a, 'c'));
    expect((await store.readPublicationHead(a))!.sha256, 'c' * 64);
    expect((await store.readSnapshot(serverA))!.revision, 7);
  });
}
