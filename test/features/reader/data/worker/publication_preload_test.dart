import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/epub/epub_archive.dart';
import 'package:shiori/features/reader/data/resources/reader_resource_budget.dart';
import 'package:shiori/features/reader/data/resources/reader_resource_source.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';
import 'package:shiori/features/reader/data/worker/publication_cancellation.dart';
import 'package:shiori/features/reader/data/worker/publication_worker.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_exception.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_protocol.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_test_hooks.dart';

import 'import_test_support.dart';
import 'worker_test_support.dart';

void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('shiori-preload-'));
  tearDown(() => temp.deleteSync(recursive: true));

  test(
    'preload transfers only this section references with archive byte parity',
    () async {
      final file = writeImport(
        temp,
        importEntries(
          sources: [
            sourcePage(
              body: '<img src="page.png"/><img src="missing.png"/>',
              head: '<link rel="stylesheet" href="style.css"/>',
            ),
            sourcePage(body: '<img src="unrequested.png"/>'),
          ],
        )..['EPUB/unrequested.png'] = 'other-section-only',
      );
      final events = ReceivePort();
      final work = <PublicationWorkerWorkEvent>[];
      final requests = <PublicationWorkerRequestEvent>[];
      final subscription = events.listen((event) {
        if (event is PublicationWorkerWorkEvent) work.add(event);
        if (event is PublicationWorkerRequestEvent) requests.add(event);
      });
      final worker = await PublicationWorker.spawn(
        testHooks: PublicationWorkerTestHooks(events.sendPort),
      );
      final budget = ReaderResourceBudget();
      try {
        final ready = await worker.prepare(file.path, identityFor(file));
        final loaded = await ReaderWorkGuard.callback(
          () => worker.preloadSection(0, budget: budget),
        );
        final archive = EpubArchive.openFile(file.path);
        try {
          expect(
            loaded.plan.references.map((ref) => ref.path),
            ready.firstSection.resources.map((ref) => ref.path),
          );
          expect(
            loaded.plan.lengths.keys,
            unorderedEquals([
              'EPUB/page.png',
              'EPUB/style.css',
              'EPUB/nested.css',
            ]),
          );
          for (final path in loaded.plan.lengths.keys) {
            expect(
              ReaderWorkGuard.callback(() => loaded.resources.bytes(path)),
              archive.bytes(path),
            );
          }
          expect(
            loaded.resources.miss('EPUB/missing.png'),
            ReaderResourceMiss.absent,
          );
          expect(
            loaded.resources.miss('EPUB/unrequested.png'),
            ReaderResourceMiss.notPreloaded,
          );
          expect(
            work.every(
              (event) => event.isolateControl != Isolate.current.controlPort,
            ),
            isTrue,
          );
          final batches = requests
              .map((event) => event.request)
              .whereType<PreloadPublicationResources>();
          expect(batches.single.lengths, loaded.plan.lengths);
          final second = await worker.preloadSection(0, budget: budget);
          expect(
            identical(
              second.resources.bytes('EPUB/page.png'),
              loaded.resources.bytes('EPUB/page.png'),
            ),
            isTrue,
          );
          expect(
            requests.last.request,
            isA<PreloadPublicationResources>().having(
              (request) => request.lengths,
              'cache hits',
              isEmpty,
            ),
          );
          loaded.dispose();
          expect(budget.retainedBytes, greaterThan(0));
          second.dispose();
          expect(budget.accountedBytes, 0);
        } finally {
          archive.close();
        }
      } finally {
        await worker.close();
        await subscription.cancel();
        events.close();
      }
    },
  );

  test('budget failure occurs before any worker resource transfer', () async {
    final file = writeImport(
      temp,
      importEntries(sources: [sourcePage(body: simpleFixedBody)]),
    );
    final events = ReceivePort();
    final requests = <PublicationWorkerRequestEvent>[];
    final subscription = events.listen((event) {
      if (event is PublicationWorkerRequestEvent) requests.add(event);
    });
    final worker = await PublicationWorker.spawn(
      testHooks: PublicationWorkerTestHooks(events.sendPort),
    );
    final budget = ReaderResourceBudget(maxBytes: 1);
    try {
      await worker.prepare(file.path, identityFor(file));
      await expectLater(
        worker.preloadSection(0, budget: budget),
        throwsA(
          isA<ReaderResourceException>().having(
            (error) => error.failure,
            'failure',
            ReaderResourceFailure.budgetExceeded,
          ),
        ),
      );
      expect(budget.accountedBytes, 0);
      expect(await worker.loadSection(0), isNotNull);
      expect(
        requests
            .map((event) => event.request)
            .whereType<PreloadPublicationResources>(),
        isEmpty,
      );
    } finally {
      await worker.close();
      await subscription.cancel();
      events.close();
    }
  });

  test('reopen and close retire live resource leases immediately', () async {
    final file = writeImport(
      temp,
      importEntries(sources: [sourcePage(body: simpleFixedBody)]),
    );
    final worker = await PublicationWorker.spawn();
    final budget = ReaderResourceBudget();
    await worker.prepare(file.path, identityFor(file));
    final old = await worker.preloadSection(0, budget: budget);
    final reopened = worker.prepare(file.path, identityFor(file));
    expect(budget.accountedBytes, 0);
    expect(old.resources.miss('EPUB/page.png'), ReaderResourceMiss.retired);
    await reopened;
    final next = await worker.preloadSection(0, budget: budget);
    final closing = worker.close();
    expect(budget.accountedBytes, 0);
    expect(next.resources.bytes('EPUB/page.png'), isNull);
    await closing;
    file.deleteSync();
  });

  test('cancellation during actual preload releases reservation, discards late bytes', () async {
    final file = writeImport(
      temp,
      importEntries(sources: [sourcePage(body: simpleFixedBody)]),
    );
    final events = ReceivePort();
    final iterator = StreamIterator<Object?>(events);
    final worker = await PublicationWorker.spawn(
      testHooks: PublicationWorkerTestHooks(
        events.sendPort,
        pausePreload: true,
      ),
    );
    final budget = ReaderResourceBudget();
    final cancellation = PublicationCancellation();
    await worker.prepare(file.path, identityFor(file));
    final pending = worker.preloadSection(
      0,
      budget: budget,
      cancellation: cancellation,
    );
    final rejected = expectLater(
      pending,
      throwsA(workerFailure(PublicationWorkerFailure.canceled)),
    );
    PublicationWorkerPreloadEvent? gate;
    while (await iterator.moveNext()) {
      if (iterator.current case final PublicationWorkerPreloadEvent event) {
        gate = event;
        break;
      }
    }
    expect(gate, isNotNull);
    expect(budget.reservedBytes, greaterThan(0));
    cancellation.cancel();
    await rejected;
    expect(budget.accountedBytes, 0);
    gate!.resume.send(null);
    await worker.loadSection(
      0,
    ); // physical slot drains before the next request.
    expect(budget.accountedBytes, 0);
    await worker.close();
    await iterator.cancel();
    events.close();
  });

  test('later sections discover their own resources; pre-canceled requests retain nothing', () async {
    final file = writeImport(
      temp,
      importEntries(
        sources: [
          sourcePage(),
          sourcePage(body: '<img src="page.png"/>'),
        ],
      ),
    );
    final worker = await PublicationWorker.spawn();
    final budget = ReaderResourceBudget();
    try {
      await worker.prepare(file.path, identityFor(file));
      final cancellation = PublicationCancellation()..cancel();
      await expectLater(
        worker.preloadSection(1, budget: budget, cancellation: cancellation),
        throwsA(workerFailure(PublicationWorkerFailure.canceled)),
      );
      expect(budget.accountedBytes, 0);
      final first = await worker.preloadSection(0, budget: budget);
      expect(first.plan.lengths, isEmpty);
      final second = await worker.preloadSection(1, budget: budget);
      expect(second.plan.sectionIndex, 1);
      expect(second.plan.href, 'EPUB/s1.xhtml');
      expect(second.plan.lengths.keys, ['EPUB/page.png']);
      expect(second.plan.cfiBase, isNot(first.plan.cfiBase));
      first.dispose();
      second.dispose();
      expect(budget.accountedBytes, 0);
    } finally {
      await worker.close();
    }
  });

  test('unexpected worker exit retires already leased bytes', () async {
    final harness = WorkerHarness();
    await harness.start();
    // Like the existing unexpected-exit tests, kill against a bundled input:
    // abrupt VM termination cannot promise synchronous native-handle cleanup.
    await harness.open(path: 'assets/reader_fixtures/images.epub');
    final budget = ReaderResourceBudget();
    final pending = harness.worker.preloadSection(0, budget: budget);
    harness.resume(await harness.nextRequest());
    harness.resume(await harness.nextRequest());
    final section = await pending;
    final path = section.plan.lengths.keys.first;
    expect(budget.retainedBytes, greaterThan(0));
    final blocked = harness.worker.loadSection(0);
    final rejected = expectLater(
      blocked,
      throwsA(workerFailure(PublicationWorkerFailure.unexpectedExit)),
    );
    await harness.nextRequest();
    harness.worker.killForTesting();
    await rejected;
    expect(budget.accountedBytes, 0);
    expect(section.resources.miss(path), ReaderResourceMiss.retired);
    await harness.dispose();
  });
}
