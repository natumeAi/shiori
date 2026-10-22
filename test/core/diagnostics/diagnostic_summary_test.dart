import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/diagnostics/diagnostic_summary.dart';
import 'package:shiori/core/diagnostics/frame_sample.dart';

import '../../helpers/diagnostics_fixtures.dart';

void main() {
  Map<String, Object?> aggregate(List<FrameSample> frames) =>
      DiagnosticSummary.aggregate(
        frames,
        frames.map((f) => f.frameNumber).toSet(),
      );

  test(
    'distribution reports unavailable input and stage budget boundaries',
    () {
      expect(DiagnosticSummary.distribution([]), {
        'count': 0,
        'source': 'unavailable_no_samples',
      });
      final input = [8334, 1, 8333, 3000, 2000];
      expect(DiagnosticSummary.distribution(input), {
        'count': 5,
        'p50Us': 3000,
        'p95Us': 8334,
        'p99Us': 8334,
        'maxUs': 8334,
        'over8333Us': 1,
      });
      expect(input, [8334, 1, 8333, 3000, 2000]);
    },
  );

  test('interval distribution counts missed vsyncs, not period jitter', () {
    // Device run: P50 8339 µs, P99 8457 µs, max 25060 µs.
    final result = DiagnosticSummary.intervalDistribution([
      8339,
      8403,
      8457,
      12499,
      12500,
      25060,
    ]);
    expect(result, containsPair('atLeast12500Us', 2));
    expect(result, containsPair('maxUs', 25060));
    expect(result.containsKey('over8333Us'), isFalse);
    expect(DiagnosticSummary.intervalDistribution([]), {
      'count': 0,
      'source': 'unavailable_no_samples',
    });
  });

  test(
    'near 120 Hz comes from engine intervals despite long pipeline latency',
    () {
      final frames = [
        for (var i = 0; i < 8; i++)
          diagnosticFrame(
            100000 + i * 8333,
            frameNumber: i,
            pipelineGapUs: 100000,
          ),
      ];
      final result = aggregate(frames.reversed.toList());
      expect(result['cadencePattern'], 'observed_near_120hz');
      expect(result['vsyncIntervals'], containsPair('p50Us', 8333));
      expect(result['vsyncIntervals'], containsPair('count', 7));
      expect(result['vsyncIntervals'], containsPair('atLeast12500Us', 0));
      expect(result['ui'], containsPair('maxUs', 1000));
      expect(result['raster'], containsPair('maxUs', 2000));
      expect(
        result['cadenceInterpretation'],
        'engine_observation_not_physical_presentation',
      );
      expect(frames.first.vsyncUs, 100000);
    },
  );

  test('uniform low-cost 60 Hz is retained as a possible system cap', () {
    final result = aggregate([
      for (var i = 0; i < 8; i++)
        diagnosticFrame(100000 + i * 16667, frameNumber: i),
    ]);
    expect(result['cadencePattern'], 'consistent_with_60hz_system_cap');
    expect(result['vsyncIntervals'], containsPair('p99Us', 16667));
    // Every 60 Hz interval misses a 120 Hz vsync; the pattern explains why.
    expect(result['vsyncIntervals'], containsPair('atLeast12500Us', 7));
    expect(result['ui'], containsPair('over8333Us', 0));
    expect(result['raster'], containsPair('over8333Us', 0));
  });

  test('mixed 120/60 Hz and costly stages identify application misses', () {
    final timestamps = [100000, 108333, 125000, 133333, 150000];
    for (final expensiveRaster in [false, true]) {
      final result = aggregate([
        for (var i = 0; i < timestamps.length; i++)
          diagnosticFrame(
            timestamps[i],
            frameNumber: i,
            buildUs: !expensiveRaster && i == 2 ? 9000 : 1000,
            rasterUs: expensiveRaster && i == 2 ? 9000 : 2000,
          ),
      ]);
      expect(result['cadencePattern'], 'mixed_cadence_with_over_budget_stages');
      expect(result['vsyncIntervals'], containsPair('atLeast12500Us', 2));
      expect(
        result[expensiveRaster ? 'raster' : 'ui'],
        containsPair('over8333Us', 1),
      );
    }
  });

  test('mixed low-cost and uniform expensive 60 Hz remain inconclusive', () {
    final mixed = aggregate([
      for (final (i, t) in [100000, 108333, 125000, 133333, 150000].indexed)
        diagnosticFrame(t, frameNumber: i),
    ]);
    expect(mixed['cadencePattern'], 'variable_or_inconclusive');
    final expensive = aggregate([
      for (var i = 0; i < 5; i++)
        diagnosticFrame(100000 + i * 16667, frameNumber: i, buildUs: 9000),
    ]);
    expect(expensive['cadencePattern'], 'variable_or_inconclusive');
  });

  test('fewer than three correlated intervals cannot establish cadence', () {
    for (var length = 0; length < 4; length++) {
      final result = aggregate([
        for (var i = 0; i < length; i++)
          diagnosticFrame(i * 8333, frameNumber: i),
      ]);
      expect(result['cadencePattern'], 'insufficient_correlated_samples');
    }
  });

  test('uncorrelated frames and their expensive stages are excluded', () {
    final result = DiagnosticSummary.aggregate(
      [
        for (var i = 0; i < 5; i++)
          diagnosticFrame(100000 + i * 8333, frameNumber: i),
        diagnosticFrame(1, frameNumber: 99, buildUs: 90000, rasterUs: 90000),
      ],
      {for (var i = 0; i < 5; i++) i},
    );
    expect(result['correlatedMotionFrames'], 5);
    expect(result['cadencePattern'], 'observed_near_120hz');
    expect(result['ui'], containsPair('maxUs', 1000));
    final unavailable = DiagnosticSummary.aggregate([diagnosticFrame(1)], {2});
    expect(unavailable['correlatedMotionFrames'], 0);
    expect(unavailable['vsyncIntervals'], containsPair('count', 0));
    expect(unavailable['cadencePattern'], 'insufficient_correlated_samples');
  });

  test('missing timing samples cannot turn motion gaps into 60 Hz cadence', () {
    final timestamps = [for (var i = 0; i < 9; i++) 100000 + i * 8333];
    final result = DiagnosticSummary.aggregate(
      [
        for (var i = 0; i < timestamps.length; i += 2)
          diagnosticFrame(timestamps[i], frameNumber: i),
      ],
      {for (var i = 0; i < timestamps.length; i++) i},
    );
    expect(result['correlatedMotionFrames'], 5);
    expect(result['vsyncIntervals'], containsPair('count', 0));
    expect(result['cadencePattern'], 'insufficient_correlated_samples');
  });

  test('missing motion callbacks cannot bridge intervening engine frames', () {
    final timestamps = [for (var i = 0; i < 9; i++) 100000 + i * 8333];
    final result = DiagnosticSummary.aggregate(
      [
        for (final (i, timestamp) in timestamps.indexed)
          diagnosticFrame(timestamp, frameNumber: i),
      ],
      {for (var i = 0; i < timestamps.length; i += 2) i},
    );
    expect(result['correlatedMotionFrames'], 5);
    expect(result['vsyncIntervals'], containsPair('count', 0));
    expect(result['cadencePattern'], 'insufficient_correlated_samples');
  });

  test('gaps in both streams do not fabricate 60 Hz cadence', () {
    final result = DiagnosticSummary.aggregate(
      [
        for (var i = 0; i < 9; i += 2)
          diagnosticFrame(100000 + i * 8333, frameNumber: i),
      ],
      {0, 2, 4, 6, 8},
    );
    expect(result['correlatedMotionFrames'], 5);
    expect(result['vsyncIntervals'], containsPair('count', 0));
  });

  test('negative frame numbers never match or establish adjacency', () {
    final result = DiagnosticSummary.aggregate(
      [
        diagnosticFrame(91667, frameNumber: -1, buildUs: 90000),
        diagnosticFrame(100000, frameNumber: 0),
        diagnosticFrame(108333, frameNumber: 1),
      ],
      {-1, 0, 1},
    );
    expect(result['correlatedMotionFrames'], 2);
    expect(result['ui'], containsPair('maxUs', 1000));
    expect(result['vsyncIntervals'], containsPair('count', 1));
  });

  test('nonpositive vsync intervals are excluded despite consecutive IDs', () {
    final result = DiagnosticSummary.aggregate(
      [
        diagnosticFrame(100000, frameNumber: 0),
        diagnosticFrame(100000, frameNumber: 1),
        diagnosticFrame(90000, frameNumber: 2),
        diagnosticFrame(98333, frameNumber: 3),
      ],
      {0, 1, 2, 3},
    );
    expect(result['correlatedMotionFrames'], 4);
    expect(result['vsyncIntervals'], containsPair('count', 1));
    expect(result['vsyncIntervals'], containsPair('p50Us', 8333));
  });

  test(
    'clipboard preserves useful identity, distributions and partial flags',
    () {
      final original = diagnosticRecord();
      final record = original.copyWith(
        aggregates: aggregate(original.frames),
        frameOverflow: 7,
        motionOverflow: 9,
      );
      const fileName = 'shiori-diag-abc123def456-gha-17-run-20261022-1.json';
      final summary = DiagnosticSummary.clipboard(record, fileName);
      final json = jsonDecode(summary) as Map<String, Object?>;
      expect(utf8.encode(summary).length, lessThanOrEqualTo(4000));
      expect(json['buildId'], record.buildId);
      expect(json['runId'], record.runId);
      expect(json['fileName'], fileName);
      expect(json['frames'], 1);
      expect(json['ui'], containsPair('p99Us', 1000));
      expect(json['raster'], containsPair('p95Us', 2000));
      expect(json['frameOverflow'], 7);
      expect(json['motionOverflow'], 9);
      expect(json['incompleteTrailingBatch'], isTrue);
      expect(json['physicalPresentation'], 'unverified');
    },
  );

  for (final payload in ['🧪漢字', '\u0001\u0002\n\\"']) {
    test(
      'clipboard bounds escaped UTF-8 text and retains all evidence keys ${payload.runes.first}',
      () {
        final longText = List.filled(10000, payload).join();
        final distribution = {
          for (final key in [
            'count',
            'p50Us',
            'p95Us',
            'p99Us',
            'maxUs',
            'over8333Us',
            'atLeast12500Us',
          ])
            key: 9223372036854775807,
          'untrusted': longText,
        };
        final base = diagnosticRecord();
        const fileName = 'shiori-diag-abc123def456-gha-17-run-20261022-1.json';
        final record = base.copyWith(
          metadata: {'os': longText, 'extra': longText},
          clocks: {'correlation': longText},
          physicalPresentation: longText,
          frameOverflow: 17,
          motionOverflow: 23,
          aggregates: {
            'ui': distribution,
            'raster': distribution,
            'vsyncIntervals': distribution,
            'cadencePattern': longText,
          },
        );
        final summary = DiagnosticSummary.clipboard(record, fileName);
        final json = jsonDecode(summary) as Map<String, Object?>;
        expect(utf8.encode(summary).length, lessThanOrEqualTo(4000));
        expect(json['buildId'], base.buildId);
        expect(json['runId'], base.runId);
        expect(json['fileName'], fileName);
        expect(json['frameOverflow'], 17);
        expect(json['motionOverflow'], 23);
        expect(json['incompleteTrailingBatch'], isTrue);
        expect(
          json.keys,
          containsAll([
            'clockCorrelation',
            'physicalPresentation',
            'cadencePattern',
          ]),
        );
        expect(json['ui'], containsPair('p99Us', 9223372036854775807));
        expect(
          json['vsyncIntervals'],
          containsPair('atLeast12500Us', 9223372036854775807),
        );

        final allTextLong = DiagnosticSummary.clipboard(
          record.copyWith(buildId: longText, runId: longText),
          longText,
        );
        expect(utf8.encode(allTextLong).length, lessThanOrEqualTo(4000));
        final abbreviated = jsonDecode(allTextLong) as Map<String, Object?>;
        for (final key in ['buildId', 'runId', 'fileName']) {
          expect(abbreviated[key], isA<String>());
          expect(abbreviated[key], isNot(isEmpty));
        }
        expect(abbreviated['incompleteTrailingBatch'], isTrue);
      },
    );
  }

  test('clipboard handles unavailable and malformed optional metadata', () {
    final summary = DiagnosticSummary.clipboard(
      diagnosticRecord().copyWith(
        metadata: {},
        clocks: {},
        aggregates: {
          'ui': 'unavailable',
          'raster': {'p95Us': 'invalid'},
        },
      ),
      'capture.json',
    );
    final json = jsonDecode(summary) as Map<String, Object?>;
    expect(json['os'], 'unknown');
    expect(json['clockCorrelation'], 'unknown');
    expect(json['ui'], containsPair('source', 'unavailable'));
    expect(json['raster'], isEmpty);
  });
}
