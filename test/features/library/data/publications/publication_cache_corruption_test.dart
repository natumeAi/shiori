import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/features/library/data/publications/publication_cache_exception.dart';
import 'package:shiori/features/library/data/publications/publication_cache_hooks.dart';

import 'cache_test_support.dart';

void main() {
  test(
    'unleased corrupt destination is removed and republished at digest path',
    () async {
      final f = await CacheFixture.create();
      addTearDown(f.dispose);
      final key = BookKey(serverA, 7);
      final old = await f.publish(key, 'valid');
      await f.file(old).writeAsString('wrong');
      await f.store.deleteGeneration(
        key,
        old.sha256,
      ); // An unreferenced destination.
      final next = await f.publish(key, 'valid');
      expect(next.relativePath, old.relativePath);
      expect(f.file(next).readAsStringSync(), 'valid');
    },
  );

  test('recovery path survives restart and repeated unchanged refresh', () async {
    final f = await CacheFixture.create();
    addTearDown(f.dispose);
    final key = BookKey(serverA, 7);
    final old = await f.publish(key, 'valid');
    final lease = (await f.cache.acquireHead(f.session, key))!;
    await f.file(old).writeAsString('wrong');
    final next = await f.publish(key, 'valid');
    // A late report about the old physical file cannot retire the repaired row.
    await f.cache.markCorrupt(lease);
    expect(
      (await f.store.readPublicationHead(key))!.relativePath,
      next.relativePath,
    );
    lease.release();
    await f.cache.reconcile();
    f.cache.dispose();
    await f.store.close();
    f.store = await f.database.open();
    await f.openCache();
    final restored = (await f.cache.acquireHead(f.session, key))!;
    expect(restored.generation.relativePath, next.relativePath);
    expect(await File(restored.local.path).readAsString(), 'valid');
    final refreshed = await f.publish(key, 'valid');
    expect(refreshed.relativePath, next.relativePath);
    expect(f.file(refreshed).readAsStringSync(), 'valid');
    restored.release();
  });

  test(
    'failed corruption cleanup is retained and explicit reconciliation retries',
    () async {
      var fail = false;
      final f = await CacheFixture.create(
        hooks: PublicationCacheHooks(
          delete: (file) async {
            if (fail) {
              throw const FileSystemException('injected cleanup failure');
            }
            await file.delete();
          },
        ),
      );
      addTearDown(f.dispose);
      final key = BookKey(serverA, 7);
      final old = await f.publish(key, 'valid');
      final lease = (await f.cache.acquireHead(f.session, key))!;
      await f.file(old).writeAsString('wrong');
      final next = await f.publish(key, 'valid');
      fail = true;
      lease.release();
      await expectLater(
        f.cache.reconcile(),
        throwsA(cacheFailure(PublicationCacheFailure.storage)),
      );
      expect(f.file(old).readAsStringSync(), 'wrong');
      expect(f.file(next).readAsStringSync(), 'valid');
      fail = false;
      await f.cache.reconcile();
      expect(f.file(old).existsSync(), isFalse);
      expect(
        (await f.store.readPublicationHead(key))!.relativePath,
        next.relativePath,
      );
    },
  );
}
