import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/library/data/publications/publication_lease.dart';
import 'package:shiori/features/reader/data/worker/publication_cancellation.dart';
import 'package:shiori/features/reader/data/worker/publication_worker.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_exception.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_protocol.dart';
import 'package:shiori/features/reader/engine/pagination/layout_identity.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';
import 'package:shiori/features/reader/engine/surface/reader_publication_lifetime.dart';

import '../../../library/data/publications/prepare_test_support.dart';
import '../../data/worker/worker_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final boundary in ['lease', 'queue', 'worker', 'open']) {
    test(
      'cancel at $boundary await drains then releases independent pin once',
      () async {
        final h = await PrepareHarness.create();
        final service = h.service;
        final ready = await service.prepare(h.key);
        final activation = h.session;
        final layout = LayoutIdentity(
          contentId: ready.identity.sha256,
          sectionIndex: 0,
          viewportWidth: 400,
          viewportHeight: 600,
          devicePixelRatio: 1,
          settings: const ReaderSettings(),
          fontSignature: 'none',
        );
        final pin = (await h.f.cache.acquireHead(activation, h.key))!;
        var releases = 0;
        final counted = PublicationLease(pin.generation, pin.local, () {
          releases++;
          pin.release();
        });
        final gate = Completer<void>();
        final entered = Completer<void>();
        Future<void>? blocker;
        if (boundary == 'queue') {
          blocker = service.queue.run(() {
            entered.complete();
            return gate.future;
          });
          await entered.future;
        }
        WorkerHarness? paused;
        if (boundary == 'open') {
          paused = WorkerHarness();
          await paused.start();
          addTearDown(paused.dispose);
        }
        final cancel = PublicationCancellation();
        final opening = ReaderPublicationLifetime.open(
          preparedBook: ready,
          activation: activation,
          layout: layout,
          isCurrent: () => h.f.guard.isCurrent(activation),
          cancellation: cancel,
          acquireLease: () async {
            if (boundary == 'lease') {
              entered.complete();
              await gate.future;
            }
            return counted;
          },
          queue: service.queue,
          worker: () async {
            if (boundary == 'worker') {
              entered.complete();
              await gate.future;
            }
            return paused?.worker ?? await service.worker.get();
          },
        );
        final rejected = expectLater(
          opening,
          throwsA(workerFailure(PublicationWorkerFailure.canceled)),
        );
        if (boundary == 'open') {
          final event = await paused!.nextRequest();
          expect(event.request, isA<OpenPublication>());
          cancel.cancel();
          expect(releases, 0);
          paused.resume(event);
          final detach = await paused.nextRequest();
          expect(detach.request, isA<DetachPublication>());
          expect(releases, 0);
          paused.resume(detach);
        } else {
          if (boundary != 'queue') await entered.future;
          cancel.cancel();
          gate.complete();
        }
        await rejected;
        await blocker;
        expect(releases, 1);
        ready.release();
        final evict = await h.f.cache.reserveBytes(h.f.limit);
        evict.release();
      },
    );
  }

  test('late first A open cannot publish in a later A activation', () async {
    final h = await PrepareHarness.create();
    final service = h.service;
    final ready = await service.prepare(h.key);
    final firstA = h.session;
    final gate = Completer<PublicationWorker>();
    final entered = Completer<void>();
    final layout = LayoutIdentity(
      contentId: ready.identity.sha256,
      sectionIndex: 0,
      viewportWidth: 400,
      viewportHeight: 600,
      devicePixelRatio: 1,
      settings: const ReaderSettings(),
      fontSignature: 'none',
    );
    final opening = ReaderPublicationLifetime.open(
      preparedBook: ready,
      activation: firstA,
      layout: layout,
      isCurrent: () => h.f.guard.isCurrent(firstA),
      acquireLease: () => h.f.cache.acquireHead(firstA, ready.identity.bookKey),
      queue: service.queue,
      worker: () {
        entered.complete();
        return gate.future;
      },
    );
    final rejected = expectLater(
      opening,
      throwsA(workerFailure(PublicationWorkerFailure.canceled)),
    );
    await entered.future;
    final physical = await service.worker.get();
    h.f.select(serverB);
    h.f.select(serverA);
    expect(h.session.serverKey, firstA.serverKey);
    expect(h.session.generation, isNot(firstA.generation));
    gate.complete(physical);
    await rejected;
    final fresh = await h.service.prepare(h.key);
    expect(fresh.identity, ready.identity);
    fresh.release();
  });

  for (final boundary in ['plan', 'resources', 'result']) {
    test(
      'preload $boundary cancellation disposes/drains before file release',
      () async {
        final h = await PrepareHarness.create();
        final service = h.service;
        final ready = await service.prepare(h.key);
        final activation = h.session;
        final layout = LayoutIdentity(
          contentId: ready.identity.sha256,
          sectionIndex: 0,
          viewportWidth: 400,
          viewportHeight: 600,
          devicePixelRatio: 1,
          settings: const ReaderSettings(),
          fontSignature: 'none',
        );
        final paused = WorkerHarness();
        await paused.start();
        addTearDown(paused.dispose);
        final pin = (await h.f.cache.acquireHead(activation, h.key))!;
        var releases = 0;
        var current = true;
        final opening = ReaderPublicationLifetime.open(
          preparedBook: ready,
          activation: activation,
          layout: layout,
          isCurrent: () => current,
          acquireLease: () async =>
              PublicationLease(pin.generation, pin.local, () {
                releases++;
                pin.release();
              }),
          queue: service.queue,
          worker: () async => paused.worker,
        );
        paused.resume(await paused.nextRequest());
        final reader = await opening;
        final preload = reader.preload(0, expectedLayout: layout);
        final rejected = expectLater(
          preload,
          throwsA(
            workerFailure(
              boundary == 'result'
                  ? PublicationWorkerFailure.stale
                  : PublicationWorkerFailure.canceled,
            ),
          ),
        );
        var event = await paused.nextRequest();
        expect(event.request, isA<PlanPublicationResources>());
        if (boundary != 'plan') {
          paused.resume(event);
          event = await paused.nextRequest();
          expect(event.request, isA<PreloadPublicationResources>());
        }
        Future<void>? closing;
        Future<void> close() => reader.close(
          disableAndInvalidate: () {},
          cancelAndDrain: () async => rejected,
          disposeScenesAndSources: () async {},
        );
        if (boundary == 'result') {
          current = false;
        } else {
          closing = close();
        }
        expect(releases, 0);
        paused.resume(event);
        await rejected;
        closing ??= close();
        final detach = await paused.nextRequest();
        expect(detach.request, isA<DetachPublication>());
        expect(releases, 0);
        paused.resume(detach);
        await closing;
        expect(releases, 1);
        ready.release();
      },
    );
  }
}
