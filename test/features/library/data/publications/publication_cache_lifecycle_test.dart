import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/core/network/request_cancelled.dart';
import 'package:shiori/core/storage/sqlite_store.dart';
import 'package:shiori/features/library/data/publications/publication_cache.dart';
import 'package:shiori/features/library/data/publications/publication_cache_exception.dart';
import 'package:shiori/features/library/data/publications/publication_cache_hooks.dart';
import 'package:shiori/features/library/data/publications/publication_staging.dart';
import 'package:shiori/features/servers/data/server_activation_dependencies.dart';

import 'cache_test_support.dart';

void main() {
  final key = BookKey(serverA, 7);

  test('corrupt lease release uses the replacement cache owner for cleanup', () async {
    final f = await CacheFixture.create();
    addTearDown(f.dispose);
    final p = await f.publish(key, 'old');
    f.cache.dispose();
    final container = ProviderContainer.test(
      overrides: [
        sqliteStoreProvider.overrideWith((ref) async => f.store),
        publicationStagingProvider.overrideWith((ref) => f.staging),
        sessionPublicationGuardProvider.overrideWith((ref) => f.guard),
      ],
      retry: (_, _) => null,
    );
    final cache = await container.read(publicationCacheProvider.future);
    final lease = (await cache.acquireHead(f.session, key))!;
    await f.file(p).writeAsString('bad');
    await cache.markCorrupt(lease);
    container.invalidate(publicationCacheProvider);
    final replacement = await container.read(publicationCacheProvider.future);
    expect(await replacement.acquireHead(f.session, key), isNull);
    expect(f.file(p).readAsStringSync(), 'bad');
    lease.release();
    // A subsequent owner command waits for the cleanup queued by last release.
    expect(await replacement.acquireHead(f.session, key), isNull);
    expect(f.file(p).existsSync(), isFalse);
  });

  test(
    'provider replacement retains container leases, reservations and queue',
    () async {
      final f = await CacheFixture.create();
      addTearDown(f.dispose);
      final p = await f.publish(key, 'old');
      f.cache.dispose();
      final container = ProviderContainer.test(
        overrides: [
          sqliteStoreProvider.overrideWith((ref) async => f.store),
          publicationStagingProvider.overrideWith((ref) => f.staging),
          sessionPublicationGuardProvider.overrideWith((ref) => f.guard),
        ],
        retry: (_, _) => null,
      );
      final cache = await container.read(publicationCacheProvider.future);
      final lease = (await cache.acquireHead(f.session, key))!;
      final reserved = await cache.reserveBytes(cache.budget.limit - 3);
      container.invalidate(publicationCacheProvider);
      final replacement = await container.read(publicationCacheProvider.future);
      expect(identical(cache, replacement), isFalse);
      expect(identical(cache.budget, replacement.budget), isTrue);
      await expectLater(
        replacement.reserveBytes(1),
        throwsA(cacheFailure(PublicationCacheFailure.cacheBusy)),
      );
      expect(f.file(p).readAsStringSync(), 'old');
      lease.release();
      final next = await replacement.reserveBytes(3);
      expect(f.file(p).existsSync(), isFalse);
      reserved.release();
      next.release();
    },
  );

  test(
    'disposed queued publish discards staging even before action admission',
    () async {
      final entered = Completer<void>();
      final proceed = Completer<void>();
      final f = await CacheFixture.create(
        hooks: PublicationCacheHooks(
          atBoundary: (point) async {
            if (point == PublicationCacheBoundary.afterRename) {
              entered.complete();
              await proceed.future;
            }
          },
        ),
      );
      addTearDown(f.dispose);
      final other = BookKey(serverA, 8);
      final first = await f.cache.beginPreparation(f.session, key);
      final second = await f.cache.beginPreparation(f.session, other);
      final publishing = f.cache.publish(
        first,
        await f.stage(key, 'one'),
        parserVersion: 2,
        canonicalVersion: 1,
      );
      final firstFailure = expectLater(
        publishing,
        throwsA(isA<RequestCancelled>()),
      );
      await entered.future;
      final stage = await f.stage(other, 'two');
      final secondFailure = expectLater(
        f.cache.publish(second, stage, parserVersion: 2, canonicalVersion: 1),
        throwsA(isA<RequestCancelled>()),
      );
      f.cache.dispose();
      proceed.complete();
      await firstFailure;
      await secondFailure;
      expect(File(stage.path).existsSync(), isFalse);
      expect(await f.store.readPublicationHead(key), isNull);
      expect(await f.store.readPublicationHead(other), isNull);
      await f.openCache();
      expect((await f.staging.directory()).listSync(), isEmpty);
    },
  );

  test(
    'closing superseding attempt never resurrects an older operation',
    () async {
      final f = await CacheFixture.create();
      addTearDown(f.dispose);
      final first = await f.cache.beginPreparation(f.session, key);
      final second = await f.cache.beginPreparation(f.session, key);
      second.close();
      final third = await f.cache.beginPreparation(f.session, key);
      expect(first.checkCurrent, throwsA(isA<RequestCancelled>()));
      third.checkCurrent();
      first.close();
      third.close();
    },
  );

  test(
    'retirement during acquisition cannot touch LRU or publish a lease',
    () async {
      final f = await CacheFixture.create();
      addTearDown(f.dispose);
      final p = await f.publish(key, 'old');
      f.time = f.time.add(const Duration(seconds: 1));
      final failed = expectLater(
        f.cache.acquireHead(f.session, key),
        throwsA(isA<RequestCancelled>()),
      );
      scheduleMicrotask(f.guard.retire);
      await failed;
      expect(
        (await f.store.readGeneration(key, p.sha256))!.accessedAt,
        p.accessedAt,
      );
      f.select(serverA);
      final reserve = await f.cache.reserveBytes(f.cache.budget.limit);
      expect(f.file(p).existsSync(), isFalse);
      reserve.release();
    },
  );

  test(
    'disposal during quota measurement stops eviction and reservation',
    () async {
      final f = await CacheFixture.create(limit: 3);
      addTearDown(f.dispose);
      final p = await f.publish(key, 'old');
      final failed = expectLater(
        f.cache.reserveBytes(3),
        throwsA(isA<RequestCancelled>()),
      );
      scheduleMicrotask(f.cache.dispose);
      await failed;
      expect(f.file(p).readAsStringSync(), 'old');
      expect((await f.store.readPublicationHead(key))!.sha256, p.sha256);
      expect(f.cache.budget.reservedBytes, 0);
    },
  );
}
