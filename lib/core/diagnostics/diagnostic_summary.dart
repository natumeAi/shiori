import 'dart:convert';

import 'package:shiori/core/diagnostics/diagnostic_record.dart';
import 'package:shiori/core/diagnostics/frame_sample.dart';

abstract final class DiagnosticSummary {
  static Map<String, Object?> distribution(Iterable<int> values) {
    final sorted = values.toList()..sort();
    if (sorted.isEmpty) return {'count': 0, 'source': 'unavailable_no_samples'};
    int percentile(double p) => sorted[((sorted.length - 1) * p).ceil()];
    return {
      'count': sorted.length,
      'p50Us': percentile(.5),
      'p95Us': percentile(.95),
      'p99Us': percentile(.99),
      'maxUs': sorted.last,
      'over8333Us': sorted.where((v) => v > 8333).length,
    };
  }

  /// Engine frame numbers identify motion independently of scheduler target
  /// and engine vsync-start timestamps. Negative identities are unavailable.
  static Map<String, Object?> aggregate(
    List<FrameSample> frames,
    Set<int> motionFrameNumbers,
  ) {
    final orderedFrames = frames.toList()
      ..sort((a, b) => a.frameNumber.compareTo(b.frameNumber));
    final active = orderedFrames
        .where(
          (f) =>
              f.frameNumber >= 0 && motionFrameNumbers.contains(f.frameNumber),
        )
        .toList();
    final intervals = <int>[];
    for (var i = 1; i < orderedFrames.length; i++) {
      final previous = orderedFrames[i - 1];
      final current = orderedFrames[i];
      // Missing timing or motion samples must never fabricate slower cadence.
      final interval = current.vsyncUs - previous.vsyncUs;
      if (previous.frameNumber >= 0 &&
          current.frameNumber == previous.frameNumber + 1 &&
          motionFrameNumbers.contains(previous.frameNumber) &&
          motionFrameNumbers.contains(current.frameNumber) &&
          interval > 0) {
        intervals.add(interval);
      }
    }
    final fast = intervals.where((v) => v >= 7000 && v <= 10000).length;
    final slow = intervals.where((v) => v >= 14000 && v <= 19000).length;
    final expensive = active.any(
      (f) =>
          f.buildFinishUs - f.buildStartUs > 8333 ||
          f.rasterFinishUs - f.rasterStartUs > 8333,
    );
    final String pattern;
    if (intervals.length < 3) {
      pattern = 'insufficient_correlated_samples';
    } else if (fast / intervals.length >= .9) {
      pattern = 'observed_near_120hz';
    } else if (slow / intervals.length >= .9 && !expensive) {
      pattern = 'consistent_with_60hz_system_cap';
    } else if (fast > 0 && slow > 0 && expensive) {
      pattern = 'mixed_cadence_with_over_budget_stages';
    } else {
      pattern = 'variable_or_inconclusive';
    }
    return {
      'scope': 'engine_frame_number_matched_motion_frames_only',
      'correlatedMotionFrames': active.length,
      'ui': distribution(active.map((f) => f.buildFinishUs - f.buildStartUs)),
      'raster': distribution(
        active.map((f) => f.rasterFinishUs - f.rasterStartUs),
      ),
      'vsyncIntervals': distribution(intervals),
      'cadencePattern': pattern,
      'cadenceInterpretation': 'engine_observation_not_physical_presentation',
    };
  }

  static String clipboard(DiagnosticRecord record, String fileName) {
    String bounded(Object? value, int length) {
      if (value is! String) return 'unknown';
      final result = StringBuffer();
      var used = 0;
      for (final rune in value.runes) {
        final char = String.fromCharCode(rune);
        used += utf8.encode(jsonEncode(char)).length - 2;
        if (used > length) break;
        result.write(char);
      }
      return result.toString();
    }

    Map<String, Object?> costs(Object? value) {
      if (value is! Map) return {'source': 'unavailable'};
      return {
        for (final key in [
          'count',
          'p50Us',
          'p95Us',
          'p99Us',
          'maxUs',
          'over8333Us',
        ])
          if (value[key] is num) key: value[key],
      };
    }

    // Bound individual text fields and select known numeric aggregates so all
    // identity/completeness fields survive, even with externally edited data.
    final text = jsonEncode({
      'buildId': bounded(record.buildId, 100),
      'runId': bounded(record.runId, 100),
      'os': bounded(record.metadata['os'], 160),
      'frames': record.frames.length,
      'motion': record.motion.length,
      'ui': costs(record.aggregates['ui']),
      'raster': costs(record.aggregates['raster']),
      'vsyncIntervals': costs(record.aggregates['vsyncIntervals']),
      'cadencePattern': bounded(record.aggregates['cadencePattern'], 80),
      'frameOverflow': record.frameOverflow,
      'motionOverflow': record.motionOverflow,
      'incompleteTrailingBatch': record.incompleteTrailingBatch,
      'clockCorrelation': bounded(record.clocks['correlation'], 80),
      'physicalPresentation': bounded(record.physicalPresentation, 40),
      'fileName': bounded(fileName, 240),
    });
    assert(utf8.encode(text).length <= 4000);
    return text;
  }
}
