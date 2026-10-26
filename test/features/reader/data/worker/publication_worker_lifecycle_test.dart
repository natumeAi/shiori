import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_exception.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_protocol.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_test_hooks.dart';

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
    'A -> B -> A rejects old work and delayed old IDs on the same isolate',
    () async {
      final old = harness.worker.loadSection(0);
      final running = await harness.nextRequest();
      final queued = harness.worker.readResource('absent');
      final checks = [
        expectLater(
          old,
          throwsA(workerFailure(PublicationWorkerFailure.stale)),
        ),
        expectLater(
          queued,
          throwsA(workerFailure(PublicationWorkerFailure.stale)),
        ),
      ];
      final intermediate = harness.worker.open(fixturePath, tagB);
      final intermediateCheck = expectLater(
        intermediate,
        throwsA(workerFailure(PublicationWorkerFailure.stale)),
      );
      final latest = harness.worker.open(fixturePath, tagA);
      await Future.wait([...checks, intermediateCheck]);
      harness.resume(running);
      final reopened = await harness.nextRequest();
      expect(reopened.request, isA<OpenPublication>());
      expect(reopened.request.tag, tagA);
      expect(reopened.request.generation, running.request.generation + 2);
      expect(reopened.isolateControl, running.isolateControl);
      // Old ID/tag cannot consume or complete the newer open's execution slot.
      reopened.replies.send(
        PublicationFailed(
          running.request.id,
          tagA,
          running.request.generation,
          const ParseException(),
        ),
      );
      harness.resume(reopened);
      expect((await latest).sections, isNotEmpty);
      final loaded = harness.worker.loadSection(0);
      final event = await harness.nextRequest();
      harness.resume(event);
      expect((await loaded).nodes, isNotEmpty);
      expect(harness.requests.where((e) => e.request.tag == tagB), isEmpty);
    },
  );

  for (final mismatch in ['tag', 'generation']) {
    test('matching ID with wrong $mismatch completes as stale', () async {
      final result = harness.worker.loadSection(0);
      final event = await harness.nextRequest();
      final request = event.request;
      final check = expectLater(
        result,
        throwsA(workerFailure(PublicationWorkerFailure.stale)),
      );
      event.replies.send(
        PublicationFailed(
          request.id,
          mismatch == 'tag' ? tagB : request.tag,
          mismatch == 'generation'
              ? request.generation + 1
              : request.generation,
          const ParseException(),
        ),
      );
      await check;
      // The real late response must not complete a subsequent request.
      final next = harness.worker.readResource('absent');
      harness.resume(event);
      final nextEvent = await harness.nextRequest();
      expect(nextEvent.request, isA<ReadPublicationResource>());
      harness.resume(nextEvent);
      expect(await next, isNull);
    });
  }

  test(
    'actual unexpected isolate kill completes all waiters and closes client',
    () async {
      final running = harness.worker.loadSection(0);
      await harness.nextRequest();
      final pending = [
        for (var i = 0; i < 8; i++) harness.worker.loadSection(0),
      ];
      final checks = [
        for (final future in [running, ...pending])
          expectLater(
            future,
            throwsA(workerFailure(PublicationWorkerFailure.unexpectedExit)),
          ),
      ];
      harness.worker.killForTesting();
      await Future.wait(checks);
      expect(harness.worker.isClosed, isTrue);
      await expectLater(
        harness.worker.open(fixturePath, tagB),
        throwsA(workerFailure(PublicationWorkerFailure.closed)),
      );
      await harness.worker.close();
    },
  );

  test(
    'uncaught worker error listener completes waiters with typed failure',
    () async {
      final running = harness.worker.loadSection(0);
      final event = await harness.nextRequest();
      final pending = harness.worker.readResource('absent');
      final checks = [
        expectLater(
          running,
          throwsA(workerFailure(PublicationWorkerFailure.workerError)),
        ),
        expectLater(
          pending,
          throwsA(workerFailure(PublicationWorkerFailure.workerError)),
        ),
      ];
      event.resume!.send(PublicationWorkerTestAction.crash);
      await Future.wait(checks);
      expect(harness.worker.isClosed, isTrue);
    },
  );

  test(
    'all archive and parser calls run away from the guarded root isolate',
    () async {
      final source = ReaderWorkGuard.callback(
        () => harness.worker.loadSection(0),
      );
      final parse = await harness.nextRequest();
      harness.resume(parse);
      await source;
      final resource = ReaderWorkGuard.callback(
        () => harness.worker.readResource(fixtureSectionPath),
      );
      final read = await harness.nextRequest();
      harness.resume(read);
      expect(await resource, isNotEmpty);
      final reopen = ReaderWorkGuard.callback(
        () => harness.worker.open(fixturePath, tagB),
      );
      final open = await harness.nextRequest();
      harness.resume(open);
      await reopen;
      final closing = ReaderWorkGuard.callback(harness.worker.close);
      final close = await harness.nextRequest();
      expect(close.request, isA<ClosePublication>());
      await closing;
      expect(
        harness.work.map((event) => event.work),
        containsAll([
          PublicationWorkerWork.archiveOpen,
          PublicationWorkerWork.packageParse,
          PublicationWorkerWork.sectionParse,
          PublicationWorkerWork.resourceRead,
          PublicationWorkerWork.archiveClose,
        ]),
      );
      expect(
        harness.work.every(
          (event) => event.isolateControl != Isolate.current.controlPort,
        ),
        isTrue,
      );
      expect(harness.work.map((event) => event.isolateControl).toSet(), {
        parse.isolateControl,
      });
    },
  );
}
