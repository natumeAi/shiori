import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/diagnostics/data/reader_probe_summary.dart';

import '../../../tool/diag/reader_input_analysis.dart';

void main() {
  test('reused IDs from different captures cannot complete each other', () {
    Map<String, Object?> event(String kind, int time, int? epoch) => {
      'event': kind,
      'monotonicUs': time,
      'inputId': 1,
      'captureEpoch': ?epoch,
    };
    // Late previous-capture and legacy epoch-less samples remain separate
    // from the newly admitted input with the same numeric ID.
    for (final previousEpoch in <int?>[1, null]) {
      final events = [
        event('inputReceived', 1000, 2),
        event('pointerAdmitted', 1000, 2),
        event('firstMotionSubmission', 2000, previousEpoch),
        event('settleEnd', 3000, 2),
      ];
      final analysis = InputAnalysis(events, [], []);
      final summary = ReaderProbeSummary.aggregate(events, [], []);
      expect(analysis.appAggregates, summary);
      expect((summary['warmInputToFirstSubmission'] as Map)['count'], 0);
      expect(analysis.windows, isEmpty);
      expect(analysis.openWindows, 1);
      expect(analysis.incompleteWarmInputs, 1);
    }
  });

  test('interleaved captures retain their own latency and motion windows', () {
    Map<String, Object?> event(String kind, int time, int epoch) => {
      'event': kind,
      'monotonicUs': time,
      'inputId': 1,
      'captureEpoch': epoch,
    };
    final events = [
      event('inputReceived', 1000, 1),
      event('pointerAdmitted', 1000, 1),
      event('inputReceived', 2000, 2),
      event('pointerAdmitted', 2000, 2),
      event('firstMotionSubmission', 3000, 1),
      event('firstMotionSubmission', 6000, 2),
      event('settleEnd', 7000, 1),
      event('settleEnd', 8000, 2),
    ];
    final analysis = InputAnalysis(events, [], []);
    final summary = ReaderProbeSummary.aggregate(events, [], []);
    expect(analysis.appAggregates, summary);
    expect(summary['warmInputToFirstSubmission'], {
      'count': 2,
      'p50Us': 2000,
      'p95Us': 4000,
      'p99Us': 4000,
      'maxUs': 4000,
    });
    expect(analysis.windows.map((w) => w['captureEpoch']), [1, 2]);
    expect(analysis.windows.map((w) => w['startUs']), [3000, 6000]);
    expect(analysis.openWindows, 0);
  });
}
