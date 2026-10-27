import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/content_change.dart';
import 'package:shiori/features/library/data/publications/prepare_book_exception.dart';

import '../../../reader/data/epub/raw_zip_test_support.dart';
import 'prepare_test_support.dart';

void main() {
  test(
    'concurrent reconciliation and D1 corruption recovery do not deadlock',
    () async {
      final h = await PrepareHarness.create();
      final old = await h.service.prepare(h.key);
      Future<void>? reconciling;
      var requests = 0;
      h.respondFile = (options) async {
        if (++requests == 1) {
          final corrupt = await File(old.lease.local.path).readAsBytes();
          corrupt[0] ^= 1;
          await File(old.lease.local.path).writeAsBytes(corrupt);
          reconciling = h.f.cache.reconcile();
          return fileBody(status: 304, bytes: []);
        }
        return fileBody(bytes: h.bytes);
      };
      final next = await h.service
          .prepare(h.key)
          .timeout(const Duration(seconds: 5));
      await reconciling!.timeout(const Duration(seconds: 5));
      expect(requests, 2);
      expect(next.identity, old.identity);
      old.release();
      next.release();
      await h.f.cache.reconcile();
      await h.clean();
    },
  );

  for (final reconcile in [false, true]) {
    for (final held in [false, true]) {
      test(
        'same bytes recover: reconcile=$reconcile, held lease=$held',
        () async {
          final h = await PrepareHarness.create();
          final changes = <ContentChange>[];
          final sub = h.service.contentChanges.listen(changes.add);
          addTearDown(sub.cancel);
          final first = await h.service.prepare(h.key);
          final file = File(first.lease.local.path);
          final corrupt = await file.readAsBytes();
          corrupt[0] ^= 1;
          if (!held) first.release();
          await file.writeAsBytes(corrupt);
          final reader = held ? await file.open() : null;
          if (reconcile) await h.f.cache.reconcile();
          // Inspect the head during recovery, after full verification detected
          // corruption and before the replacement is committed.
          h.respondFile = (options) async {
            expect(options.headers['If-None-Match'], isNull);
            expect(await h.f.cache.acquireHead(h.session, h.key), isNull);
            return fileBody(bytes: h.bytes);
          };
          final next = await h.service.prepare(h.key, refresh: reconcile);
          expect(next.identity, first.identity);
          expect(await File(next.lease.local.path).readAsBytes(), h.bytes);
          expect(
            changes.length,
            1,
            reason: 'Physical repair keeps content identity',
          );
          if (held) {
            expect(next.lease.local.path, isNot(first.lease.local.path));
            expect(await file.readAsBytes(), corrupt);
            expect(await reader!.read(8), corrupt.take(8).toList());
            await reader.close();
            await h.f.cache.reconcile();
            expect(await file.readAsBytes(), corrupt);
            first.release();
            await h.f.cache.reconcile();
            expect(await file.exists(), isFalse);
          }
          final head = (await h.f.store.readPublicationHead(h.key))!;
          expect(head.relativePath, next.lease.generation.relativePath);
          final acquired = (await h.f.cache.acquireHead(h.session, h.key))!;
          expect(await File(acquired.local.path).readAsBytes(), h.bytes);
          acquired.release();
          next.release();
          await h.clean();
        },
      );
    }
  }

  for (final status in [200, 206]) {
    test(
      'D1 reports corrupt small 304 cache before recovery: $status',
      () async {
        final h = await PrepareHarness.create();
        final old = await h.service.prepare(h.key);
        var requests = 0;
        h.respondFile = (options) async {
          requests++;
          if (requests == 1) {
            expect(options.headers['If-None-Match'], isNotNull);
            final corrupt = await File(old.lease.local.path).readAsBytes();
            corrupt[0] ^= 1;
            await File(old.lease.local.path).writeAsBytes(corrupt);
            return fileBody(status: 304, bytes: []);
          }
          expect(options.headers['If-None-Match'], isNull);
          expect(await h.f.cache.acquireHead(h.session, h.key), isNull);
          return fileBody(status: status, bytes: status == 200 ? h.bytes : [1]);
        };
        if (status == 200) {
          final next = await h.service.prepare(h.key);
          expect(next.identity, old.identity);
          expect(await File(next.lease.local.path).readAsBytes(), h.bytes);
          next.release();
        } else {
          await expectLater(
            h.service.prepare(h.key),
            throwsA(prepareFailure(PrepareBookFailure.server)),
          );
        }
        expect(requests, 2);
        old.release();
        await h.f.cache.reconcile();
      },
    );
  }

  for (final status in [200, 206, 304, 412, 416]) {
    test(
      'large corrupt post-304 file shares recovery allowance: $status',
      () async {
        final h = await PrepareHarness.create();
        final small = ZipDecoder().decodeBytes(importZip(importEntries()));
        h.bytes = rawZip([
          for (final entry in small.files)
            RawZipEntry(entry.name, entry.content),
          RawZipEntry('padding.bin', Uint8List(9 * 1024 * 1024)),
        ]);
        final old = await h.service.prepare(h.key);
        var requests = 0;
        h.respondFile = (options) async {
          requests++;
          if (requests == 1) {
            expect(options.headers['If-None-Match'], isNotNull);
            final handle = await File(old.lease.local.path)
                .open(mode: FileMode.append);
            await handle.setPosition(100);
            await handle.writeByte(99);
            await handle.close();
            return fileBody(status: 304, bytes: []);
          }
          expect(options.headers['If-None-Match'], isNull);
          return fileBody(status: status, bytes: status == 200 ? h.bytes : [1]);
        };
        if (status == 200) {
          final next = await h.service.prepare(h.key);
          expect(next.identity, old.identity);
          expect(await File(next.lease.local.path).readAsBytes(), h.bytes);
          next.release();
        } else {
          await expectLater(
            h.service.prepare(h.key),
            throwsA(prepareFailure(PrepareBookFailure.server)),
          );
          expect(await h.f.cache.acquireHead(h.session, h.key), isNull);
        }
        expect(requests, 2, reason: 'Only one unconditional recovery request');
        old.release();
        await h.f.cache.reconcile();
        await h.clean();
      },
    );
  }
}
