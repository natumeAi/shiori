import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:shiori/core/diagnostics/diagnostic_record.dart';
import 'package:shiori/core/diagnostics/motion_sample.dart';
import 'package:shiori/core/diagnostics/probe_declarations.dart';

import '../../helpers/diagnostics_fixtures.dart';

void main() {
  Map<String, Object?> wire(DiagnosticRecord record) =>
      jsonDecode(jsonEncode(record.toJson())) as Map<String, Object?>;

  test(
    'versioned record round-trips raw clocks, nested data and declarations',
    () {
      final record = diagnosticRecord().copyWith(
        declarations: const ProbeDeclarations(
          deviceModel: 'iPhone 14 Pro Max',
          lowPowerMode: DeclaredSetting.off,
          limitFrameRate: DeclaredSetting.on,
          charging: DeclaredSetting.on,
          warm: DeclaredSetting.unknown,
        ),
        metadata: {
          'os': 'iOS 26',
          'reportedRefreshRate': null,
          'viewport': {'width': 430.0, 'height': 932.0, 'dpr': 3.0},
        },
        motion: const [
          MotionSample(
            frameNumber: 1,
            schedulerUs: 1,
            rawSchedulerUs: 108333,
            monotonicUs: 7100000,
            progress: .25,
          ),
        ],
        frameOverflow: 2,
        motionOverflow: 3,
        omittedOutsideMotion: 1,
        errors: ['engine_motion_frame_number_correlation_unavailable'],
        aggregates: {
          'ui': {'count': 1, 'p99Us': 1000},
        },
      );
      final json = wire(record);
      expect(json['schemaVersion'], 1);
      expect(json['scenarioId'], 'synthetic_transform');
      expect(json['physicalPresentation'], 'unverified');
      expect(json['startedAt'], '2026-10-22T12:00:00.000Z');
      expect(json['declarations'], containsPair('lowPowerMode', 'off'));
      expect(json['declarations'], containsPair('source', 'user_provided'));
      final restored = DiagnosticRecord.fromJson(json);
      expect(restored, record);
      expect(restored.startedAt.isUtc, isTrue);
      expect(restored.stoppedAt.isUtc, isTrue);
      expect(jsonEncode(restored.toJson()), jsonEncode(record.toJson()));
      expect(restored.frames.single.vsyncUs, 100000);
      expect(restored.frames.single.arrivalMonotonicUs, 9000000);
      expect(restored.motion.single.schedulerUs, 1);
      expect(restored.motion.single.frameNumber, 1);
      expect(restored.motion.single.rawSchedulerUs, 108333);
      expect(restored.metadata['reportedRefreshRate'], isNull);
    },
  );

  test(
    'optional schema defaults and unknown fields do not invent evidence',
    () {
      final json = wire(diagnosticRecord())
        ..remove('schemaVersion')
        ..remove('scenarioId')
        ..remove('physicalPresentation')
        ..['futureField'] = {'not': 'evidence'}
        ..['declarations'] = {'futureSetting': 'on'};
      final record = DiagnosticRecord.fromJson(json);
      expect(record.schemaVersion, 1);
      expect(record.scenarioId, 'synthetic_transform');
      expect(record.physicalPresentation, 'unverified');
      expect(record.declarations, const ProbeDeclarations());
      expect(record.metadata['reportedRefreshRate'], isNull);
      expect(record.toJson(), isNot(contains('futureField')));
    },
  );

  test(
    'missing required evidence and malformed nested fields are rejected',
    () {
      for (final key in [
        'runId',
        'startedAt',
        'frames',
        'clocks',
        'incompleteTrailingBatch',
      ]) {
        final json = wire(diagnosticRecord())..remove(key);
        expect(
          () => DiagnosticRecord.fromJson(json),
          throwsA(isA<CheckedFromJsonException>()),
          reason: 'A missing $key must not look like a valid capture',
        );
      }
      for (final replacement in <Map<String, Object?>>[
        {
          'frames': [
            {'vsyncUs': 'invalid'},
          ],
        },
        {
          'motion': [
            {'schedulerUs': 1},
          ],
        },
        {'startedAt': 'not-a-date'},
      ]) {
        final json = wire(diagnosticRecord())..addAll(replacement);
        expect(
          () => DiagnosticRecord.fromJson(json),
          throwsA(isA<CheckedFromJsonException>()),
        );
      }
    },
  );

  test(
    'all declarations serialize explicit on/off/unknown without inference',
    () {
      for (final setting in DeclaredSetting.values) {
        final declarations = ProbeDeclarations(
          lowPowerMode: setting,
          limitFrameRate: setting,
          charging: setting,
          warm: setting,
        );
        final json = declarations.toJson();
        for (final key in [
          'lowPowerMode',
          'limitFrameRate',
          'charging',
          'warm',
        ]) {
          expect(json[key], setting.name);
        }
        expect(ProbeDeclarations.fromJson(json), declarations);
      }
      final unknown = ProbeDeclarations.fromJson({});
      expect(unknown.deviceModel, isEmpty);
      expect(unknown.source, 'user_provided');
      expect(unknown.lowPowerMode, DeclaredSetting.unknown);
      expect(unknown.limitFrameRate, DeclaredSetting.unknown);
      expect(unknown.charging, DeclaredSetting.unknown);
      expect(unknown.warm, DeclaredSetting.unknown);
    },
  );

  test(
    'unrecognized declaration value is rejected rather than treated as off',
    () {
      expect(
        () => ProbeDeclarations.fromJson({'limitFrameRate': 'future_setting'}),
        throwsA(isA<CheckedFromJsonException>()),
      );
    },
  );

  test(
    'decoded record samples and evidence maps cannot mutate after capture',
    () {
      final record = DiagnosticRecord.fromJson(wire(diagnosticRecord()));
      expect(() => record.frames.clear(), throwsUnsupportedError);
      expect(() => record.motion.clear(), throwsUnsupportedError);
      expect(() => record.errors.add('invented'), throwsUnsupportedError);
      expect(() => record.metadata['os'] = 'changed', throwsUnsupportedError);
      expect(() => record.clocks.clear(), throwsUnsupportedError);
    },
  );
}
