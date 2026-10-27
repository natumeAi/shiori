import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/features/library/data/publications/publication_cache_exception.dart';
import 'package:shiori/features/library/data/publications/publication_cache_hooks.dart';

import 'cache_test_support.dart';

void main() {
  final a = BookKey(serverA, 7);
  final b = BookKey(serverB, 7);
  late CacheFixture f;
  Future<void> create(int limit) async {
    f = await CacheFixture.create(limit: limit);
    addTearDown(f.dispose);
  }

  test(
    'lease survives replacement; last release permits non-head LRU eviction',
    () async {
      await create(9);
      final old = await f.publish(a, 'old');
      final first = (await f.cache.acquireHead(f.session, a))!;
      final second = (await f.cache.acquireHead(f.session, a))!;
      f.time = f.time.add(const Duration(seconds: 1));
      await f.publish(a, 'new');
      expect(File(first.local.path).readAsStringSync(), 'old');
      first.release();
      first.release();
      final headPin = await f.cache.pinHead(a);
      final reserve = await f.cache.reserveBytes(3);
      await expectLater(
        f.cache.reserveBytes(1),
        throwsA(cacheFailure(PublicationCacheFailure.cacheBusy)),
      );
      reserve.release();
      second.release();
      final incoming = await f.cache.reserveBytes(6);
      expect(f.file(old).existsSync(), isFalse);
      expect(await f.store.readGeneration(a, old.sha256), isNull);
      incoming.release();
      headPin!.release();
    },
  );

  test(
    'leased full cache returns cacheBusy without deleting a live file',
    () async {
      await create(3);
      final p = await f.publish(a, 'old');
      final lease = (await f.cache.acquireHead(f.session, a))!;
      await expectLater(
        f.cache.reserveBytes(1),
        throwsA(cacheFailure(PublicationCacheFailure.cacheBusy)),
      );
      expect(f.file(p).readAsStringSync(), 'old');
      lease.release();
      final reservation = await f.cache.reserveBytes(3);
      expect(f.file(p).existsSync(), isFalse);
      expect(await f.store.readPublicationHead(a), isNull);
      reservation.release();
    },
  );

  test(
    'preparation pins previous head before quota admission for entire attempt',
    () async {
      await create(3);
      final old = await f.publish(a, 'old');
      final attempt = await f.cache.beginPreparation(f.session, a);
      final stage = await f.stage(a, 'new');
      await expectLater(
        f.cache.publish(attempt, stage, parserVersion: 2, canonicalVersion: 1),
        throwsA(cacheFailure(PublicationCacheFailure.cacheBusy)),
      );
      expect(f.file(old).readAsStringSync(), 'old');
      expect(attempt.previousHead!.local.digest, old.sha256);
      expect((await f.store.readPublicationHead(a))!.sha256, old.sha256);
      await expectLater(
        f.cache.reserveBytes(1),
        throwsA(cacheFailure(PublicationCacheFailure.cacheBusy)),
      );
      attempt.close();
      final reservation = await f.cache.reserveBytes(3);
      expect(f.file(old).existsSync(), isFalse);
      reservation.release();
    },
  );

  test('explicit pin also blocks eviction and release is idempotent', () async {
    await create(3);
    await f.publish(a, 'old');
    final pin = (await f.cache.pinHead(a))!;
    await expectLater(
      f.cache.reserveBytes(1),
      throwsA(cacheFailure(PublicationCacheFailure.cacheBusy)),
    );
    pin.release();
    pin.release();
    final reservation = await f.cache.reserveBytes(3);
    reservation.release();
  });

  test(
    'global LRU separates same numeric book IDs and honors acquisition touch',
    () async {
      await create(6);
      final pa = await f.publish(a, 'aaa');
      f.time = f.time.add(const Duration(seconds: 1));
      f.select(serverB);
      final pb = await f.publish(b, 'bbb');
      f.time = f.time.add(const Duration(seconds: 1));
      f.select(serverA);
      (await f.cache.acquireHead(f.session, a))!.release();
      final reserve = await f.cache.reserveBytes(3);
      expect(f.file(pa).existsSync(), isTrue);
      expect(f.file(pb).existsSync(), isFalse);
      expect((await f.store.readPublicationHead(a))!.sha256, pa.sha256);
      expect(await f.store.readPublicationHead(b), isNull);
      reserve.release();
    },
  );

  test(
    'individual generation exceeding limit fails recoverably; stage released',
    () async {
      await create(3);
      await expectLater(
        f.publish(a, 'large'),
        throwsA(cacheFailure(PublicationCacheFailure.tooLarge)),
      );
      expect(await f.store.readPublicationHead(a), isNull);
      expect((await f.staging.directory()).listSync(), isEmpty);
      await expectLater(
        f.cache.reserveBytes(4),
        throwsA(cacheFailure(PublicationCacheFailure.tooLarge)),
      );
    },
  );

  test(
    'same digest admission requires no extra quota even with leased head',
    () async {
      await create(3);
      final first = await f.publish(a, 'old');
      final lease = (await f.cache.acquireHead(f.session, a))!;
      final next = await f.publish(a, 'old');
      expect(next.sha256, first.sha256);
      expect(f.file(first).readAsStringSync(), 'old');
      lease.release();
    },
  );

  test('shared reservations hold cover quota and cannot over-admit concurrent calls', () async {
    await create(6);
    final first = await f.cache.reserveBytes(4);
    expect(f.cache.budget.reservedBytes, 4);
    await expectLater(
      f.cache.reserveBytes(3),
      throwsA(cacheFailure(PublicationCacheFailure.cacheBusy)),
    );
    final second = await f.cache.reserveBytes(2);
    first.release();
    first.release();
    expect(f.cache.budget.reservedBytes, 2);
    final third = await f.cache.reserveBytes(4);
    second.release();
    third.release();
    expect(f.cache.budget.reservedBytes, 0);
  });

  test(
    'simultaneous reservations serialize admission against the shared charge',
    () async {
      await create(6);
      final firstFuture = f.cache.reserveBytes(4);
      final secondFailure = expectLater(
        f.cache.reserveBytes(4),
        throwsA(cacheFailure(PublicationCacheFailure.cacheBusy)),
      );
      final first = await firstFuture;
      await secondFailure;
      expect(f.cache.budget.reservedBytes, 4);
      first.release();
    },
  );

  test(
    'orphan after rename stays charged until reconciliation removes it',
    () async {
      await create(6);
      await f.publish(a, 'old');
      f.cache.dispose();
      await f.openCache(
        hooks: PublicationCacheHooks(
          atBoundary: (point) async {
            if (point == PublicationCacheBoundary.afterRename) {
              throw const FileSystemException('crash');
            }
          },
        ),
      );
      await expectLater(
        f.publish(a, 'new'),
        throwsA(isA<PublicationCacheException>()),
      );
      final pin = (await f.cache.pinHead(a))!;
      await expectLater(
        f.cache.reserveBytes(1),
        throwsA(cacheFailure(PublicationCacheFailure.cacheBusy)),
      );
      await f.cache.reconcile();
      final reservation = await f.cache.reserveBytes(3);
      reservation.release();
      pin.release();
    },
  );
}
