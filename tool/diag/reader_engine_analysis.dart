import 'reader_export_data.dart';

final class EngineAnalysis {
  EngineAnalysis(Json engine) {
    if (engine['schemaVersion'] is! int || engine['schemaVersion'] != 1) {
      throw FormatException(
        'Unsupported engine.schemaVersion: ${engine['schemaVersion']}',
      );
    }
    frames = objects(engine['frames'], 'engine.frames');
    motion = objects(engine['motion'], 'engine.motion');
    final ids = <int>{
      for (final sample in motion)
        if (sample['frameNumber'] case final int id when id >= 0) id,
    };
    unavailableFrameNumbers = [...frames, ...motion]
        .where((s) => s['frameNumber'] is! int || (s['frameNumber'] as int) < 0)
        .length;
    final ordered = frames.where((f) => f['frameNumber'] is int).toList()
      ..sort(
        (a, b) => (a['frameNumber'] as int).compareTo(b['frameNumber'] as int),
      );
    active = ordered.where((f) => ids.contains(f['frameNumber'])).toList();
    unmatchedMotionIds = ids
        .difference(active.map((f) => f['frameNumber'] as int).toSet())
        .length;
    int cost(Json f, String stage) =>
        integer(f['${stage}FinishUs'], '${stage}FinishUs') -
        integer(f['${stage}StartUs'], '${stage}StartUs');
    final ui = active.map((f) => cost(f, 'build')).toList();
    final raster = active.map((f) => cost(f, 'raster')).toList();
    for (var i = 1; i < ordered.length; i++) {
      final previous = ordered[i - 1], next = ordered[i];
      if ((previous['frameNumber'] as int) < 0 ||
          next['frameNumber'] != (previous['frameNumber'] as int) + 1 ||
          !ids.contains(previous['frameNumber']) ||
          !ids.contains(next['frameNumber'])) {
        continue;
      }
      final delta =
          integer(next['vsyncUs'], 'vsyncUs') -
          integer(previous['vsyncUs'], 'vsyncUs');
      if (delta > 0) {
        intervals.add(delta);
        intervalPairs.add({
          'previous': previous['frameNumber'],
          'next': next['frameNumber'],
          'us': delta,
        });
      }
    }
    final fast = intervals.where((v) => v >= 7000 && v <= 10000).length;
    final slow = intervals.where((v) => v >= 14000 && v <= 19000).length;
    final expensive = [
      ...ui,
      ...raster,
    ].any((v) => v > ReaderGates.stageBudgetUs);
    final pattern = intervals.length < 3
        ? 'insufficient_correlated_samples'
        : fast / intervals.length >= .9
        ? 'observed_near_120hz'
        : slow / intervals.length >= .9 && !expensive
        ? 'consistent_with_60hz_system_cap'
        : fast > 0 && slow > 0 && expensive
        ? 'mixed_cadence_with_over_budget_stages'
        : 'variable_or_inconclusive';
    aggregates = {
      'scope': 'engine_frame_number_matched_motion_frames_only',
      'correlatedMotionFrames': active.length,
      'ui': distribution(ui, engine: true),
      'raster': distribution(raster, engine: true),
      'vsyncIntervals': distribution(intervals, engine: true, interval: true),
      'cadencePattern': pattern,
      'cadenceInterpretation': 'engine_observation_not_physical_presentation',
    };
  }

  late final List<Json> frames, motion, active;
  late final int unavailableFrameNumbers;
  late final int unmatchedMotionIds;
  late final Json aggregates;
  final intervals = <int>[];
  final intervalPairs = <Json>[];

  /// Only pairs within the same recorded first-submission/settle window count.
  /// Stopwatch samples are compared to Stopwatch windows, never engine epochs.
  Json stalls(List<Json> windows) {
    final motionById = <int, int>{
      for (final m in motion)
        if (m['frameNumber'] case final int id when id >= 0)
          id: integer(m['monotonicUs'], 'motion.monotonicUs'),
    };
    bool inside(int time, Json w) =>
        time >= (w['startUs'] as int) && time <= (w['endUs'] as int);
    final engineStalls = <Json>[];
    final candidates = <Json>[];
    for (final pair in intervalPairs) {
      final a = motionById[pair['previous']], b = motionById[pair['next']];
      if ((pair['us'] as int) >= ReaderGates.stallUs &&
          a != null &&
          b != null &&
          windows.any((w) => inside(a, w) && inside(b, w))) {
        engineStalls.add(pair);
        candidates.add({
          'source': 'engineInterval',
          ...pair,
          'class': 'unresolved',
          'reason': 'no recorded frame-demand or deliberate-hold interval',
        });
      }
    }
    final submissionGaps = <int>[];
    var brokenAdjacency = 0;
    for (var i = 1; i < active.length; i++) {
      final a = motionById[active[i - 1]['frameNumber']];
      final b = motionById[active[i]['frameNumber']];
      if ((active[i]['frameNumber'] as int) >
              (active[i - 1]['frameNumber'] as int) + 1 &&
          a != null &&
          b != null &&
          windows.any((w) => inside(a, w) && inside(b, w))) {
        brokenAdjacency++;
      }
    }
    for (final w in windows) {
      final times =
          motion
              .map((m) => integer(m['monotonicUs'], 'motion.monotonicUs'))
              .where((t) => inside(t, w))
              .toSet()
              .toList()
            ..sort();
      for (var i = 1; i < times.length; i++) {
        if (times[i] - times[i - 1] >= ReaderGates.stallUs) {
          submissionGaps.add(times[i] - times[i - 1]);
          candidates.add({
            'source': 'submissionGap',
            'captureEpoch': w['captureEpoch'],
            'inputId': w['inputId'],
            'startUs': times[i - 1],
            'endUs': times[i],
            'us': times[i] - times[i - 1],
            'class': 'unresolved',
            'reason': 'missing motion samples cannot prove idle or a requested frame; pointer moves and holds are not recorded',
          });
        }
      }
    }
    final longStageFrames = active
        .where(
          (f) =>
              integer(f['buildFinishUs'], 'buildFinishUs') -
                      integer(f['buildStartUs'], 'buildStartUs') >=
                  ReaderGates.stallUs ||
              integer(f['rasterFinishUs'], 'rasterFinishUs') -
                      integer(f['rasterStartUs'], 'rasterStartUs') >=
                  ReaderGates.stallUs,
        )
        .toList();
    final longStages = longStageFrames.length;
    for (final frame in longStageFrames) {
      candidates.add({
        'source': 'longStage',
        'frameNumber': frame['frameNumber'],
        'class': 'dueLateOrMissing',
        'reason':
            'recorded UI or raster execution took >=${ReaderGates.stallUs} us',
      });
    }
    return {
      'motionWindows': windows.length,
      'engineIntervals': distribution(engineStalls.map((p) => p['us'] as int)),
      'submissionGaps': distribution(submissionGaps),
      'longStageFrames': longStages,
      'brokenAdjacencyInsideWindows': brokenAdjacency,
      'classes': {
        'recordedDeliberateHold': 0,
        'provenIdleNoFrameRequested': 0,
        'dueLateOrMissing': longStages,
        'unresolved': engineStalls.length + submissionGaps.length,
      },
      'candidates': candidates,
      'observed':
          engineStalls.isNotEmpty ||
          submissionGaps.isNotEmpty ||
          longStages > 0,
      'interpretation': 'counts are candidate observations by source, not deduplicated episodes; unresolved candidates remain failed; no cross-clock correlation inferred',
    };
  }
}
