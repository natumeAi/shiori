import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/resources/reader_resource_budget.dart';
import 'package:shiori/features/reader/data/worker/publication_cancellation.dart';
import 'package:shiori/features/reader/data/worker/publication_worker.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_exception.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_protocol.dart';

import '../../contract_test_values.dart';
import 'worker_test_support.dart';

void main() {
  test('worker exit cannot deadlock final reservation release', () async {
    final worker = await PublicationWorker.spawn();
    final owner = worker.reserveReader();
    await worker.open(fixturePath, tagA, reservation: owner);
    final pending = worker.loadSection(0, reservation: owner);
    worker.killForTesting();
    await pending.then<void>((_) {}, onError: (Object _) {});
    // Wait for the isolate exit listener without clocks or real I/O polling.
    while (!worker.isClosed) {
      await Future<void>.delayed(Duration.zero);
    }
    await owner.release();
    await worker.close();
    expect(owner.isReleased, isTrue);
  });
  test('prepare defers without retiring the reader adapter', () async {
    final worker = await PublicationWorker.spawn();
    addTearDown(worker.close);
    final owner = worker.reserveReader();
    await worker.open(
      'assets/reader_fixtures/images.epub',
      tagA,
      reservation: owner,
    );
    final budget = ReaderResourceBudget();
    final preload = await worker.preloadSection(
      0,
      reservation: owner,
      budget: budget,
    );
    final path = preload.plan.lengths.keys.first;
    final bytes = preload.resources.bytes(path);
    expect(bytes, isNotNull);
    var imported = false;
    final prepare = worker
        .prepare(fixturePath, contractContent(), tag: tagB)
        .then((result) {
          imported = true;
          return result;
        });
    await Future<void>.delayed(Duration.zero);
    expect(imported, isFalse);
    expect(preload.resources.bytes(path), same(bytes));
    await expectLater(
      worker.loadSection(0),
      throwsA(workerFailure(PublicationWorkerFailure.reserved)),
    );
    await expectLater(
      worker.preloadSection(0),
      throwsA(workerFailure(PublicationWorkerFailure.reserved)),
    );
    preload.dispose();
    await owner.release();
    await owner.release();
    await prepare;
    expect(imported, isTrue);
    expect(budget.retainedBytes, 0);
  });

  test('deferred cancellation starts no import, queue stays bounded', () async {
    final worker = await PublicationWorker.spawn();
    addTearDown(worker.close);
    final owner = worker.reserveReader();
    await worker.open(fixturePath, tagA, reservation: owner);
    final cancel = PublicationCancellation();
    final work = worker.prepare(
      fixturePath,
      contractContent(),
      cancellation: cancel,
    );
    final canceled = expectLater(
      work,
      throwsA(workerFailure(PublicationWorkerFailure.canceled)),
    );
    cancel.cancel();
    await canceled;
    final pending = [
      for (var i = 0; i < PublicationWorker.pendingLimit; i++)
        worker.open(fixturePath, tagB),
    ];
    await expectLater(
      worker.open(fixturePath, tagB),
      throwsA(workerFailure(PublicationWorkerFailure.queueFull)),
    );
    // Cancel the physical owner only after every deferred waiter is observed.
    final results = Future.wait(
      pending.map(
        (result) => result.then((_) => true, onError: (Object _) => false),
      ),
    );
    expect(await worker.loadSection(0, reservation: owner), isNotNull);
    await owner.release();
    await results;
  });

  test(
    'release waits for canceled physical preload before detach and close',
    () async {
      final h = WorkerHarness();
      await h.start();
      addTearDown(h.dispose);
      final owner = h.worker.reserveReader();
      final opening = h.worker.open(fixturePath, tagA, reservation: owner);
      h.resume(await h.nextRequest());
      await opening;
      final cancellation = PublicationCancellation();
      final preload = h.worker.preloadSection(
        0,
        reservation: owner,
        cancellation: cancellation,
      );
      final rejected = expectLater(
        preload,
        throwsA(workerFailure(PublicationWorkerFailure.canceled)),
      );
      final plan = await h.nextRequest();
      expect(plan.request, isA<PlanPublicationResources>());
      cancellation.cancel();
      await rejected;
      var released = false;
      final release = owner.release().then((_) => released = true);
      final close = h.worker.close();
      await Future<void>.delayed(Duration.zero);
      expect(released, isFalse);
      h.resume(plan);
      final detach = await h.nextRequest();
      expect(detach.request, isA<DetachPublication>());
      expect(released, isFalse);
      h.resume(detach);
      await release;
      await close;
      expect(owner.isReleased, isTrue);
    },
  );
}
