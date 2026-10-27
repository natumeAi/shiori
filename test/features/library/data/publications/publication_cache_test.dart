import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/core/network/request_cancelled.dart';
import 'package:shiori/core/storage/sqlite_store_test_hooks.dart';
import 'package:shiori/features/library/data/publications/publication_cache_exception.dart';
import 'package:shiori/features/library/data/publications/publication_cache_hooks.dart';
import 'package:shiori/features/library/data/publications/publication_head_change.dart';

import 'cache_test_support.dart';

void main() {
  final key = BookKey(serverA, 7);
  late CacheFixture f;
  Future<void> create({
    PublicationCacheHooks? hooks,
    SqliteStoreTestHooks? storeHooks,
    int limit = 100,
  }) async {
    f = await CacheFixture.create(
      hooks: hooks,
      storeHooks: storeHooks,
      limit: limit,
    );
    addTearDown(f.dispose);
  }

  test(
    'publish closes stage, commits immutable head and emits digest event',
    () async {
      await create();
      final changes = <PublicationHeadChange>[];
      final sub = f.cache.headChanges.listen(changes.add);
      addTearDown(sub.cancel);
      final first = await f.publish(key, 'old');
      expect(f.file(first).readAsStringSync(), 'old');
      expect(
        first.relativePath,
        'shiori/v1/publications/${serverA.value}/7/${first.sha256}.epub',
      );
      expect((await f.store.readPublicationHead(key))!.sha256, first.sha256);
      expect((await f.staging.directory()).listSync(), isEmpty);
      expect(changes.single.previousDigest, isNull);
      final second = await f.publish(key, 'new');
      expect(changes.last.previousDigest, first.sha256);
      expect(changes.last.newDigest, second.sha256);
      final lease = (await f.cache.acquireHead(f.session, key))!;
      expect(lease.local.digest, second.sha256);
      expect(lease.generation.canonicalVersion, 1);
      expect(lease.generation.parserVersion, 2);
      lease.release();
    },
  );

  test(
    'same digest reuses verified destination while a handle is open',
    () async {
      var renames = 0;
      await create(
        hooks: PublicationCacheHooks(
          rename: (file, path) async {
            renames++;
            await file.rename(path);
          },
        ),
      );
      final changes = <PublicationHeadChange>[];
      final sub = f.cache.headChanges.listen(changes.add);
      addTearDown(sub.cancel);
      final p = await f.publish(key, 'same');
      final handle = await f.file(p).open();
      try {
        final again = await f.publish(key, 'same');
        expect(again.sha256, p.sha256);
        expect(renames, 1);
        expect(await handle.read(4), 'same'.codeUnits);
        expect((await f.store.listPublicationCandidates()).length, 1);
        expect(changes.length, 1);
      } finally {
        await handle.close();
      }
    },
  );

  for (final boundary in ['rename', 'afterRename', 'beforeCommit', 'commit']) {
    test('$boundary failure preserves old head and cleans only own stage', () async {
      var armed = false;
      await create(
        hooks: PublicationCacheHooks(
          rename: (file, path) async {
            if (armed && boundary == 'rename') {
              throw const FileSystemException('disk full');
            }
            await file.rename(path);
          },
          atBoundary: (point) async {
            if (armed && point.name == boundary) {
              throw const FileSystemException('disk full');
            }
          },
        ),
      );
      final old = await f.publish(key, 'old');
      final stage = await f.stage(key, 'new');
      if (boundary == 'commit') {
        f.cache.dispose();
        await f.store.close();
        f.store = await f.database.open(
          hooks: SqliteStoreTestHooks(
            failPublicationCommitDigest: stage.digest,
          ),
        );
        await f.openCache();
      }
      final attempt = await f.cache.beginPreparation(f.session, key);
      armed = true;
      await expectLater(
        f.cache.publish(attempt, stage, parserVersion: 2, canonicalVersion: 1),
        throwsA(cacheFailure(PublicationCacheFailure.storage)),
      );
      attempt.close();
      expect((await f.store.readPublicationHead(key))!.sha256, old.sha256);
      expect(f.file(old).readAsStringSync(), 'old');
      expect(File(stage.path).existsSync(), isFalse);
      expect(await f.store.readGeneration(key, stage.digest), isNull);
      final orphan = File(
        '${f.root.path}/caches/shiori/v1/publications/${serverA.value}/7/${stage.digest}.epub',
      );
      expect(orphan.existsSync(), boundary != 'rename');
      await f.cache.reconcile();
      expect(orphan.existsSync(), isFalse);
      final next = await f.staging.create();
      await next.discard();
    });
  }

  for (final point in [
    PublicationCacheBoundary.afterRename,
    PublicationCacheBoundary.afterCommit,
  ]) {
    test(
      'restart after ${point.name} reconciles reachable head and orphans',
      () async {
        var armed = false;
        await create(
          hooks: PublicationCacheHooks(
            atBoundary: (boundary) async {
              if (armed && boundary == point) {
                throw const FileSystemException('crash');
              }
            },
          ),
        );
        final old = await f.publish(key, 'old');
        armed = true;
        await expectLater(
          f.publish(key, 'new'),
          throwsA(isA<PublicationCacheException>()),
        );
        f.cache.dispose();
        await f.store.close();
        f.store = await f.database.open();
        await f.openCache();
        final head = (await f.cache.acquireHead(f.session, key))!;
        expect(
          File(head.local.path).readAsStringSync(),
          point == PublicationCacheBoundary.afterCommit ? 'new' : 'old',
        );
        expect(f.file(old).existsSync(), isTrue);
        final files = Directory('${f.root.path}/caches/shiori/v1/publications')
            .listSync(recursive: true)
            .whereType<File>();
        expect(
          files.length,
          point == PublicationCacheBoundary.afterCommit ? 2 : 1,
        );
        head.release();
      },
    );
  }

  test('queued acquire cannot see renamed generation before commit', () async {
    final entered = Completer<void>();
    final proceed = Completer<void>();
    await create(
      hooks: PublicationCacheHooks(
        atBoundary: (point) async {
          if (point == PublicationCacheBoundary.beforeCommit) {
            entered.complete();
            await proceed.future;
          }
        },
      ),
    );
    final publishing = f.publish(key, 'new');
    await entered.future;
    expect(await f.store.readPublicationHead(key), isNull);
    var acquired = false;
    final leaseFuture = f.cache.acquireHead(f.session, key).then((value) {
      acquired = true;
      return value;
    });
    await Future<void>.delayed(Duration.zero);
    expect(acquired, isFalse);
    proceed.complete();
    final p = await publishing;
    final lease = (await leaseFuture)!;
    expect(lease.local.digest, p.sha256);
    lease.release();
  });

  test(
    'superseded per-book token discards its stage and preserves head',
    () async {
      await create();
      final old = await f.publish(key, 'old');
      final first = await f.cache.beginPreparation(f.session, key);
      final staged = await f.stage(key, 'stale');
      final second = await f.cache.beginPreparation(f.session, key);
      await expectLater(
        f.cache.publish(first, staged, parserVersion: 2, canonicalVersion: 1),
        throwsA(isA<RequestCancelled>()),
      );
      expect(File(staged.path).existsSync(), isFalse);
      expect((await f.store.readPublicationHead(key))!.sha256, old.sha256);
      first.close();
      second.close();
    },
  );

  test(
    'A to B to A rejects first activation after rename without an event',
    () async {
      var armed = false;
      await create(
        hooks: PublicationCacheHooks(
          atBoundary: (point) async {
            if (armed && point == PublicationCacheBoundary.afterRename) {
              f.select(serverB);
              f.select(serverA);
            }
          },
        ),
      );
      final old = await f.publish(key, 'old');
      final events = <PublicationHeadChange>[];
      final sub = f.cache.headChanges.listen(events.add);
      addTearDown(sub.cancel);
      armed = true;
      await expectLater(
        f.publish(key, 'stale'),
        throwsA(isA<RequestCancelled>()),
      );
      expect((await f.store.readPublicationHead(key))!.sha256, old.sha256);
      expect(events, isEmpty);
      await f.cache.reconcile();
      expect(f.file(old).readAsStringSync(), 'old');
    },
  );

  test(
    'same-length corrupt destination recovers without overwriting a lease',
    () async {
      await create();
      final p = await f.publish(key, 'old');
      final lease = (await f.cache.acquireHead(f.session, key))!;
      await f.file(p).writeAsString('bad');
      final recovered = await f.publish(key, 'old');
      expect(recovered.relativePath, isNot(p.relativePath));
      expect(f.file(recovered).readAsStringSync(), 'old');
      expect(f.file(p).readAsStringSync(), 'bad');
      expect((await f.store.readPublicationHead(key))!.sha256, p.sha256);
      lease.release();
      await f.cache.reconcile();
      expect(f.file(p).existsSync(), isFalse);
      expect(f.file(recovered).readAsStringSync(), 'old');
    },
  );

  test(
    'stage digest or length mismatch never reaches immutable namespace',
    () async {
      await create();
      final attempt = await f.cache.beginPreparation(f.session, key);
      final stage = await f.stage(key, 'old');
      await File(stage.path).writeAsString('bad');
      await expectLater(
        f.cache.publish(attempt, stage, parserVersion: 2, canonicalVersion: 1),
        throwsA(cacheFailure(PublicationCacheFailure.invalidGeneration)),
      );
      expect(await f.store.readPublicationHead(key), isNull);
      expect(File(stage.path).existsSync(), isFalse);
      attempt.close();
    },
  );
}
