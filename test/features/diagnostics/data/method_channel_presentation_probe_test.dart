import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/features/diagnostics/data/method_channel_presentation_probe.dart';
import 'package:shiori/features/diagnostics/data/presentation_probe.dart';

import '../../../helpers/presentation_probe_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel(MethodChannelPresentationProbe.channelName);
  late MethodChannelPresentationProbe probe;
  late List<MethodCall> calls;
  Object? payload = presentationPayload(PresentationMode.inventory);
  setUp(() {
    probe = MethodChannelPresentationProbe();
    calls = [];
    payload = presentationPayload(PresentationMode.inventory);
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'install' || call.method == 'stop' ? payload : null;
    });
  });
  tearDown(() async {
    await probe.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  });

  for (final mode in PresentationMode.values) {
    test('sequence and raw payload for ${mode.name}', () async {
      final installed = await probe.install();
      expect(installed.evidence, 'metadata');
      await probe.install();
      await probe.start(runId: 'test', mode: mode);
      payload = presentationPayload(mode, overflow: 7);
      final report = await probe.stop();
      expect(report.available, true);
      expect(report.evidence, mode.evidence);
      expect(report.overflow, 7);
      expect(report.contentionDrops, 1);
      expect(report.samples, (payload as Map)['samples']);
      if (mode == PresentationMode.b) {
        expect(report.samples.last['presentedTime'], 0.0);
        expect(report.samples.first['drawableId'], '18446744073709551615');
      }
      expect(identical(await probe.stop(), report), true);
      await probe.dispose();
      await probe.dispose();
      expect(calls.map((c) => c.method), [
        'install',
        'start',
        'stop',
        'dispose',
      ]);
      expect(calls[1].arguments, {'runId': 'test', 'mode': mode.name});
      await expectLater(probe.install(), throwsStateError);
    });
  }

  test('unmatched callbacks are exported separately from ring loss', () async {
    await probe.install();
    await probe.start(runId: 'test', mode: PresentationMode.b);
    payload = {
      ...presentationPayload(PresentationMode.b),
      'unmatchedCallbacks': 4,
    };
    final report = await probe.stop();
    expect(report.overflow, 0);
    expect(report.unmatchedCallbacks, 4);
    expect(report.toJson()['unmatchedCallbacks'], 4);
  });

  test('negative unmatched callback count is rejected', () async {
    await probe.install();
    await probe.start(runId: 'test', mode: PresentationMode.b);
    payload = {
      ...presentationPayload(PresentationMode.b),
      'unmatchedCallbacks': -1,
    };
    await expectLater(probe.stop(), throwsA(isA<ParseException>()));
  });

  test('native mode omission stays explicit with inventory', () async {
    await probe.install();
    await probe.start(runId: 'test', mode: PresentationMode.b);
    payload = presentationPayload(
      PresentationMode.b,
      omission: 'requires_cametal_variant',
    );
    final report = await probe.stop();
    expect(report.available, false);
    expect(report.omission, 'requires_cametal_variant');
    expect(report.inventory['layerClass'], isNotNull);
  });

  test('construction and unused disposal never install', () async {
    await probe.dispose();
    expect(calls, isEmpty);
  });

  test('missing plugin uses unavailable fallback', () async {
    messenger.setMockMethodCallHandler(channel, null);
    final installed = await probe.install();
    expect(installed.available, false);
    expect(installed.omission, 'missing_plugin_install');
    await probe.start(runId: 'test', mode: PresentationMode.a2);
    final report = await probe.stop();
    expect(report.available, false);
    expect(report.evidence, PresentationMode.a2.evidence);
    expect(report.omission, 'missing_plugin_install');
  });

  for (final method in ['install', 'start', 'stop', 'dispose']) {
    test(
      'platform error at $method is unavailable without error details',
      () async {
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == method) {
            throw PlatformException(code: 'test', message: 'not exported');
          }
          return call.method == 'install'
              ? presentationPayload(PresentationMode.inventory)
              : presentationPayload(PresentationMode.a1);
        });
        await probe.install();
        await probe.start(runId: 'test', mode: PresentationMode.a1);
        final report = await probe.stop();
        if (method != 'dispose') {
          expect(report.available, false);
          expect(report.omission, 'platform_error_$method');
        }
        await probe.dispose();
      },
    );
  }

  final invalid = <String, Object?>{
    'null': null,
    'not map': [],
    'missing fields': <String, Object?>{},
    'non-string key': <Object?, Object?>{1: true},
    for (final entry in <String, Object?>{
      'mode': 'b',
      'evidence': 'metadata',
      'available': 1,
      'omission': 'bad',
      'inventory': {},
      'samples': null,
      'overflow': -1,
      'contentionDrops': 1,
    }.entries)
      entry.key: {
        ...presentationPayload(PresentationMode.a1),
        entry.key: entry.value,
      },
    'negative timestamp': {
      ...presentationPayload(PresentationMode.a1),
      'samples': [
        {'kind': 'layer_commit', 'timestamp': -1.0},
      ],
    },
    'nonfinite timestamp': {
      ...presentationPayload(PresentationMode.a1),
      'samples': [
        {'kind': 'layer_commit', 'timestamp': double.nan},
      ],
    },
    'wrong sample kind': {
      ...presentationPayload(PresentationMode.a1),
      'samples': [
        {'kind': 'display_link', 'timestamp': 1.0, 'targetTimestamp': 2.0},
      ],
    },
    'unavailable without reason': {
      ...presentationPayload(PresentationMode.a1),
      'available': false,
    },
  };
  for (final entry in invalid.entries) {
    test('malformed ${entry.key} is a typed parse failure', () async {
      await probe.install();
      await probe.start(runId: 'test', mode: PresentationMode.a1);
      payload = entry.value;
      await expectLater(probe.stop(), throwsA(isA<ParseException>()));
    });
  }

  test('malformed install is rejected', () async {
    payload = null;
    await expectLater(probe.install(), throwsA(isA<ParseException>()));
  });

  for (final (name, mode, sample)
      in <(String, PresentationMode, Map<String, Object?>)>[
        (
          'A2 reversed period',
          PresentationMode.a2,
          {'kind': 'display_link', 'timestamp': 2.0, 'targetTimestamp': 1.0},
        ),
        (
          'B negative presentedTime',
          PresentationMode.b,
          {
            'kind': 'drawable',
            'timestamp': 1.0,
            'drawableId': '1',
            'presentedTime': -1,
          },
        ),
        (
          'B numeric ID',
          PresentationMode.b,
          {
            'kind': 'drawable',
            'timestamp': 1.0,
            'drawableId': 1,
            'presentedTime': 0,
          },
        ),
        (
          'B overflowing ID',
          PresentationMode.b,
          {
            'kind': 'drawable',
            'timestamp': 1.0,
            'drawableId': '18446744073709551616',
            'presentedTime': 0,
          },
        ),
        (
          'extra sample fields',
          PresentationMode.a1,
          {
            'kind': 'layer_commit',
            'timestamp': 1.0,
            'unrecognized': 'excluded',
          },
        ),
        (
          'unknown sample kind',
          PresentationMode.a1,
          {'kind': 'unknown', 'timestamp': 1.0},
        ),
      ]) {
    test('rejects $name', () async {
      await probe.install();
      await probe.start(runId: 'test', mode: mode);
      payload = {
        ...presentationPayload(mode),
        'samples': [sample],
      };
      await expectLater(probe.stop(), throwsA(isA<ParseException>()));
    });
  }

  test('A2 requires both streams and bounds the sample count', () async {
    await probe.install();
    for (final samples in [
      <Map<String, Object?>>[],
      [
        {'kind': 'layer_commit', 'timestamp': 1.0},
      ],
      List.filled(16385, {'kind': 'layer_commit', 'timestamp': 1.0}),
    ]) {
      await probe.start(runId: 'test', mode: PresentationMode.a2);
      payload = {
        ...presentationPayload(PresentationMode.a2),
        'samples': samples,
      };
      await expectLater(probe.stop(), throwsA(isA<ParseException>()));
    }
  });

  test('available B requires the alternate layer and plist value', () async {
    await probe.install();
    await probe.start(runId: 'test', mode: PresentationMode.b);
    payload = {
      ...presentationPayload(PresentationMode.b),
      'inventory': presentationPayload(PresentationMode.inventory)['inventory'],
    };
    await expectLater(probe.stop(), throwsA(isA<ParseException>()));
  });

  test('lifecycle misuse is rejected before channel traffic', () async {
    await expectLater(
      probe.start(runId: 'test', mode: PresentationMode.a1),
      throwsStateError,
    );
    await expectLater(probe.stop(), throwsStateError);
    expect(calls, isEmpty);
    await probe.install();
    await expectLater(
      probe.start(runId: '', mode: PresentationMode.a1),
      throwsArgumentError,
    );
    await probe.start(runId: 'test', mode: PresentationMode.a1);
    await expectLater(
      probe.start(runId: 'test', mode: PresentationMode.a1),
      throwsStateError,
    );
  });
}
