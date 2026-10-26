import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/diagnostics/diagnostic_recorder.dart';
import 'package:shiori/core/diagnostics/probe_declarations.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/features/diagnostics/data/method_channel_presentation_probe.dart';
import 'package:shiori/features/diagnostics/data/presentation_probe.dart';
import 'package:shiori/features/diagnostics/data/reader_export_repository.dart';
import 'package:shiori/features/diagnostics/data/reader_probe_recorder.dart';

import '../../../helpers/diagnostics_fixtures.dart';
import '../../../helpers/presentation_probe_fixtures.dart';
import '../../../helpers/probe_storage_fixtures.dart';
import '../../../helpers/reader_probe_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel(MethodChannelPresentationProbe.channelName);
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  for (final mode in PresentationMode.values) {
    test(
      'Documents export retains ${mode.name} evidence and overflow',
      () async {
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'install') {
            return presentationPayload(PresentationMode.inventory);
          }
          if (call.method == 'stop') {
            return presentationPayload(mode, overflow: 9);
          }
          return null;
        });
        final recorder = _recorder();
        addTearDown(recorder.dispose);
        await _start(recorder, mode);
        final record = (await recorder.stop())!;
        final root = await Directory.systemTemp.createTemp(
          'presentation-export-',
        );
        addTearDown(() => root.delete(recursive: true));
        final repo = ReaderExportRepository(TestDirectories(root));
        final path = await repo.export(record);
        final decoded = ReaderExportRepository.decode(
          await File(path).readAsString(),
        );
        expect(decoded.presentation['mode'], mode.name);
        expect(decoded.presentation['evidence'], mode.evidence);
        expect(
          decoded.presentation['samples'],
          presentationPayload(mode)['samples'],
        );
        expect(
          decoded.presentation['clock'],
          'native_monotonic_seconds; epoch not correlated with Dart',
        );
        expect(decoded.presentation['overflow'], 9);
        expect(decoded.presentation['contentionDrops'], 1);
        expect(decoded.overflow['native'], 9);
        expect(decoded.omissions['native'], isNull);
        expect(decoded.presentation['physicalPresentation'], 'unverified');
        expect(decoded.presentation['touchToPhoton'], 'unverified');
      },
    );
  }

  test('mode mismatch omission survives export', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'install') {
        return presentationPayload(PresentationMode.inventory);
      }
      if (call.method == 'stop') {
        return presentationPayload(
          PresentationMode.b,
          omission: 'requires_cametal_variant',
        );
      }
      return null;
    });
    final recorder = _recorder();
    addTearDown(recorder.dispose);
    await _start(recorder, PresentationMode.b);
    final record = (await recorder.stop())!;
    expect(record.presentation['mode'], 'b');
    expect(record.presentation['available'], false);
    expect(record.omissions['native'], 'requires_cametal_variant');
  });

  test('missing plugin still exports selected mode and omission', () async {
    final recorder = _recorder();
    addTearDown(recorder.dispose);
    await _start(recorder, PresentationMode.a2);
    final record = (await recorder.stop())!;
    expect(record.presentation['mode'], 'a2');
    expect(record.presentation['evidence'], PresentationMode.a2.evidence);
    expect(record.omissions['native'], 'missing_plugin_install');
  });

  test(
    'malformed stop resolves capture with a typed error and allows restart',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'install'
            ? presentationPayload(PresentationMode.inventory)
            : null,
      );
      final recorder = _recorder();
      addTearDown(recorder.dispose);
      await _start(recorder, PresentationMode.a1);
      await expectLater(recorder.stop(), throwsA(isA<ParseException>()));
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'stop'
            ? presentationPayload(PresentationMode.a1)
            : null,
      );
      await _start(recorder, PresentationMode.a1);
      expect((await recorder.stop())!.presentation['available'], true);
    },
  );
}

ReaderProbeRecorder _recorder() => ReaderProbeRecorder(
  engine: DiagnosticRecorder(
    clock: DiagnosticTestClock(),
    source: DiagnosticTestFrameSource(),
    drainDuration: Duration.zero,
  ),
  presentation: MethodChannelPresentationProbe(),
);

Future<void> _start(ReaderProbeRecorder recorder, PresentationMode mode) =>
    recorder.start(
      runId: 'presentation-export',
      bookSha256: readerDigest,
      fixtureId: 'chapters',
      scenarioId: 'R01',
      repeatIndex: 1,
      repeatCount: 3,
      input: 'synthetic_injected',
      declarations: const ProbeDeclarations(),
      metadata: const {},
      mode: mode,
    );
