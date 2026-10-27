import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/features/library/data/publications/publication_cache_exception.dart';
import 'package:shiori/features/library/data/publications/publication_cache_hooks.dart';

import 'cache_test_support.dart';

void main() {
  final a = BookKey(serverA, 7);
  final b = BookKey(serverA, 8);
  late CacheFixture f;
  setUp(() async {
    f = await CacheFixture.create();
    addTearDown(f.dispose);
  });

  test('missing, length mismatch, orphan and abandoned stage cleanup is cache-only', () async {
    final missing = await f.publish(a, 'missing');
    final mismatch = await f.publish(b, 'mismatch');
    final good = await f.publish(BookKey(serverA, 9), 'good');
    await f.file(missing).delete();
    await f.file(mismatch).writeAsString('short');
    final orphan = await File('${f.file(good).parent.path}/orphan.epub')
        .writeAsString('orphan');
    final abandoned = await File(
      '${(await f.staging.directory()).path}/abandoned.part',
    ).writeAsString('partial');
    final retainedStage = await f.staging.create();
    await File(retainedStage.path).writeAsString('owned');
    final outside = await File('${f.root.path}/caches/unrelated.epub')
        .writeAsString('keep');
    final durable = await File('${f.database.support.path}/sentinel.epub')
        .writeAsString('durable');
    final documents = await Directory('${f.root.path}/Documents').create();
    final exported = await File('${documents.path}/export.epub')
        .writeAsString('export');
    f.cache.dispose();
    await f.openCache(); // Startup automatically reconciles before admission.
    expect(await f.store.readPublicationHead(a), isNull);
    expect(await f.store.readGeneration(a, missing.sha256), isNull);
    expect(await f.store.readPublicationHead(b), isNull);
    expect(await f.store.readGeneration(b, mismatch.sha256), isNull);
    expect(f.file(mismatch).existsSync(), isFalse);
    expect(orphan.existsSync(), isFalse);
    expect(abandoned.existsSync(), isFalse);
    expect(File(retainedStage.path).readAsStringSync(), 'owned');
    expect(f.file(good).readAsStringSync(), 'good');
    expect(outside.readAsStringSync(), 'keep');
    expect(durable.readAsStringSync(), 'durable');
    expect(exported.readAsStringSync(), 'export');
    await retainedStage.discard();
  });

  test(
    'acquire detects OS removal after startup and clears only cache record',
    () async {
      final p = await f.publish(a, 'old');
      await f.file(p).delete();
      expect(await f.cache.acquireHead(f.session, a), isNull);
      expect(await f.store.readPublicationHead(a), isNull);
      expect((await f.store.readActiveServer())!.key, serverA);
      expect((await f.store.readSnapshot(serverA))!.revision, 7);
    },
  );

  test(
    'reconciliation keeps a valid leased non-head generation and a head',
    () async {
      final old = await f.publish(a, 'old');
      final lease = (await f.cache.acquireHead(f.session, a))!;
      final head = await f.publish(a, 'new');
      await f.cache.reconcile();
      expect(f.file(old).readAsStringSync(), 'old');
      expect(f.file(head).readAsStringSync(), 'new');
      lease.release();
    },
  );

  test(
    'startup length-only verification is documented; same-length bytes remain',
    () async {
      final p = await f.publish(a, 'old');
      await f.file(p).writeAsString('bad');
      await f.cache.reconcile();
      expect((await f.store.readPublicationHead(a))!.sha256, p.sha256);
    },
  );

  test(
    'OS removal of publications directory is an empty recoverable cache',
    () async {
      final p = await f.publish(a, 'old');
      // Remove only this test's exact synthetic publication directory.
      final publications = Directory(
        '${f.root.path}/caches/shiori/v1/publications',
      );
      expect(
        publications.absolute.path.startsWith(f.root.absolute.path),
        isTrue,
      );
      await publications.delete(recursive: true);
      await f.cache.reconcile();
      expect(await f.store.readGeneration(a, p.sha256), isNull);
      final next = await f.publish(a, 'new');
      expect(f.file(next).readAsStringSync(), 'new');
    },
  );

  test('closed storage gives content-free typed cache failure', () async {
    await f.store.close();
    await expectLater(
      f.cache.reconcile(),
      throwsA(cacheFailure(PublicationCacheFailure.storage)),
    );
  });

  test(
    'cleanup disk error is typed and retry keeps every outside sentinel',
    () async {
      f.cache.dispose();
      var fail = true;
      await f.openCache(
        hooks: PublicationCacheHooks(
          delete: (file) async {
            if (fail) throw const FileSystemException('cleanup failed');
            await file.delete();
          },
        ),
      );
      final orphan = await File(
        '${f.root.path}/caches/shiori/v1/publications/orphan.epub',
      ).writeAsString('orphan');
      final outside = await File('${f.root.path}/caches/keep.epub')
          .writeAsString('keep');
      await expectLater(
        f.cache.reconcile(),
        throwsA(cacheFailure(PublicationCacheFailure.storage)),
      );
      expect(orphan.readAsStringSync(), 'orphan');
      expect(outside.readAsStringSync(), 'keep');
      fail = false;
      await f.cache.reconcile();
      expect(orphan.existsSync(), isFalse);
      expect(outside.readAsStringSync(), 'keep');
    },
  );

  test(
    'legacy invalid, empty and outside-path rows clear without following paths',
    () async {
      final p = await f.publish(a, 'old');
      f.cache.dispose();
      await f.store.close();
      final outside = await File('${f.database.support.path}/private.epub')
          .writeAsString('private');
      f.database.inspect((db) {
        db.execute('UPDATE cached_publications SET relative_path = ?', [
          outside.path,
        ]);
        db.execute(
          '''INSERT INTO cached_publications
        (server_key, book_id, byte_digest, relative_path, actual_bytes,
         parser_version, validation_status, accessed_at)
        VALUES (?, 8, ?, ?, 0, 1, 'invalid', 0)''',
          [serverA.value, 'a' * 64, '../../private.epub'],
        );
      });
      f.store = await f.database.open();
      await f.openCache();
      expect(await f.store.listPublicationCandidates(), isEmpty);
      expect(await f.store.readPublicationHead(a), isNull);
      expect(f.file(p).existsSync(), isFalse);
      expect(outside.readAsStringSync(), 'private');
    },
  );

  test('all cache transitions preserve exact durable rows and future reader sentinel', () async {
    f.cache.dispose();
    await f.store.close();
    const tables = [
      'servers',
      'app_state',
      'library_snapshots',
      'reader_state_sentinel',
    ];
    final before = <String, Object>{};
    f.database.inspect((db) {
      db.execute('CREATE TABLE reader_state_sentinel (id INTEGER, value TEXT)');
      db.execute(
        "INSERT INTO reader_state_sentinel VALUES (7, 'accepted-position')",
      );
      for (final table in tables) {
        before[table] = db
            .select('SELECT * FROM $table ORDER BY 1')
            .map((row) => row.values.toList())
            .toList();
      }
    });
    f.store = await f.database.open();
    await f.openCache();
    final old = await f.publish(a, 'old');
    final lease = (await f.cache.acquireHead(f.session, a))!;
    await f.publish(a, 'new');
    await f.cache.reconcile();
    expect(f.file(old).readAsStringSync(), 'old');
    lease.release();
    final reservation = await f.cache.reserveBytes(f.cache.budget.limit);
    reservation.release();
    final missing = await f.publish(b, 'missing');
    await f.file(missing).delete();
    await f.cache.reconcile();
    f.cache.dispose();
    await f.store.close();
    f.database.inspect((db) {
      for (final table in tables) {
        expect(
          db
              .select('SELECT * FROM $table ORDER BY 1')
              .map((row) => row.values.toList())
              .toList(),
          before[table],
          reason: table,
        );
      }
    });
  });
}
