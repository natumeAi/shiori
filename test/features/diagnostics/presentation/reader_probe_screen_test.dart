import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/features/diagnostics/data/method_channel_presentation_probe.dart';
import 'package:shiori/features/diagnostics/data/presentation_probe.dart';
import 'package:shiori/features/diagnostics/data/book_digest.dart';
import 'package:shiori/features/diagnostics/data/probe_book_repository.dart';
import 'package:shiori/features/diagnostics/data/reader_export_repository.dart';
import 'package:shiori/features/diagnostics/data/reader_feasibility_record.dart';
import 'package:shiori/features/diagnostics/data/reader_probe_recorder.dart';
import 'package:shiori/features/diagnostics/presentation/reader_probe/reader_probe_screen.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/engine/support/unsupported_layout.dart';
import 'package:shiori/features/reader/engine/surface/prepared_reader.dart';
import 'package:shiori/l10n/l10n.dart';

import '../../../helpers/probe_storage_fixtures.dart';
import '../../../helpers/presentation_probe_fixtures.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/reader_probe_fixtures.dart';

void main() {
  final l = lookupAppLocalizations(const Locale('zh'));
  testWidgets(
    'scripted native stop failure is recoverable without async errors',
    (tester) async {
      const channel = MethodChannel(MethodChannelPresentationProbe.channelName);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'install'
            ? presentationPayload(PresentationMode.inventory)
            : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final recorder = ReaderProbeRecorder(
        engine: readerRecorder(capacity: 1024).engine,
        presentation: MethodChannelPresentationProbe(),
      );
      final exports = _Exports();
      await tester.pumpApp(
        ReaderProbeScreen(
          books: _Books(Future.value([_book('chapters')])),
          exports: exports,
          recorder: recorder,
          openBook: (bytes) async => EpubBook.open(bytes),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.readerFixture('chapters')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(l.readerProbeControls));
      await tester.pumpAndSettle();
      final scenario = tester
          .widgetList<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .singleWhere((w) => w.initialValue == 'R01');
      scenario.onChanged!('R02');
      tester.state<ScaffoldState>(find.byType(Scaffold)).closeEndDrawer();
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.readerStart));
      // Advance actual frames until the capture starts; do not wait for the
      // entire scripted scenario to settle.
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(microseconds: 8333));
      }
      expect(recorder.engine.phase.name, 'recording');
      await tester.tap(find.text(l.diagnosticsStop));
      await tester.pumpAndSettle();
      expect(find.text(l.readerFailure), findsOneWidget);
      expect(exports.records, isEmpty);
      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, l.readerStart),
            )
            .onPressed,
        isNotNull,
      );
      await tester.pumpApp(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'default reader client installs only on capture and uses selected mode',
    (tester) async {
      final calls = <MethodCall>[];
      const channel = MethodChannel(MethodChannelPresentationProbe.channelName);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        if (call.method == 'install') {
          return presentationPayload(PresentationMode.inventory);
        }
        if (call.method == 'stop') {
          return presentationPayload(PresentationMode.b);
        }
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final exports = _Exports();
      await tester.pumpApp(
        ReaderProbeScreen(
          books: _Books(Future.value([_book('chapters')])),
          exports: exports,
          openBook: (bytes) async => EpubBook.open(bytes),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.readerFixture('chapters')));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      await tester.tap(find.byTooltip(l.readerProbeControls));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(l.readerManual));
      await tester.tap(find.text(l.readerManual));
      await tester.pumpAndSettle();
      final selector = find.byType(DropdownButtonFormField<PresentationMode>);
      await tester.ensureVisible(selector);
      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.readerNativeModeName('b')).last);
      await tester.pumpAndSettle();
      tester.state<ScaffoldState>(find.byType(Scaffold)).closeEndDrawer();
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.readerStart));
      await tester.pumpAndSettle();
      expect(calls.map((c) => c.method), ['install', 'start']);
      expect((calls.last.arguments as Map)['mode'], 'b');
      await tester.tap(find.text(l.diagnosticsStop));
      await tester.pumpAndSettle();
      expect(exports.records.single.presentation['mode'], 'b');
      expect(
        exports.records.single.presentation['evidence'],
        PresentationMode.b.evidence,
      );
      await tester.pumpApp(const SizedBox());
      await tester.pumpAndSettle();
      expect(calls.map((c) => c.method), [
        'install',
        'start',
        'stop',
        'dispose',
      ]);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('loading, empty, repository error and retry states', (
    tester,
  ) async {
    final pending = Completer<List<ProbeBook>>();
    final repo = _Books(pending.future);
    await tester.pumpApp(ReaderProbeScreen(books: repo));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete([]);
    await tester.pumpAndSettle();
    expect(find.text(l.readerEmpty), findsOneWidget);
    await tester.pumpApp(const SizedBox());
    final failure = Completer<List<ProbeBook>>();
    final failing = _Books(failure.future);
    await tester.pumpApp(ReaderProbeScreen(books: failing));
    failure.completeError(const ParseException());
    await tester.pumpAndSettle();
    expect(find.text(l.diagnosticsStorageError), findsOneWidget);
    failing.result = Future.value([]);
    await tester.tap(find.text(l.readerBooks));
    await tester.pumpAndSettle();
    expect(find.text(l.readerEmpty), findsOneWidget);
  });
  testWidgets(
    'all settings and declarations are reachable at 200 percent scale',
    (tester) async {
      await tester.pumpApp(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: ReaderProbeScreen(books: _Books(Future.value([]))),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(l.readerProbeControls));
      await tester.pumpAndSettle();
      for (final label in [
        l.readerFont,
        l.readerTheme,
        l.readerReducedMotion,
        l.readerScenario,
        l.readerRepeat,
        l.diagnosticsDeviceModel,
        l.diagnosticsLowPower,
        l.diagnosticsLimitRate,
        l.readerNativeMode,
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.byType(Slider), findsNWidgets(5));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'unsupported layout and broken book are recoverable and never show a reader',
    (tester) async {
      for (final fixture in ['unsupported-vertical', 'chapters']) {
        final book = _book(fixture);
        await tester.pumpApp(
          ReaderProbeScreen(
            books: _Books(Future.value([book])),
            openBook: (bytes) async {
              if (fixture == 'chapters') throw const ParseException();
              final parsed = EpubBook.open(bytes);
              detectBookLayout(parsed).requireSupported();
              return parsed;
            },
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(l.readerFixture(fixture)));
        await tester.pumpAndSettle();
        expect(
          find.text(
            fixture == 'chapters' ? l.readerFailure : l.readerUnsupported,
          ),
          findsOneWidget,
        );
        expect(find.byType(PreparedReader), findsNothing);
        await tester.pumpApp(const SizedBox());
      }
    },
  );
  testWidgets(
    'open, manual capture, drain, export, clipboard and retry failure',
    (tester) async {
      final exports = _Exports();
      final rec = readerRecorder(capacity: 1024);
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
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
      final book = _book('chapters');
      await tester.pumpApp(
        ReaderProbeScreen(
          books: _Books(Future.value([book])),
          exports: exports,
          recorder: rec,
          openBook: (bytes) async => EpubBook.open(bytes),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.readerFixture('chapters')));
      await tester.pumpAndSettle();
      expect(find.byType(PreparedReader), findsOneWidget);
      await tester.tap(find.byTooltip(l.readerProbeControls));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(l.readerManual));
      await tester.tap(find.text(l.readerManual));
      await tester.pumpAndSettle();
      // Dismiss the drawer using the scaffold, then operate the real capture controls.
      tester.state<ScaffoldState>(find.byType(Scaffold)).closeEndDrawer();
      await tester.pumpAndSettle();
      final before = tester.getSize(find.byType(PreparedReader));
      await tester.tap(find.text(l.readerStart));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(PreparedReader)), before);
      await tester.tap(find.text(l.diagnosticsStop));
      await tester.pump(Duration.zero);
      await tester.pumpAndSettle();
      expect(exports.records.single.input, 'manual_touch');
      expect(exports.records.single.engine.scenarioId, 'R01');
      await tester.tap(find.text(l.diagnosticsCopy));
      await tester.pumpAndSettle();
      expect(clipboard, contains('reader_feasibility'));
      ScaffoldMessenger.of(tester.element(find.byType(ReaderProbeScreen)))
          .hideCurrentSnackBar();
      await tester.pumpAndSettle();
      exports.fail = true;
      await tester.tap(find.text(l.diagnosticsExport));
      await tester.pumpAndSettle();
      expect(find.text(l.diagnosticsStorageError), findsOneWidget);
      await tester.pumpApp(const SizedBox());
      await tester.pump(Duration.zero);
      expect(tester.takeException(), isNull);
    },
  );
}

ProbeBook _book(String id) {
  final bytes = File('assets/reader_fixtures/$id.epub').readAsBytesSync();
  return ProbeBook(
    sha256: sha256Hex(bytes),
    fixtureId: id,
    read: () async => bytes,
  );
}

class _Books extends ProbeBookRepository {
  _Books(this.result) : super(TestDirectories(Directory.systemTemp));
  Future<List<ProbeBook>> result;
  @override
  Future<List<ProbeBook>> list() => result;
}

class _Exports extends ReaderExportRepository {
  _Exports() : super(TestDirectories(Directory.systemTemp));
  final records = <ReaderFeasibilityRecord>[];
  bool fail = false;
  @override
  Future<String> export(ReaderFeasibilityRecord record) async {
    if (fail) throw const ParseException();
    records.add(record);
    return '/documents/${ReaderExportRepository.fileName(record)}';
  }
}
