import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/diag/reader_export_analysis.dart';
import '../../../tool/diag/reader_export_data.dart';
import '../../../tool/diag/reader_native_resources.dart';

Json loadExport([String name = 'passing-120hz-a1-1.json']) => object(
  jsonDecode(File('test/fixtures/reader/exports/$name').readAsStringSync()),
  name,
);
ReaderExportAnalysis analyze([String name = 'passing-120hz-a1-1.json']) =>
    ReaderExportAnalysis(loadExport(name));
String gate(ReaderExportAnalysis a, String name) =>
    a.gates.singleWhere((g) => g.name == name).status;

void main() {
  test('native unmatched callbacks remain distinct from overflow', () {
    final raw = loadExport('stall-b.json');
    final presentation = object(raw['presentation'], 'presentation');
    expect(nativeAnalysis(presentation)['unmatchedCallbacks'], 0);
    presentation['unmatchedCallbacks'] = 4;
    final analysis = ReaderExportAnalysis(raw);
    expect(analysis.native['unmatchedCallbacks'], 4);
    expect(analysis.native['overflow'], presentation['overflow']);
    expect(
      analysis.gates.singleWhere((g) => g.name == 'native evidence (b)').reason,
      contains('unmatchedCallbacks=4 (separate)'),
    );
    presentation['unmatchedCallbacks'] = -1;
    expect(() => nativeAnalysis(presentation), throwsFormatException);
  });

  test('motion stage distributions and separate 99 percent budgets', () {
    final a = analyze();
    expect(a.engine.aggregates['ui'], {
      'count': 6,
      'p50Us': 4000,
      'p95Us': 8333,
      'p99Us': 8333,
      'maxUs': 8333,
      'over8333Us': 0,
    });
    expect(a.engine.aggregates['raster'], {
      'count': 6,
      'p50Us': 5000,
      'p95Us': 8333,
      'p99Us': 8333,
      'maxUs': 8333,
      'over8333Us': 0,
    });
    expect(gate(a, 'ui motion budget'), 'pass');
    expect(gate(a, 'raster motion budget'), 'pass');
    final failed = analyze('failing-budgets-a2.json');
    expect(object(failed.engine.aggregates['ui'], 'ui')['over8333Us'], 6);
    expect(
      object(failed.engine.aggregates['raster'], 'raster')['over8333Us'],
      6,
    );
    expect(gate(failed, 'ui motion budget'), 'fail');
    expect(gate(failed, 'raster motion budget'), 'fail');
  });
  test('engine cadence is consecutive matched engine identity only', () {
    final a = analyze();
    expect(a.engine.aggregates['vsyncIntervals'], {
      'count': 5,
      'p50Us': 8333,
      'p95Us': 8333,
      'p99Us': 8333,
      'maxUs': 8333,
      'atLeast12500Us': 0,
    });
    expect(a.engine.aggregates['cadencePattern'], 'observed_near_120hz');
    final gaps = analyze('negative-missing-frames.json');
    expect(gaps.engine.unavailableFrameNumbers, 2);
    expect(gaps.engine.active.length, 4);
    expect(gaps.engine.intervals, [8333]);
    expect(gaps.stalls['brokenAdjacencyInsideWindows'], 2);
    expect(gate(gaps, 'motion stalls'), 'unavailable');
    final raw = loadExport();
    final engine = object(raw['engine'], 'engine');
    objects(engine['frames'], 'frames').first.remove('frameNumber');
    final missing = ReaderExportAnalysis(raw);
    expect(missing.engine.active.length, 5);
    expect(missing.engine.unavailableFrameNumbers, 1);
    expect(missing.engine.unmatchedMotionIds, 1);
    expect(missing.mismatches, isNotEmpty);
  });
  test('informational warm receipt uses opaque ID across generations', () {
    final a = analyze();
    expect(a.readerAggregates['warmInputToFirstSubmission'], {
      'count': 2,
      'p50Us': 10000,
      'p95Us': 16000,
      'p99Us': 16000,
      'maxUs': 16000,
    });
    expect(gate(a, 'warm admitted input to first submission'), 'unavailable');
    expect(a.readerAggregates['queueWait'], {
      'count': 1,
      'p50Us': 30000,
      'p95Us': 30000,
      'p99Us': 30000,
      'maxUs': 30000,
    });
    expect(a.readerAggregates['preparation'], {
      'count': 2,
      'p50Us': 1000,
      'p95Us': 40000,
      'p99Us': 40000,
      'maxUs': 40000,
    });
    expect(a.inputs.coldInputPreparation['p95Us'], 40000);
    expect(
      object(a.readerAggregates['coldSectionPreparation'], 'cold')['p95Us'],
      50000,
    );
    expect(a.inputs.incompleteWarmInputs, 0);
  });
  test('paragraph layout, fallback rate and observable correctness', () {
    final a = analyze();
    expect(a.readerAggregates['paragraphLayout'], {
      'count': 4,
      'p50Us': 200,
      'p95Us': 1000,
      'p99Us': 1000,
      'maxUs': 1000,
    });
    expect(a.readerAggregates['acceptedTurns'], 4);
    expect(a.readerAggregates['staticFallbacks'], 1);
    expect(a.readerAggregates['staticFallbackRate'], .25);
    expect(a.correctness['proofFailures'], 0);
    expect(a.inputs.counts['rejected'], 1);
    expect(a.correctness['staleCallbackRejections'], 0);
    expect(a.correctness['committedInputs'], 4);
    expect(a.correctness['failures'], 0);
    expect(
      gate(a, 'correctness / committed destinations / stale callbacks'),
      'pass',
    );
  });
  test('stall candidates are at least 50 ms inside motion windows', () {
    final a = analyze('stall-b.json');
    expect(a.stalls['observed'], true);
    expect(object(a.stalls['engineIntervals'], 'stalls')['maxUs'], 58333);
    expect(object(a.stalls['submissionGaps'], 'gaps')['count'], 1);
    expect(
      object(
        a.engine.aggregates['vsyncIntervals'],
        'intervals',
      )['atLeast12500Us'],
      1,
    );
    expect(gate(a, 'motion stalls'), 'fail');
    expect(gate(analyze(), 'motion stalls'), 'pass');
  });
  test('idle gaps between completed motion windows do not create stalls', () {
    final raw = loadExport('stall-b.json');
    final events = objects(raw['readerEvents'], 'events');
    events.firstWhere((e) => e['event'] == 'settleEnd')['monotonicUs'] =
        7030000;
    final a = ReaderExportAnalysis(raw);
    expect(a.stalls['observed'], false);
    expect(a.engine.intervals.where((v) => v >= 50000), isNotEmpty);
  });
  test(
    'long UI or raster stages are stall candidates even without cadence',
    () {
      for (final stage in ['build', 'raster']) {
        final raw = loadExport();
        final frames = objects(
          object(raw['engine'], 'engine')['frames'],
          'frames',
        );
        frames.first['${stage}FinishUs'] =
            (frames.first['${stage}StartUs'] as int) + 50000;
        final a = ReaderExportAnalysis(raw);
        expect(a.stalls['longStageFrames'], 1);
        expect(gate(a, 'motion stalls'), 'fail');
      }
    },
  );
  test('resource first last maximum and OLS slopes over 100 turns', () {
    final a = analyze('resources-100-turns-unavailable.json');
    expect(a.readerAggregates['acceptedTurns'], 100);
    expect(a.readerAggregates['resourceSnapshots'], 3);
    expect(a.readerAggregates['rssDeltaBytes'], 2000);
    for (final entry in {
      'liveSurfaces': [3, 3, 3, 0],
      'pictureBytes': [1000, 1200, 1200, 100],
      'imageBytes': [2000, 2000, 2000, 0],
      'rssBytes': [10000, 12000, 12000, 1000],
    }.entries) {
      final trend = object(a.resources[entry.key], entry.key);
      expect([
        trend['first'],
        trend['last'],
        trend['max'],
        trend['slopePerSecond'],
      ], entry.value);
    }
    expect(gate(a, 'resource trend >=100 turns'), 'unavailable');
  });
  test('missing resource samples and equal times never fabricate a slope', () {
    expect(
      object(resourceTrends([])['rssBytes'], 'rss')['reason'],
      contains('missing'),
    );
    final samples = [
      for (final n in [1, 2])
        <String, Object?>{'monotonicUs': 1, 'rssBytes': n},
    ];
    expect(
      object(resourceTrends(samples)['rssBytes'], 'rss')['slopePerSecond'],
      isNull,
    );
  });
  test('native A1 intervals retain their own clock', () {
    final a = analyze();
    expect(a.native['evidence'], 'layer_commit_cadence');
    expect(a.native['commitIntervals'], {
      'count': 3,
      'p50Us': 8333,
      'p95Us': 8333,
      'p99Us': 8333,
      'maxUs': 8333,
      'atLeast12500Us': 0,
    });
  });
  test('native A2 bins 0 1 and at least 2 commits with half-open periods', () {
    final a = analyze('failing-budgets-a2.json');
    final bins = object(a.native['commitsPerDisplayPeriod'], 'bins');
    expect(
      [
        bins['periods'],
        bins['zero'],
        bins['one'],
        bins['atLeastTwo'],
        bins['outsideRecordedPeriods'],
      ],
      [3, 1, 1, 1, 1],
    );
    expect(a.native['evidence'], 'layer_commit_cadence_per_display_period');
  });
  test('native B separates presented from zero at stop and intervals', () {
    final a = analyze('stall-b.json');
    expect(a.native['presented'], 2);
    expect(a.native['notPresentedByStop'], 1);
    expect(
      object(a.native['presentationIntervals'], 'presentation')['p95Us'],
      8333,
    );
    expect(
      a.native['evidence'],
      'system_drawable_presentation_non_product_path',
    );
    expect(a.native['interpretation'], contains('pending/lost'));
  });
  test(
    'overflow qualifies every affected gate and preserves contention subset',
    () {
      final a = analyze('overflowed-rings.json');
      expect(a.overflow, {
        'events': 3,
        'layoutCosts': 1,
        'resources': 1,
        'frames': 1,
        'motion': 1,
        'native': 2,
      });
      expect(a.native['contentionDrops'], 1);
      expect(gate(a, 'ui motion budget'), 'unavailable');
      expect(gate(a, 'raster motion budget'), 'unavailable');
      expect(gate(a, 'motion stalls'), 'unavailable');
      expect(a.mismatches, isEmpty);
    },
  );
}
