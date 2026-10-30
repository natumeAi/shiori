import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/features/diagnostics/data/probe_book_repository.dart';
import 'package:shiori/features/diagnostics/presentation/reader_probe/reader_probe_controller.dart';
import 'package:shiori/features/diagnostics/presentation/reader_probe/reader_probe_controls.dart';
import 'package:shiori/features/diagnostics/presentation/reader_probe/reader_probe_screen.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_test_hooks.dart';
import 'package:shiori/features/reader/engine/surface/prepared_reader.dart';
import 'package:shiori/l10n/l10n.dart';

import '../../../helpers/probe_storage_fixtures.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/reader_probe_fixtures.dart';
import '../../library/data/publications/prepare_test_support.dart';
import '../../reader/engine/surface/publication_fixed_test_support.dart';

void main() {
  test(
    'latest cancelled replacement reports typed failure and can retry',
    () async {
      final h = await PrepareHarness.create();
      h.bytes = fixedSidesPublication(['center', 'center']);
      final ready = await h.service.prepare(h.key);
      addTearDown(ready.release);
      final recorder = readerRecorder();
      addTearDown(recorder.dispose);
      final controller = ReaderProbeController(recorder);
      addTearDown(controller.dispose);
      var current = true;
      var acquisitions = 0;
      expect(
        await controller.openPublication(
          book: ready,
          activation: h.session,
          isCurrent: (session) => current && h.f.guard.isCurrent(session),
          acquireLease: () async {
            acquisitions++;
            if (acquisitions == 3) current = false;
            return h.f.cache.acquireHead(h.session, h.key);
          },
          queue: h.service.queue,
          worker: h.service.worker.get,
          section: 1,
        ),
        true,
      );
      final position = controller.accepted.value;
      await expectLater(
        controller.reflow(controller.settings),
        throwsA(isA<ParseException>()),
      );
      expect(controller.session, isNull);
      expect(controller.accepted.value, same(position));
      current = true;
      await controller.reflow(controller.settings);
      expect(controller.session, isNotNull);
      expect(controller.accepted.value!.sectionIndex, 1);
      final session = controller.session!;
      controller.dispose();
      await session.closed;
      await h.idle();
      expect(
        session.pool.resourceBudget.used.values.every((n) => n == 0),
        true,
      );
    },
  );

  for (final changes in [2, 3]) {
    for (final settings in [false, true]) {
      testWidgets('coalesces $changes metrics changes settings=$settings', (
        tester,
      ) async {
        Future<void> pumpUntil(bool Function() done) async {
          final elapsed = Stopwatch()..start();
          while (!done() && elapsed.elapsed < const Duration(seconds: 10)) {
            await tester.pump(const Duration(milliseconds: 16));
            await Future<void>(() {});
          }
          expect(done(), true);
          await tester.pump();
        }

        final events = ReceivePort();
        addTearDown(events.close);
        var armed = false;
        final paused = Completer<PublicationWorkerPreloadEvent>();
        final subscription = events.listen((value) {
          if (value is! PublicationWorkerPreloadEvent) return;
          if (armed && !paused.isCompleted) {
            paused.complete(value);
          } else {
            value.resume.send(null);
          }
        });
        addTearDown(subscription.cancel);
        final h = (await tester.runAsync(
          () => PrepareHarness.create(
            workerHooks: PublicationWorkerTestHooks(
              events.sendPort,
              pausePreload: true,
            ),
          ),
        ))!;
        h.bytes = fixedSidesPublication(['center', 'center']);
        final ready = (await tester.runAsync(() => h.service.prepare(h.key)))!;
        addTearDown(ready.release);
        final recorder = readerRecorder();
        addTearDown(recorder.dispose);
        final entry = ProbeBook(
          fixtureId: 'chapters',
          sha256: ready.identity.sha256,
          read: () async => h.bytes,
        );
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1000, 1000);
        await tester.pumpApp(
          ReaderProbeScreen(
            books: _Books(entry),
            recorder: recorder,
            prepareBook: (_) async => ReaderProbePreparation(
              book: ready,
              session: h.session,
              service: h.service,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final l = lookupAppLocalizations(const Locale('zh'));
        await tester.runAsync(() async {
          await tester.tap(find.text(l.readerFixture('chapters')));
          await pumpUntil(
            () => find.byType(PreparedReader).evaluate().isNotEmpty,
          );
        });
        expect(find.byType(PreparedReader), findsOneWidget);
        await tester.tap(find.byIcon(Icons.tune));
        await tester.pumpAndSettle();
        final controls = tester.widget<ReaderProbeControls>(
          find.byType(ReaderProbeControls),
        );
        final controller = controls.controller;
        await tester.runAsync(() async {
          final jumping = controller.jump(1);
          await pumpUntil(() => controller.session?.position.sectionIndex == 1);
          await jumping;
        });
        Navigator.of(tester.element(find.byType(ReaderProbeControls))).pop();
        await tester.pumpAndSettle();
        final original = controller.accepted.value!;
        final nextSettings = controller.settings.copyWith(fontSize: 26);
        final published = Completer<void>();
        void changed() {
          final layout = controller.session?.frames.value.current.layout;
          if (layout != null &&
              layout.viewportWidth == controller.width &&
              (!settings || layout.settings == nextSettings) &&
              !published.isCompleted) {
            published.complete();
          }
        }

        controller.addListener(changed);
        armed = true;
        await tester.runAsync(() async {
          tester.view.physicalSize = const Size(1020, 1000);
          await pumpUntil(() => paused.isCompleted);
          final event = await paused.future.timeout(
            const Duration(seconds: 10),
          );
          expect(controller.session, isNull);
          for (var i = 1; i < changes; i++) {
            tester.view.physicalSize = Size(1020 + i * 20, 1000 + i * 20);
            await tester.pump();
            if (settings && i == 1) {
              controls.onSettings(nextSettings);
              await tester.pump();
            }
          }
          event.resume.send(null);
          await pumpUntil(() => published.isCompleted);
        });
        controller.removeListener(changed);
        await tester.pumpAndSettle();
        expect(controller.session, isNotNull);
        expect(controller.accepted.value!.sectionIndex, original.sectionIndex);
        expect(controller.accepted.value!.cfi, original.cfi);
        final layout = controller.session!.frames.value.current.layout;
        expect(layout.viewportWidth, controller.width);
        expect(layout.viewportHeight, controller.height);
        expect(layout.settings, settings ? nextSettings : controller.settings);
        expect(find.byType(PreparedReader), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final session = controller.session!;
          await tester.pumpApp(const SizedBox());
          await session.closed;
          await h.idle();
          expect(
            session.pool.resourceBudget.used.values.every((n) => n == 0),
            true,
          );
        });
      });
    }
  }
}

class _Books extends ProbeBookRepository {
  _Books(this.entry) : super(TestDirectories(Directory.systemTemp));
  final ProbeBook entry;
  @override
  Future<List<ProbeBook>> list() async => [entry];
}
