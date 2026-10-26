import 'dart:ui';

import 'package:shiori/core/diagnostics/diagnostic_record.dart';
import 'package:shiori/core/diagnostics/frame_sample.dart';
import 'package:shiori/core/diagnostics/frame_source.dart';
import 'package:shiori/core/diagnostics/motion_sample.dart';
import 'package:shiori/core/diagnostics/probe_clock.dart';
import 'package:shiori/core/diagnostics/probe_declarations.dart';

final class DiagnosticTestClock implements ProbeClock {
  DateTime wall = DateTime.utc(2026, 10, 22, 12);
  int elapsedUs = 7000000;

  @override
  DateTime utcNow() => wall;

  @override
  int get monotonicUs => elapsedUs;

  void advance(Duration duration) {
    wall = wall.add(duration);
    elapsedUs += duration.inMicroseconds;
  }
}

final class DiagnosticTestFrameSource implements FrameSource {
  void Function(List<FrameTiming>)? callback;
  int starts = 0;
  int stops = 0;
  bool subscribed = false;

  @override
  void start(void Function(List<FrameTiming>) onTimings) {
    starts++;
    subscribed = true;
    callback = onTimings;
  }

  @override
  void stop() {
    stops++;
    subscribed = false;
  }

  // Keep the callback to simulate an already queued delivery after unsubscribe.
  void emit(List<FrameTiming> timings) => callback?.call(timings);
}

FrameTiming diagnosticTiming(
  int vsyncUs, {
  int frameNumber = 1,
  int buildUs = 1000,
  int rasterUs = 2000,
  int pipelineGapUs = 0,
}) {
  final buildStart = vsyncUs + 100;
  final buildFinish = buildStart + buildUs;
  final rasterStart = buildFinish + pipelineGapUs;
  return FrameTiming(
    frameNumber: frameNumber,
    vsyncStart: vsyncUs,
    buildStart: buildStart,
    buildFinish: buildFinish,
    rasterStart: rasterStart,
    rasterFinish: rasterStart + rasterUs,
    rasterFinishWallTime: 1792670400000000 + rasterStart + rasterUs,
  );
}

FrameSample diagnosticFrame(
  int vsyncUs, {
  int frameNumber = 1,
  int buildUs = 1000,
  int rasterUs = 2000,
  int pipelineGapUs = 0,
  int arrivalUs = 9000000,
}) {
  final timing = diagnosticTiming(
    vsyncUs,
    frameNumber: frameNumber,
    buildUs: buildUs,
    rasterUs: rasterUs,
    pipelineGapUs: pipelineGapUs,
  );
  return FrameSample(
    frameNumber: timing.frameNumber,
    vsyncUs: timing.timestampInMicroseconds(FramePhase.vsyncStart),
    buildStartUs: timing.timestampInMicroseconds(FramePhase.buildStart),
    buildFinishUs: timing.timestampInMicroseconds(FramePhase.buildFinish),
    rasterStartUs: timing.timestampInMicroseconds(FramePhase.rasterStart),
    rasterFinishUs: timing.timestampInMicroseconds(FramePhase.rasterFinish),
    rasterFinishWallUs: timing.timestampInMicroseconds(
      FramePhase.rasterFinishWallTime,
    ),
    arrivalMonotonicUs: arrivalUs,
  );
}

DiagnosticRecord diagnosticRecord() => DiagnosticRecord(
  runId: 'run-20261022-1',
  buildId: 'abc123def456-gha-17',
  startedAt: DateTime.utc(2026, 10, 22, 12),
  stoppedAt: DateTime.utc(2026, 10, 22, 12, 0, 1),
  startedMonotonicUs: 7000000,
  stoppedMonotonicUs: 8000000,
  finalizedMonotonicUs: 9200000,
  stopReason: 'user_stop',
  declarations: const ProbeDeclarations(),
  metadata: const {'os': 'iOS 26', 'reportedRefreshRate': null},
  clocks: const {'correlation': 'engine_frame_number_identity'},
  frames: [diagnosticFrame(100000)],
  motion: const [
    MotionSample(
      frameNumber: 1,
      schedulerUs: 1,
      rawSchedulerUs: 108333,
      monotonicUs: 7100000,
      progress: .25,
    ),
  ],
  frameOverflow: 0,
  motionOverflow: 0,
  reportsDuringDrain: 1,
  omittedOutsideMotion: 0,
  incompleteTrailingBatch: true,
  errors: const [],
  aggregates: const {},
);
