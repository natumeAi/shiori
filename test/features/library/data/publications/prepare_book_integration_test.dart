import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/content_change.dart';
import 'package:shiori/features/library/data/publications/preparation_state.dart';
import 'package:shiori/features/library/data/publications/prepare_book_exception.dart';
import 'package:shiori/features/library/data/publications/session_publication_worker.dart';
import 'package:shiori/features/reader/data/resources/reader_resource_budget.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';
import 'package:shiori/features/reader/data/worker/publication_worker.dart';

import 'prepare_test_support.dart';

void main() {
  test(
    'S4 reopens leased immutable path and preloads through resource seam',
    () async {
      final h = await PrepareHarness.create();
      h.bytes = importZip(
        importEntries(sources: [sourcePage(body: simpleFixedBody)]),
      );
      final ready = await h.service.prepare(h.key);
      final owner = h.container.read(
        sessionPublicationWorkerProvider(h.session),
      );
      final worker = await owner.get();
      expect(identical(worker, await owner.get()), isTrue);
      // D5 detached the stage; S4 must reopen the immutable leased file.
      await worker.prepare(ready.lease.local.path, ready.identity);
      final budget = ReaderResourceBudget(maxBytes: 1024 * 1024);
      final preload = await worker.preloadSection(0, budget: budget);
      expect(preload.plan.href, ready.publication.firstSection.href);
      final resources = preload.resources;
      ReaderWorkGuard.callback(() {
        expect(resources.contains('EPUB/page.png'), isTrue);
        expect(resources.bytes('EPUB/page.png'), isNotEmpty);
        expect(resources.size('EPUB/page.png'), greaterThan(0));
      });
      expect(budget.accountedBytes, greaterThan(0));
      h.f.guard.retire();
      await owner.closed;
      expect(budget.accountedBytes, 0);
      expect(ready.isReleased, isTrue);
      expect(resources.bytes('EPUB/page.png'), isNull);
      preload.dispose();
    },
  );

  test(
    'unchanged refresh re-downloads unconditionally without a content change',
    () async {
      final h = await PrepareHarness.create();
      final changes = <ContentChange>[];
      final sub = h.service.contentChanges.listen(changes.add);
      addTearDown(sub.cancel);
      final first = await h.service.prepare(h.key);
      final second = await h.service.prepare(h.key, refresh: true);
      expect(second.identity, first.identity);
      expect(h.downloaded, h.bytes.length * 2);
      expect(h.adapter.requests.last.headers['If-None-Match'], isNull);
      expect(changes.length, 1);
    },
  );

  for (final missing in [false, true]) {
    test(
      '${missing ? 'missing' : 'corrupt'} local head recovers through full GET',
      () async {
        final h = await PrepareHarness.create();
        final first = await h.service.prepare(h.key);
        final file = File(first.lease.local.path);
        if (missing) {
          await file.delete();
        } else {
          final bytes = await file.readAsBytes();
          bytes[0] ^= 1;
          await file.writeAsBytes(bytes);
          h.bytes = importZip(
            importEntries(
              sources: [sourcePage(body: '<p>Server replacement</p>')],
            ),
          );
        }
        final second = await h.service.prepare(h.key);
        expect(second.identity == first.identity, missing);
        expect(h.adapter.requests.last.headers['If-None-Match'], isNull);
        expect(
          h.downloaded,
          first.lease.generation.byteLength + h.bytes.length,
        );
        await h.clean();
      },
    );
  }

  test(
    '304 losing its local file performs exactly one unconditional recovery',
    () async {
      final h = await PrepareHarness.create();
      final first = await h.service.prepare(h.key);
      var calls = 0;
      h.respondFile = (options) async {
        calls++;
        if (calls == 1) {
          expect(options.headers['If-None-Match'], h.etag);
          await File(first.lease.local.path).delete();
          return ResponseBody.fromBytes([], 304);
        }
        expect(options.headers['If-None-Match'], isNull);
        return fileBody(bytes: h.bytes);
      };
      final recovered = await h.service.prepare(h.key);
      expect(recovered.identity, first.identity);
      expect(calls, 2);
    },
  );

  test(
    'chunked overflow is tooLarge and network errors remain network',
    () async {
      final h = await PrepareHarness.create(downloadLimit: 16);
      h.respondFile = (_) => fileBody(stream: Stream.value(Uint8List(17)));
      await expectLater(
        h.service.prepare(h.key),
        throwsA(prepareFailure(PrepareBookFailure.tooLarge)),
      );
      await h.clean();
      h.respondFile = (options) => throw DioException.connectionError(
        requestOptions: options,
        reason: 'synthetic offline',
      );
      h.listen();
      await h.controller.prepare();
      expect(
        (h.state as PreparationFailed).error.failure,
        PrepareBookFailure.network,
      );
    },
  );
}
