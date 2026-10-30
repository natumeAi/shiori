import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/features/diagnostics/data/book_digest.dart';
import 'package:shiori/features/diagnostics/data/probe_book_repository.dart';
import 'package:shiori/features/diagnostics/data/reader_export_repository.dart';
import 'package:shiori/features/diagnostics/data/reader_feasibility_record.dart';
import 'package:shiori/features/diagnostics/presentation/reader_probe/reader_probe_controller.dart';
import 'package:shiori/features/diagnostics/presentation/reader_probe/reader_probe_controls.dart';
import 'package:shiori/features/diagnostics/presentation/reader_probe/reader_probe_screen.dart';
import 'package:shiori/features/reader/engine/surface/prepared_reader.dart';
import 'package:shiori/l10n/l10n.dart';

import '../../../helpers/probe_storage_fixtures.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/reader_probe_fixtures.dart';
import '../../library/data/publications/prepare_test_support.dart';
import '../../reader/engine/surface/publication_fixed_test_support.dart';

void main() {
  testWidgets(
    'failed scripted replacement starts no capture on retired identity',
    (tester) async {
      final h = (await tester.runAsync(PrepareHarness.create))!;
      h.bytes = fixedSidesPublication(['center']);
      final ready = (await tester.runAsync(() => h.service.prepare(h.key)))!;
      addTearDown(ready.release);
      final entry = ProbeBook(
        sha256: sha256Hex(h.bytes),
        fixtureId: 'chapters',
        read: () async => h.bytes,
      );
      final recorder = readerRecorder(capacity: 1024);
      final exports = _Exports();
      var preparations = 0;
      await tester.pumpApp(
        ReaderProbeScreen(
          books: _Books(entry),
          recorder: recorder,
          exports: exports,
          prepareBook: (_) async {
            if (++preparations > 1) throw const ParseException();
            return ReaderProbePreparation(
              book: ready,
              session: h.session,
              service: h.service,
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      final l = lookupAppLocalizations(const Locale('zh'));
      await tester.runAsync(() async {
        await tester.tap(find.text(l.readerFixture('chapters')));
        for (
          var i = 0;
          i < 200 && find.byType(PreparedReader).evaluate().isEmpty;
          i++
        ) {
          await tester.pump(const Duration(microseconds: 8333));
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        await tester.pumpAndSettle();
      });
      await tester.tap(find.byTooltip(l.readerProbeControls));
      await tester.pumpAndSettle();
      final controls = tester.widget<ReaderProbeControls>(
        find.byType(ReaderProbeControls),
      );
      controls.onScenario('R02');
      tester.state<ScaffoldState>(find.byType(Scaffold)).closeEndDrawer();
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text(l.readerStart));
        for (
          var i = 0;
          i < 100 && find.text(l.readerFailure).evaluate().isEmpty;
          i++
        ) {
          await tester.pump(const Duration(microseconds: 8333));
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        await tester.pumpAndSettle();
      });
      expect(find.text(l.readerFailure), findsOneWidget);
      expect(recorder.engine.phase.name, 'idle');
      expect(exports.records, isEmpty);
      expect(controls.controller.session, isNull);
      await tester.runAsync(() async {
        await tester.pumpApp(const SizedBox());
        await h.idle();
      });
      expect(tester.takeException(), isNull);
    },
  );

  for (final mixed in [false, true]) {
    for (final manual in [false, true]) {
      testWidgets(
        'publication capture uses displayed identity mixed=$mixed manual=$manual',
        (tester) async {
          final h = (await tester.runAsync(PrepareHarness.create))!;
          h.bytes = mixed
              ? corpusPublication('mixed-navigation-positive')
              : fixedSidesPublication(['center', 'center']);
          final ready = (await tester.runAsync(
            () => h.service.prepare(h.key),
          ))!;
          addTearDown(ready.release);
          final entry = ProbeBook(
            sha256: sha256Hex(h.bytes),
            fixtureId: 'chapters',
            read: () async => h.bytes,
          );
          final recorder = readerRecorder(capacity: 1024);
          final exports = _Exports();
          var preparations = 0;
          await tester.pumpApp(
            ReaderProbeScreen(
              books: _Books(entry),
              recorder: recorder,
              exports: exports,
              prepareBook: (_) async {
                preparations++;
                if (preparations == 1) {
                  return ReaderProbePreparation(
                    book: ready,
                    session: h.session,
                    service: h.service,
                  );
                }
                return prepareProbeBook(
                  key: h.key,
                  session: h.session,
                  service: h.service,
                );
              },
            ),
          );
          await tester.pumpAndSettle();
          final l = lookupAppLocalizations(const Locale('zh'));
          await tester.runAsync(() async {
            await tester.tap(find.text(l.readerFixture('chapters')));
            for (
              var i = 0;
              i < 200 && find.byType(PreparedReader).evaluate().isEmpty;
              i++
            ) {
              await tester.pump(const Duration(microseconds: 8333));
              await Future<void>.delayed(const Duration(milliseconds: 5));
            }
            await tester.pumpAndSettle();
          });
          expect(find.byType(PreparedReader), findsOneWidget);
          await tester.tap(find.byTooltip(l.readerProbeControls));
          await tester.pumpAndSettle();
          final controls = tester.widget<ReaderProbeControls>(
            find.byType(ReaderProbeControls),
          );
          final controller = controls.controller;
          await tester.runAsync(() async {
            var jumped = false;
            final jumping = controller.jump(1).whenComplete(() {
              jumped = true;
            });
            for (var i = 0; i < 200 && !jumped; i++) {
              await tester.pump(const Duration(microseconds: 8333));
              await Future<void>.delayed(const Duration(milliseconds: 5));
            }
            expect(jumped, true);
            await jumping;
          });
          controls.onScenario('R02');
          controls.onRepeats(1);
          controls.onManual(manual);
          tester.state<ScaffoldState>(find.byType(Scaffold)).closeEndDrawer();
          await tester.pumpAndSettle();
          if (manual) {
            final beforeResize = controller.session!;
            tester.view.physicalSize = const Size(1000, 800);
            addTearDown(tester.view.resetPhysicalSize);
            await tester.runAsync(() async {
              for (
                var i = 0;
                i < 200 &&
                    (controller.session == null ||
                        controller.session == beforeResize ||
                        tester
                                .widget<FilledButton>(
                                  find.widgetWithText(
                                    FilledButton,
                                    l.readerStart,
                                  ),
                                )
                                .onPressed ==
                            null);
                i++
              ) {
                await tester.pump(const Duration(microseconds: 8333));
                await Future<void>.delayed(const Duration(milliseconds: 5));
              }
            });
            expect(controller.session, isNot(same(beforeResize)));
            expect(controller.session, isNotNull);
            expect(controller.accepted.value!.sectionIndex, 1);
            expect(
              controller.session!.frames.value.current.layout.viewportWidth,
              controller.width,
            );
          }
          final beforeCapture = controller.session;
          await tester.runAsync(() async {
            await tester.tap(find.text(l.readerStart));
            for (
              var i = 0;
              i < 80 && recorder.engine.phase.name != 'recording';
              i++
            ) {
              await tester.pump(const Duration(microseconds: 8333));
              await Future<void>.delayed(const Duration(milliseconds: 5));
            }
            for (
              var i = 0;
              i < 200 &&
                  (controller.session == beforeCapture ||
                      controller.session == null ||
                      controller.session!.position.sectionIndex != 1);
              i++
            ) {
              await tester.pump(const Duration(microseconds: 8333));
              await Future<void>.delayed(const Duration(milliseconds: 5));
            }
          });
          expect(recorder.engine.phase.name, 'recording');
          expect(preparations, manual ? 1 : 2);
          expect(controller.identity!.sha256 == entry.sha256, true);
          expect(controller.identity!.fixtureId, 'chapters');
          expect(controller.accepted.value!.sectionIndex, 1);
          expect(
            controller.accepted.value!.layoutKey,
            controller.session!.position.layoutKey,
          );
          expect(controller.session!.unit, isNotNull);
          await tester.runAsync(() async {
            await tester.tap(find.text(l.diagnosticsStop));
            for (var i = 0; i < 200 && exports.records.isEmpty; i++) {
              await tester.pump(const Duration(microseconds: 8333));
              await Future<void>.delayed(const Duration(milliseconds: 5));
            }
            await tester.pumpAndSettle();
          });
          expect(exports.records, hasLength(1));
          expect(exports.records.single.bookSha256 == entry.sha256, true);
          expect(exports.records.single.fixtureId, 'chapters');
          expect(tester.takeException(), isNull);
          await tester.runAsync(() async {
            await tester.pumpApp(const SizedBox());
            await controller.session!.closed;
            await h.idle();
          });
        },
      );
    }
  }
}

class _Books extends ProbeBookRepository {
  _Books(this.entry) : super(TestDirectories(Directory.systemTemp));
  final ProbeBook entry;
  @override
  Future<List<ProbeBook>> list() async => [entry];
}

class _Exports extends ReaderExportRepository {
  _Exports() : super(TestDirectories(Directory.systemTemp));
  final records = <ReaderFeasibilityRecord>[];
  @override
  Future<String> export(ReaderFeasibilityRecord record) async {
    records.add(record);
    return 'synthetic.json';
  }
}
