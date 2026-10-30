import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/features/diagnostics/data/probe_book_repository.dart';
import 'package:shiori/features/diagnostics/presentation/reader_probe/reader_probe_controller.dart';
import 'package:shiori/features/diagnostics/presentation/reader_probe/reader_probe_screen.dart';
import 'package:shiori/features/library/data/publications/publication_lease.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_test_hooks.dart';
import 'package:shiori/features/reader/engine/motion/page_turn_engine.dart';
import 'package:shiori/features/reader/engine/motion/reader_turn_controller.dart';
import 'package:shiori/features/reader/engine/motion/turn_clock.dart';
import 'package:shiori/features/reader/engine/motion/turn_session.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';
import 'package:shiori/features/reader/engine/surface/prepared_reader.dart';
import 'package:shiori/features/reader/engine/surface/publication_fixed_composition.dart';
import 'package:shiori/l10n/l10n.dart';

import '../../../helpers/probe_storage_fixtures.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/reader_probe_fixtures.dart';
import '../../library/data/publications/prepare_test_support.dart';
import '../../reader/engine/surface/publication_fixed_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('replacement drains old lifetime before acquiring shared queue', () async {
    final h = await PrepareHarness.create();
    h.bytes = fixedSidesPublication(['center']);
    final ready = await h.service.prepare(h.key);
    addTearDown(ready.release);
    final recorder = readerRecorder(capacity: 1024);
    addTearDown(recorder.dispose);
    final controller = ReaderProbeController(recorder);
    addTearDown(controller.dispose);
    Future<bool> open() => controller.openPublication(
      book: ready,
      activation: h.session,
      isCurrent: h.f.guard.isCurrent,
      acquireLease: () => h.f.cache.acquireHead(h.session, h.key),
      queue: h.service.queue,
      worker: h.service.worker.get,
    );
    expect(await open(), true);
    final old = controller.session!;
    final oldTurn = controller.turn!;
    final opening = open();
    final completed = await opening.timeout(
      const Duration(seconds: 1),
      onTimeout: () => false,
    );
    // Unblock the defective implementation so a failed assertion can tear down.
    if (!completed) old.close();
    expect(await opening, true);
    await old.closed;
    expect(old.state, TurnSessionState.closed);
    expect(oldTurn.phase, TurnPhase.closed);
    expect(controller.turn!.phase, TurnPhase.idle);
    controller.dispose();
    await controller.session!.closed;
    await h.idle();
    expect(completed, true);
  });

  test('session shutdown owns its turn even if public turn changes', () async {
    final h = await PrepareHarness.create();
    h.bytes = fixedSidesPublication(['center']);
    final ready = await h.service.prepare(h.key);
    addTearDown(ready.release);
    final recorder = readerRecorder(capacity: 1024);
    addTearDown(recorder.dispose);
    final controller = ReaderProbeController(recorder);
    addTearDown(controller.dispose);
    expect(
      await controller.openPublication(
        book: ready,
        activation: h.session,
        isCurrent: h.f.guard.isCurrent,
        acquireLease: () => h.f.cache.acquireHead(h.session, h.key),
        queue: h.service.queue,
        worker: h.service.worker.get,
      ),
      true,
    );
    final owned = controller.turn!;
    final unrelated = ReaderTurnController(
      session: controller.session!,
      initial: controller.session!.position,
      clock: StopwatchTurnClock(),
      width: controller.width,
    );
    controller.turn = unrelated;
    controller.session!.close();
    await controller.session!.closed;
    final ownedPhase = owned.phase;
    final unrelatedPhase = unrelated.phase;
    unrelated.close();
    controller.turn = owned;
    expect(ownedPhase, TurnPhase.closed);
    expect(unrelatedPhase, TurnPhase.idle);
  });

  test('failed replacement preserves the accepted position', () async {
    final h = await PrepareHarness.create();
    h.bytes = fixedSidesPublication(['center']);
    final ready = await h.service.prepare(h.key);
    addTearDown(ready.release);
    final recorder = readerRecorder();
    addTearDown(recorder.dispose);
    final controller = ReaderProbeController(recorder);
    addTearDown(controller.dispose);
    expect(
      await controller.openPublication(
        book: ready,
        activation: h.session,
        isCurrent: h.f.guard.isCurrent,
        acquireLease: () => h.f.cache.acquireHead(h.session, h.key),
        queue: h.service.queue,
        worker: h.service.worker.get,
      ),
      true,
    );
    final old = controller.session!;
    final accepted = controller.accepted.value;
    var acceptedChanges = 0;
    controller.accepted.addListener(() => acceptedChanges++);
    final replacement = controller.openPublication(
      book: ready,
      activation: h.session,
      isCurrent: h.f.guard.isCurrent,
      acquireLease: () => h.f.cache.acquireHead(h.session, h.key),
      queue: h.service.queue,
      worker: () async => throw StateError('worker'),
    );
    // Also permit this regression to terminate on the defective implementation.
    if (controller.session == old) old.close();
    await expectLater(replacement, throwsStateError);
    await h.idle();
    expect(controller.accepted.value, same(accepted));
    expect(acceptedChanges, 0);
    expect(controller.session, isNull);
    expect(controller.turn, isNull);
  });

  test(
    'route releases its publication before another S3 preparation',
    () async {
      final h = await PrepareHarness.create();
      h.bytes = fixedSidesPublication(['center']);
      final ready = await h.service.prepare(h.key);
      addTearDown(ready.release);
      final recorder = readerRecorder();
      addTearDown(recorder.dispose);
      final controller = ReaderProbeController(recorder);
      addTearDown(controller.dispose);
      expect(
        await controller.openPublication(
          book: ready,
          activation: h.session,
          isCurrent: h.f.guard.isCurrent,
          acquireLease: () => h.f.cache.acquireHead(h.session, h.key),
          queue: h.service.queue,
          worker: h.service.worker.get,
        ),
        true,
      );
      final accepted = controller.accepted.value;
      await controller.releasePublication();
      final replacement = await h.service
          .prepare(h.key)
          .timeout(const Duration(seconds: 5));
      replacement.release();
      expect(controller.session, isNull);
      expect(controller.accepted.value, same(accepted));
      await h.idle();
    },
  );

  test('a later request supersedes an identical pending open', () async {
    final h = await PrepareHarness.create();
    h.bytes = fixedSidesPublication(['center']);
    final ready = await h.service.prepare(h.key);
    addTearDown(ready.release);
    final recorder = readerRecorder();
    addTearDown(recorder.dispose);
    final controller = ReaderProbeController(recorder);
    addTearDown(controller.dispose);
    final acquired = Completer<void>();
    final resume = Completer<void>();
    var releases = 0;
    final first = controller.openPublication(
      book: ready,
      activation: h.session,
      isCurrent: h.f.guard.isCurrent,
      acquireLease: () async {
        final lease = (await h.f.cache.acquireHead(h.session, h.key))!;
        acquired.complete();
        await resume.future;
        return PublicationLease(lease.generation, lease.local, () {
          releases++;
          lease.release();
        });
      },
      queue: h.service.queue,
      worker: h.service.worker.get,
    );
    await acquired.future;
    expect(
      await controller.openPublication(
        book: ready,
        activation: h.session,
        isCurrent: h.f.guard.isCurrent,
        acquireLease: () => h.f.cache.acquireHead(h.session, h.key),
        queue: h.service.queue,
        worker: h.service.worker.get,
      ),
      true,
    );
    final winner = controller.session!;
    resume.complete();
    final completed = await first.timeout(
      const Duration(seconds: 1),
      onTimeout: () => true,
    );
    // Release the winner only on the defective, blocked implementation.
    if (completed) winner.close();
    final firstOpened = await first;
    final published = controller.session;
    controller.dispose();
    await published?.closed;
    await h.idle();
    expect(firstOpened, false);
    expect(published, same(winner));
    expect(releases, 1);
  });

  for (final change in ['width', 'height', 'dpr', 'settings', 'dispose']) {
    test(
      'pending publication rejects $change and releases candidate once',
      () async {
        final h = await PrepareHarness.create();
        h.bytes = fixedSidesPublication(['center']);
        final ready = await h.service.prepare(h.key);
        addTearDown(ready.release);
        final recorder = readerRecorder(capacity: 1024);
        addTearDown(recorder.dispose);
        final controller = ReaderProbeController(recorder);
        addTearDown(controller.dispose);
        final acquired = Completer<void>();
        final resume = Completer<void>();
        var releases = 0;
        final opening = controller.openPublication(
          book: ready,
          activation: h.session,
          isCurrent: h.f.guard.isCurrent,
          acquireLease: () async {
            final lease = (await h.f.cache.acquireHead(h.session, h.key))!;
            acquired.complete();
            await resume.future;
            return PublicationLease(lease.generation, lease.local, () {
              releases++;
              lease.release();
            });
          },
          queue: h.service.queue,
          worker: h.service.worker.get,
        );
        await acquired.future;
        switch (change) {
          case 'width':
            controller.width += 30;
          case 'height':
            controller.height += 30;
          case 'dpr':
            controller.dpr = 2;
          case 'settings':
            await controller.reflow(const ReaderSettings(fontSize: 26));
          case 'dispose':
            controller.dispose();
        }
        resume.complete();
        final opened = await opening;
        final published = controller.session;
        final accepted = change == 'dispose' ? null : controller.accepted.value;
        controller.dispose();
        await published?.closed;
        await h.idle();
        expect(opened, false);
        expect(published, isNull);
        expect(accepted, isNull);
        expect(releases, 1);
      },
    );
  }

  for (final change in ['resize', 'settings', 'dispose']) {
    test('late $change during source preparation releases once', () async {
      final events = ReceivePort();
      addTearDown(events.close);
      final paused = Completer<PublicationWorkerPreloadEvent>();
      final subscription = events.listen((value) {
        if (value is! PublicationWorkerPreloadEvent) return;
        if (paused.isCompleted) {
          value.resume.send(null);
        } else {
          paused.complete(value);
        }
      });
      addTearDown(subscription.cancel);
      final h = await PrepareHarness.create(
        workerHooks: PublicationWorkerTestHooks(
          events.sendPort,
          pausePreload: true,
        ),
      );
      h.bytes = fixedSidesPublication(['center']);
      final ready = await h.service.prepare(h.key);
      addTearDown(ready.release);
      final recorder = readerRecorder();
      addTearDown(recorder.dispose);
      final controller = ReaderProbeController(recorder);
      addTearDown(controller.dispose);
      var releases = 0;
      final opening = controller.openPublication(
        book: ready,
        activation: h.session,
        isCurrent: h.f.guard.isCurrent,
        acquireLease: () async {
          final lease = (await h.f.cache.acquireHead(h.session, h.key))!;
          return PublicationLease(lease.generation, lease.local, () {
            releases++;
            lease.release();
          });
        },
        queue: h.service.queue,
        worker: h.service.worker.get,
      );
      final event = await paused.future;
      switch (change) {
        case 'resize':
          // Even a resize back to the original dimensions revokes the request.
          controller.width += 30;
          controller.width -= 30;
        case 'settings':
          await controller.reflow(const ReaderSettings(fontSize: 26));
        case 'dispose':
          controller.dispose();
      }
      event.resume.send(null);
      final opened = await opening;
      final published = controller.session;
      controller.dispose();
      await published?.closed;
      await h.idle();
      expect(opened, false);
      expect(published, isNull);
      expect(releases, 1);
    });
  }

  test('published source loaders retain the captured layout inputs', () async {
    final h = await PrepareHarness.create();
    h.bytes = fixedSidesPublication(['center', 'center']);
    final ready = await h.service.prepare(h.key);
    addTearDown(ready.release);
    final recorder = readerRecorder();
    addTearDown(recorder.dispose);
    final controller = ReaderProbeController(recorder);
    addTearDown(controller.dispose);
    final expected = fixedSectionLayout(
      identity: ready.identity,
      section: 1,
      viewportWidth: controller.width,
      viewportHeight: controller.height,
      devicePixelRatio: controller.dpr,
      settings: controller.settings,
    );
    expect(
      await controller.openPublication(
        book: ready,
        activation: h.session,
        isCurrent: h.f.guard.isCurrent,
        acquireLease: () => h.f.cache.acquireHead(h.session, h.key),
        queue: h.service.queue,
        worker: h.service.worker.get,
      ),
      true,
    );
    controller.width += 30;
    controller.height += 30;
    controller.dpr = 2;
    controller.settings = const ReaderSettings(fontSize: 26);
    final session = controller.session!;
    final prepared = await session.prepare(
      session.position,
      TurnDirection.next,
    );
    final target = prepared?.target;
    prepared?.release();
    controller.dispose();
    await session.closed;
    expect(target, isNotNull);
    expect(target!.layoutKey, expected.key);
  });

  test(
    'a candidate revoked during turn setup closes without publication',
    () async {
      final h = await PrepareHarness.create();
      h.bytes = fixedSidesPublication(['center']);
      final ready = await h.service.prepare(h.key);
      addTearDown(ready.release);
      final recorder = readerRecorder();
      addTearDown(recorder.dispose);
      late final ReaderProbeController controller;
      controller = ReaderProbeController(
        recorder,
        clockFactory: () {
          // The real PreparedReaderSession already exists at this boundary.
          controller.width += 30;
          return StopwatchTurnClock();
        },
      );
      addTearDown(controller.dispose);
      var releases = 0;
      final opened = await controller.openPublication(
        book: ready,
        activation: h.session,
        isCurrent: h.f.guard.isCurrent,
        acquireLease: () async {
          final lease = (await h.f.cache.acquireHead(h.session, h.key))!;
          return PublicationLease(lease.generation, lease.local, () {
            releases++;
            lease.release();
          });
        },
        queue: h.service.queue,
        worker: h.service.worker.get,
      );
      expect(opened, false);
      expect(controller.session, isNull);
      expect(controller.turn, isNull);
      expect(controller.accepted.value, isNull);
      controller.dispose();
      await h.idle();
      expect(releases, 1);
    },
  );

  testWidgets('replacement detaches the old reader before draining', (
    tester,
  ) async {
    final h = (await tester.runAsync(PrepareHarness.create))!;
    h.bytes = fixedSidesPublication(['center']);
    final ready = (await tester.runAsync(() => h.service.prepare(h.key)))!;
    addTearDown(ready.release);
    final recorder = readerRecorder();
    addTearDown(recorder.dispose);
    final controller = ReaderProbeController(recorder);
    addTearDown(controller.dispose);
    Future<bool> open() => controller.openPublication(
      book: ready,
      activation: h.session,
      isCurrent: h.f.guard.isCurrent,
      acquireLease: () => h.f.cache.acquireHead(h.session, h.key),
      queue: h.service.queue,
      worker: h.service.worker.get,
    );
    expect(await tester.runAsync(open), true);
    final old = controller.session!;
    await tester.pumpWidget(
      MaterialApp(
        home: ListenableBuilder(
          listenable: controller,
          builder: (_, _) {
            final session = controller.session;
            return session == null
                ? const SizedBox()
                : PreparedReader(
                    key: ObjectKey(session),
                    session: session,
                    controller: controller.turn!,
                    closeOnDispose: false,
                  );
          },
        ),
      ),
    );
    expect(find.byType(PreparedReader), findsOneWidget);
    await tester.runAsync(() async {
      final replacement = open();
      await tester.pumpAndSettle();
      expect(await replacement.timeout(const Duration(seconds: 5)), true);
    });
    await tester.pump();
    expect(old.state, TurnSessionState.closed);
    expect(controller.turn!.phase, TurnPhase.idle);
    expect(find.byType(PreparedReader), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      controller.dispose();
      await controller.session!.closed;
    });
  });

  testWidgets('stale fixed opening never falls back to reflow', (tester) async {
    final h = (await tester.runAsync(PrepareHarness.create))!;
    h.bytes = fixedSidesPublication(['center']);
    final ready = (await tester.runAsync(() => h.service.prepare(h.key)))!;
    addTearDown(ready.release);
    final recorder = readerRecorder();
    addTearDown(recorder.dispose);
    final entry = ProbeBook(
      fixtureId: 'chapters',
      sha256: ready.identity.sha256,
      read: () async => h.bytes,
    );
    var reflowOpens = 0;
    await tester.pumpApp(
      ReaderProbeScreen(
        books: _Books(entry),
        recorder: recorder,
        prepareBook: (_) async => ReaderProbePreparation(
          book: ready,
          service: h.service,
          session: ServerSession(
            endpoint: h.session.endpoint,
            generation: h.session.generation + 1,
          ),
        ),
        openBook: (bytes) async {
          reflowOpens++;
          return EpubBook.open(bytes);
        },
      ),
    );
    await tester.pumpAndSettle();
    final l = lookupAppLocalizations(const Locale('zh'));
    await tester.runAsync(() async {
      await tester.tap(find.text(l.readerFixture('chapters')));
      await tester.pumpAndSettle();
    });
    expect(reflowOpens, 0);
    expect(ready.isReleased, true);
    expect(find.byType(PreparedReader), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpApp(const SizedBox());
  });

  test(
    'probe prepares a server book through S3 and opens fixed session',
    () async {
      final h = await PrepareHarness.create();
      h.bytes = fixedSidesPublication(['center']);
      final recorder = readerRecorder(capacity: 1024);
      addTearDown(recorder.dispose);
      final controller = ReaderProbeController(recorder)
        ..width = 600
        ..height = 400
        ..dpr = 1;
      addTearDown(controller.dispose);
      final preparation = await prepareProbeBook(
        key: h.key,
        session: h.session,
        service: h.service,
      );
      expect(preparation.book.identity.bookKey, h.key);
      final opened = await controller.openPublication(
        book: preparation.book,
        activation: h.session,
        isCurrent: preparation.service.guard.isCurrent,
        acquireLease: () async =>
            (await preparation.service.cache()).acquireHead(h.session, h.key),
        queue: preparation.service.queue,
        worker: preparation.service.worker.get,
      );
      expect(opened, true);
      expect(controller.session, isNotNull);
      expect(controller.session!.position.sectionIndex, 0);
      expect(controller.session!.unit!.activeSource.sectionIndex, 0);
      preparation.book.release();
      controller.dispose();
      await controller.session!.closed;
    },
  );
}

class _Books extends ProbeBookRepository {
  _Books(this.entry) : super(TestDirectories(Directory.systemTemp));
  final ProbeBook entry;
  @override
  Future<List<ProbeBook>> list() async => [entry];
}
