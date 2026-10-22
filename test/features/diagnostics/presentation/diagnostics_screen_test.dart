import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shiori/core/diagnostics/diagnostic_record.dart';
import 'package:shiori/core/diagnostics/diagnostic_recorder.dart';
import 'package:shiori/core/diagnostics/probe_declarations.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/features/diagnostics/data/diagnostic_export_repository.dart';
import 'package:shiori/features/diagnostics/data/probe_marker_repository.dart';
import 'package:shiori/features/diagnostics/presentation/diagnostics_screen.dart';
import 'package:shiori/l10n/app_localizations.dart';

import '../../../helpers/probe_storage_fixtures.dart';
import '../../../helpers/diagnostics_fixtures.dart';
import '../../../helpers/pump_app.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('zh'));
  late MockMarkerRepository marker;
  late MockExportRepository exports;
  late DiagnosticRecorder recorder;
  late List<Override> overrides;
  setUpAll(() => registerFallbackValue(storageRecord()));
  setUp(() {
    marker = MockMarkerRepository();
    exports = MockExportRepository();
    when(marker.load).thenAnswer((_) async => 'retained-marker');
    when(() => marker.save(any())).thenAnswer((_) async {});
    when(exports.loadLast).thenAnswer((_) async => null);
    when(() => exports.export(any()))
        .thenAnswer((_) async => '/documents/export.json');
    recorder = DiagnosticRecorder(
      clock: WidgetProbeClock(),
      source: MockProbeFrameSource(),
      maximumDuration: const Duration(seconds: 2),
      drainDuration: const Duration(milliseconds: 100),
    );
    overrides = [
      probeMarkerRepositoryProvider.overrideWith((ref) => marker),
      diagnosticExportRepositoryProvider.overrideWith((ref) => exports),
      diagnosticRecorderProvider.overrideWith((ref) => recorder),
    ];
  });
  tearDown(() => recorder.dispose());
  Future<void> scrollTo(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(
      find.text(text),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text(text));
    await tester.pump();
  }

  Future<void> start(WidgetTester tester) async {
    await scrollTo(tester, l10n.diagnosticsStart);
    await tester.tap(find.text(l10n.diagnosticsStart));
    await tester.pump(const Duration(milliseconds: 16));
  }

  testWidgets('shows loading then retained marker and saves edits', (
    tester,
  ) async {
    final pending = Completer<String>();
    when(marker.load).thenAnswer((_) => pending.future);
    await tester.pumpApp(const DiagnosticsScreen(), overrides: overrides);
    await scrollTo(tester, l10n.diagnosticsStop);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete('retained-marker');
    await tester.pumpAndSettle();
    await scrollTo(tester, l10n.diagnosticsSaveMarker);
    final input = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == l10n.diagnosticsMarker,
    );
    expect(tester.widget<TextField>(input).controller?.text, 'retained-marker');
    await tester.enterText(input, 'edited-marker');
    await tester.tap(find.text(l10n.diagnosticsSaveMarker));
    await tester.pumpAndSettle();
    verify(() => marker.save('edited-marker')).called(1);
    expect(find.text(l10n.diagnosticsMarkerSaved), findsOneWidget);
  });
  testWidgets('storage error has localized retry and recovery', (tester) async {
    when(marker.load).thenThrow(const ParseException());
    await tester.pumpApp(const DiagnosticsScreen(), overrides: overrides);
    await tester.pumpAndSettle();
    await scrollTo(tester, l10n.commonRetry);
    expect(find.text(l10n.diagnosticsStorageError), findsOneWidget);
    when(marker.load).thenAnswer((_) async => 'recovered');
    await tester.tap(find.text(l10n.commonRetry));
    await tester.pumpAndSettle();
    await scrollTo(tester, l10n.diagnosticsSaveMarker);
    expect(find.text('recovered'), findsOneWidget);
  });
  testWidgets('capture stops, drains, exports and copies matching summary', (
    tester,
  ) async {
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard =
              (call.arguments as Map<Object?, Object?>)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpApp(const DiagnosticsScreen(), overrides: overrides);
    await tester.pumpAndSettle();
    await start(tester);
    expect(recorder.phase, CapturePhase.recording);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, l10n.diagnosticsStart),
          )
          .onPressed,
      isNull,
    );
    expect(find.bySemanticsLabel(l10n.diagnosticsMotion), findsOneWidget);
    await tester.tap(find.text(l10n.diagnosticsStop));
    await tester.pump();
    expect(recorder.phase, CapturePhase.draining);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    final captured =
        verify(() => exports.export(captureAny())).captured.single
            as DiagnosticRecord;
    expect(captured.stopReason, 'user_stop');
    expect(captured.motion, isNotEmpty);
    expect(captured.incompleteTrailingBatch, isTrue);
    expect(captured.metadata['buildNumber'], {
      'value': null,
      'source': 'unavailable_compile_time_define',
    });
    await scrollTo(tester, l10n.diagnosticsCopy);
    expect(
      find.text(l10n.diagnosticsExported('/documents/export.json')),
      findsOneWidget,
    );
    await tester.tap(find.text(l10n.diagnosticsCopy));
    await tester.pumpAndSettle();
    final summary = jsonDecode(clipboard!) as Map<String, Object?>;
    expect(summary['runId'], captured.runId);
    expect(summary['buildId'], captured.buildId);
    expect(summary['fileName'], DiagnosticExportRepository.fileName(captured));
  });
  testWidgets(
    'motion reads current engine identity only after ticker callbacks',
    (tester) async {
      var engineFrameNumber = 40;
      final reads = <int>[];
      final source = DiagnosticTestFrameSource();
      recorder = DiagnosticRecorder(
        clock: WidgetProbeClock(),
        source: source,
        drainDuration: const Duration(milliseconds: 100),
      );
      await tester.pumpApp(
        DiagnosticsScreen(
          frameNumberForTesting: () {
            expect(
              tester.binding.schedulerPhase,
              SchedulerPhase.postFrameCallbacks,
            );
            reads.add(engineFrameNumber);
            return engineFrameNumber;
          },
        ),
        overrides: overrides,
      );
      await tester.pumpAndSettle();
      await scrollTo(tester, l10n.diagnosticsStart);
      await tester.tap(find.text(l10n.diagnosticsStart));
      for (var i = 0; i < 5; i++) {
        final current = 41 + i;
        tester.binding.scheduleFrameCallback((_) {
          expect(engineFrameNumber, current - 1);
          // Mirrors the engine updating frameData after begin-frame callbacks.
          scheduleMicrotask(() => engineFrameNumber = current);
        });
        await tester.pump(const Duration(microseconds: 8333));
        final targetUs =
            tester.binding.currentSystemFrameTimeStamp.inMicroseconds;
        source.emit([diagnosticTiming(targetUs - 8333, frameNumber: current)]);
      }
      await tester.tap(find.text(l10n.diagnosticsStop));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      final record = (await recorder.completed)!;
      expect(reads, [41, 42, 43, 44, 45]);
      expect(record.motion.map((m) => m.frameNumber), reads);
      expect(
        record.motion.last.progress,
        greaterThan(record.motion.first.progress),
      );
      for (var i = 0; i < record.motion.length; i++) {
        expect(
          record.motion[i].rawSchedulerUs,
          record.frames[i].vsyncUs + 8333,
        );
      }
      expect(record.aggregates['correlatedMotionFrames'], 5);
      expect(record.aggregates['vsyncIntervals'], containsPair('count', 4));
      expect(record.aggregates['cadencePattern'], 'observed_near_120hz');
    },
  );

  testWidgets('queued motion is ignored after same-frame lifecycle stop', (
    tester,
  ) async {
    var reads = 0;
    await tester.pumpApp(
      DiagnosticsScreen(frameNumberForTesting: () => ++reads),
      overrides: overrides,
    );
    await tester.pumpAndSettle();
    await start(tester);
    final before = reads;
    tester.binding.addPostFrameCallback((_) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    });
    await tester.pump(const Duration(microseconds: 8333));
    expect(reads, before);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    final first = (await recorder.completed)!;
    expect(first.motion, hasLength(before));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await start(tester);
    await tester.tap(find.text(l10n.diagnosticsStop));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    final second = (await recorder.completed)!;
    expect(second.runId, isNot(first.runId));
    expect(
      second.motion.map((m) => m.frameNumber),
      everyElement(greaterThan(before)),
    );
  });

  testWidgets('dispose before queued post-frame motion never reads identity', (
    tester,
  ) async {
    var reads = 0;
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    await tester.pumpApp(
      ValueListenableBuilder<bool>(
        valueListenable: visible,
        builder: (_, show, _) => show
            ? DiagnosticsScreen(frameNumberForTesting: () => ++reads)
            : const SizedBox(),
      ),
      overrides: overrides,
    );
    await tester.pumpAndSettle();
    await start(tester);
    final before = reads;
    tester.binding.scheduleFrameCallback((_) {
      // After ticker queues motion, before build disposes the screen.
      scheduleMicrotask(() => visible.value = false);
    });
    await tester.pump(const Duration(microseconds: 8333));
    expect(reads, before);
    expect(recorder.phase, CapturePhase.disposed);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'auto duration stops animation and background never restarts capture',
    (tester) async {
      await tester.pumpApp(const DiagnosticsScreen(), overrides: overrides);
      await tester.pumpAndSettle();
      await start(tester);
      await tester.pump(const Duration(seconds: 2));
      expect(recorder.phase, CapturePhase.draining);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      final first = await recorder.completed;
      expect(first?.stopReason, 'duration_limit');
      await start(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect((await recorder.completed)?.stopReason, 'lifecycle_inactive');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(recorder.phase, CapturePhase.finished);
    },
  );
  testWidgets('failed export preserves partial record and can retry', (
    tester,
  ) async {
    when(() => exports.export(any())).thenThrow(const ParseException());
    await tester.pumpApp(const DiagnosticsScreen(), overrides: overrides);
    await tester.pumpAndSettle();
    await start(tester);
    await tester.tap(find.text(l10n.diagnosticsStop));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text(l10n.diagnosticsStorageError), findsOneWidget);
    await scrollTo(tester, l10n.diagnosticsExport);
    expect(find.text(l10n.diagnosticsPartial), findsOneWidget);
    when(() => exports.export(any()))
        .thenAnswer((_) async => '/documents/retry.json');
    await tester.tap(find.text(l10n.diagnosticsExport));
    await tester.pumpAndSettle();
    expect(
      find.text(l10n.diagnosticsExported('/documents/retry.json')),
      findsOneWidget,
    );
  });
  testWidgets('declaration edits are frozen into the captured record', (
    tester,
  ) async {
    await tester.pumpApp(const DiagnosticsScreen(), overrides: overrides);
    await tester.pumpAndSettle();
    final device = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == l10n.diagnosticsDeviceModel,
    );
    await tester.enterText(device, 'fixture phone');
    final lowPower = find.ancestor(
      of: find.text(l10n.diagnosticsLowPower),
      matching: find.byType(DropdownButtonFormField<DeclaredSetting>),
    );
    await Scrollable.ensureVisible(tester.element(lowPower), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(lowPower);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.diagnosticsOff).last);
    await tester.pumpAndSettle();
    await start(tester);
    await tester.tap(find.text(l10n.diagnosticsStop));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    final record =
        verify(() => exports.export(captureAny())).captured.single
            as DiagnosticRecord;
    expect(record.declarations.deviceModel, 'fixture phone');
    expect(record.declarations.lowPowerMode, DeclaredSetting.off);
    expect(record.declarations.limitFrameRate, DeclaredSetting.unknown);
    expect(record.declarations.source, 'user_provided');
    expect(record.metadata['deviceModelSource'], 'user_provided');
  });
  testWidgets('dispose during async export does not publish stale UI', (
    tester,
  ) async {
    final pending = Completer<String>();
    when(() => exports.export(any())).thenAnswer((_) => pending.future);
    await tester.pumpApp(const DiagnosticsScreen(), overrides: overrides);
    await tester.pumpAndSettle();
    await start(tester);
    await tester.tap(find.text(l10n.diagnosticsStop));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    verify(() => exports.export(any())).called(1);
    await tester.pumpWidget(const SizedBox());
    pending.complete('/documents/late.json');
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(recorder.phase, CapturePhase.disposed);
  });
  testWidgets('marker save error remains editable at 200 percent text scale', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    when(() => marker.save(any())).thenThrow(const ParseException());
    await tester.pumpApp(const DiagnosticsScreen(), overrides: overrides);
    await tester.pumpAndSettle();
    await scrollTo(tester, l10n.diagnosticsSaveMarker);
    await tester.tap(find.text(l10n.diagnosticsSaveMarker));
    await tester.pumpAndSettle();
    expect(find.text(l10n.diagnosticsStorageError), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, l10n.diagnosticsSaveMarker),
          )
          .onPressed,
      isNotNull,
    );
  });
}
