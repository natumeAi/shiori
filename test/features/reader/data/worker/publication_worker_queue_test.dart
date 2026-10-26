import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/worker/publication_cancellation.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_exception.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_protocol.dart';

import 'worker_test_support.dart';

void main() {
  late WorkerHarness harness;
  setUp(() async {
    harness = WorkerHarness();
    await harness.start();
    addTearDown(harness.dispose);
    await harness.open();
  });

  test(
    'one running plus eight pending, overflow fails fast, FIFO execution',
    () async {
      final first = harness.worker.loadSection(0);
      final running = await harness.nextRequest();
      final pending = [
        for (var i = 0; i < 8; i++) harness.worker.loadSection(0),
      ];
      await expectLater(
        harness.worker.loadSection(0),
        throwsA(workerFailure(PublicationWorkerFailure.queueFull)),
      );
      harness.resume(running);
      await first;
      var lastId = running.request.id;
      for (final future in pending) {
        final event = await harness.nextRequest();
        expect(event.request.id, lastId + 1);
        lastId = event.request.id;
        harness.resume(event);
        expect((await future).nodes, isNotEmpty);
      }
      expect(harness.requests.length, 10); // Open, running, eight pending.
    },
  );

  test('cancel pending removes it without ever sending it to worker', () async {
    final first = harness.worker.loadSection(0);
    final running = await harness.nextRequest();
    final token = PublicationCancellation();
    final canceled = harness.worker.loadSection(999, cancellation: token);
    final canceledCheck = expectLater(
      canceled,
      throwsA(workerFailure(PublicationWorkerFailure.canceled)),
    );
    final after = harness.worker.readResource('absent');
    token.cancel();
    token.cancel();
    await canceledCheck;
    harness.resume(running);
    await first;
    final next = await harness.nextRequest();
    expect(next.request, isA<ReadPublicationResource>());
    expect(next.request.id, running.request.id + 2);
    harness.resume(next);
    expect(await after, isNull);
    expect(
      harness.requests.where((e) => e.request is LoadPublicationSection).length,
      1,
    );
  });

  test(
    'cancel running completes immediately but holds slot until late result',
    () async {
      final token = PublicationCancellation();
      final first = harness.worker.loadSection(0, cancellation: token);
      final running = await harness.nextRequest();
      final check = expectLater(
        first,
        throwsA(workerFailure(PublicationWorkerFailure.canceled)),
      );
      token.cancel();
      await check; // The worker is still stopped at its gate.
      final pending = [
        for (var i = 0; i < 8; i++) harness.worker.readResource('absent'),
      ];
      await expectLater(
        harness.worker.loadSection(0),
        throwsA(workerFailure(PublicationWorkerFailure.queueFull)),
      );
      harness.resume(running);
      for (final future in pending) {
        final event = await harness.nextRequest();
        expect(event.request, isA<ReadPublicationResource>());
        harness.resume(event);
        expect(await future, isNull);
      }
    },
  );

  test(
    'already canceled token does not dispatch or invalidate publication',
    () async {
      final token = PublicationCancellation()..cancel();
      await expectLater(
        harness.worker.open('absent', tagB, cancellation: token),
        throwsA(workerFailure(PublicationWorkerFailure.canceled)),
      );
      await expectLater(
        harness.worker.loadSection(0, cancellation: token),
        throwsA(workerFailure(PublicationWorkerFailure.canceled)),
      );
      final valid = harness.worker.loadSection(0);
      final event = await harness.nextRequest();
      expect(event.request.tag, tagA);
      harness.resume(event);
      expect((await valid).nodes, isNotEmpty);
    },
  );

  test(
    'close completes all waiters and discards a running parse failure',
    () async {
      final first = harness.worker.loadSection(999);
      final running = await harness.nextRequest();
      final pending = harness.worker.loadSection(0);
      final checks = [
        expectLater(
          first,
          throwsA(workerFailure(PublicationWorkerFailure.closed)),
        ),
        expectLater(
          pending,
          throwsA(workerFailure(PublicationWorkerFailure.closed)),
        ),
      ];
      final closing = harness.worker.close();
      expect(identical(closing, harness.worker.close()), isTrue);
      await Future.wait(checks);
      harness.resume(running);
      final event = await harness.nextRequest();
      expect(event.request, isA<ClosePublication>());
      await closing;
      expect(harness.worker.isClosed, isTrue);
    },
  );
}
