import 'dart:async';
import 'dart:collection';
import 'dart:ui';

import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shiori/core/config/env.dart';
import 'package:shiori/core/diagnostics/diagnostic_record.dart';
import 'package:shiori/core/diagnostics/diagnostic_summary.dart';
import 'package:shiori/core/diagnostics/frame_sample.dart';
import 'package:shiori/core/diagnostics/frame_source.dart';
import 'package:shiori/core/diagnostics/motion_sample.dart';
import 'package:shiori/core/diagnostics/probe_clock.dart';
import 'package:shiori/core/diagnostics/probe_declarations.dart';
import 'package:shiori/core/diagnostics/scheduler_frame_source.dart';
import 'package:shiori/core/diagnostics/system_probe_clock.dart';
part 'diagnostic_recorder.g.dart';

enum CapturePhase { idle, recording, draining, finished, disposed }

class DiagnosticRecorder {
  DiagnosticRecorder({
    required this.clock,
    required this.source,
    this.capacity = 4096,
    this.maximumDuration = const Duration(seconds: 15),
    this.drainDuration = const Duration(milliseconds: 1200),
  }) {
    if (capacity < 1 ||
        maximumDuration <= Duration.zero ||
        drainDuration < Duration.zero) {
      throw ArgumentError('Invalid capture bounds');
    }
  }
  final ProbeClock clock;
  final FrameSource source;
  final int capacity;
  final Duration maximumDuration;
  final Duration drainDuration;
  final _log = Logger('DiagnosticRecorder');
  final _frames = ListQueue<FrameSample>();
  final _motion = ListQueue<MotionSample>();
  CapturePhase phase = CapturePhase.idle;
  Timer? _limit;
  Timer? _drain;
  Completer<DiagnosticRecord?>? _completion;
  DateTime? _startedAt;
  DateTime? _stoppedAt;
  int _startedUs = 0;
  int _stoppedUs = 0;
  String _runId = '';
  String _reason = '';
  Map<String, Object?> _metadata = const {};
  ProbeDeclarations _declarations = const ProbeDeclarations();
  int _frameOverflow = 0;
  int _motionOverflow = 0;
  int _drainReports = 0;
  bool _motionFrameNumberUnavailable = false;
  bool _engineFrameNumberUnavailable = false;
  final _errors = <String>[];
  Future<DiagnosticRecord?> get completed =>
      _completion?.future ?? Future.value(null);

  void start({
    required String runId,
    required ProbeDeclarations declarations,
    required Map<String, Object?> metadata,
  }) {
    if (phase == CapturePhase.disposed ||
        phase == CapturePhase.recording ||
        phase == CapturePhase.draining) {
      throw StateError('Capture cannot start in $phase');
    }
    _frames.clear();
    _motion.clear();
    _errors.clear();
    _frameOverflow = 0;
    _motionOverflow = 0;
    _drainReports = 0;
    _motionFrameNumberUnavailable = false;
    _engineFrameNumberUnavailable = false;
    _runId = runId;
    _declarations = declarations;
    _metadata = Map.of(metadata);
    _startedAt = clock.utcNow();
    _startedUs = clock.monotonicUs;
    _completion = Completer<DiagnosticRecord?>();
    phase = CapturePhase.recording;
    source.start(_onTimings);
    _limit = Timer(
      maximumDuration,
      () => unawaited(stop(reason: 'duration_limit')),
    );
    _log.info('Capture started');
  }

  void motion({
    required int frameNumber,
    required int schedulerUs,
    required int rawSchedulerUs,
    required double progress,
  }) {
    if (phase != CapturePhase.recording) return;
    if (frameNumber < 0) _motionFrameNumberUnavailable = true;
    if (_motion.length == capacity) {
      _motion.removeFirst();
      _motionOverflow++;
    }
    _motion.add(
      MotionSample(
        frameNumber: frameNumber,
        schedulerUs: schedulerUs,
        rawSchedulerUs: rawSchedulerUs,
        monotonicUs: clock.monotonicUs,
        progress: progress,
      ),
    );
  }

  void _onTimings(List<FrameTiming> timings) {
    if (phase != CapturePhase.recording && phase != CapturePhase.draining) {
      return;
    }
    if (phase == CapturePhase.draining) _drainReports++;
    final arrival = clock.monotonicUs;
    for (final timing in timings) {
      if (timing.frameNumber < 0) _engineFrameNumberUnavailable = true;
      if (_frames.length == capacity) {
        _frames.removeFirst();
        _frameOverflow++;
      }
      _frames.add(
        FrameSample(
          frameNumber: timing.frameNumber,
          vsyncUs: timing.timestampInMicroseconds(FramePhase.vsyncStart),
          buildStartUs: timing.timestampInMicroseconds(FramePhase.buildStart),
          buildFinishUs: timing.timestampInMicroseconds(FramePhase.buildFinish),
          rasterStartUs: timing.timestampInMicroseconds(FramePhase.rasterStart),
          rasterFinishUs: timing.timestampInMicroseconds(
            FramePhase.rasterFinish,
          ),
          rasterFinishWallUs: timing.timestampInMicroseconds(
            FramePhase.rasterFinishWallTime,
          ),
          arrivalMonotonicUs: arrival,
        ),
      );
    }
  }

  Future<DiagnosticRecord?> stop({String reason = 'user_stop'}) {
    if (phase == CapturePhase.recording) {
      phase = CapturePhase.draining;
      _limit?.cancel();
      _stoppedAt = clock.utcNow();
      _stoppedUs = clock.monotonicUs;
      _reason = reason;
      // Release reports are batched; a bounded drain admits late reports.
      // Flutter exposes no public flush/completion guarantee.
      _drain = Timer(drainDuration, _finish);
    }
    return completed;
  }

  void _finish() {
    if (phase != CapturePhase.draining) return;
    source.stop();
    final frames = _frames.toList();
    final motion = _motion.toList();
    final frameNumbers = motion
        .map((m) => m.frameNumber)
        .where((number) => number >= 0)
        .toSet();
    final correlated = frames
        .where(
          (f) => f.frameNumber >= 0 && frameNumbers.contains(f.frameNumber),
        )
        .length;
    if (frames.isEmpty) _errors.add('engine_timings_unavailable');
    if (motion.isEmpty) _errors.add('motion_samples_unavailable');
    if (_motionFrameNumberUnavailable) {
      _errors.add('motion_frame_number_unavailable');
    }
    if (_engineFrameNumberUnavailable) {
      _errors.add('engine_frame_number_unavailable');
    }
    if (correlated == 0) {
      _errors.add('engine_motion_frame_number_correlation_unavailable');
    }
    final record = DiagnosticRecord(
      runId: _runId,
      buildId: Env.buildId,
      startedAt: _startedAt!,
      stoppedAt: _stoppedAt!,
      startedMonotonicUs: _startedUs,
      stoppedMonotonicUs: _stoppedUs,
      finalizedMonotonicUs: clock.monotonicUs,
      stopReason: _reason,
      declarations: _declarations,
      metadata: _metadata,
      clocks: {
        'wall': 'UTC DateTime; may jump',
        'monotonic': 'recorder-local Stopwatch microseconds; independent epoch',
        'engine':
            'FrameTiming microseconds; vsyncUs is vsync start, engine epoch',
        'scheduler':
            'currentFrameTimeStamp; adjusted/time-dilated vsync target',
        'rawScheduler': 'currentSystemFrameTimeStamp; raw engine vsync target, not vsync start; metadata only',
        'frameNumber': 'same-frame post-frame PlatformDispatcher.frameData.frameNumber matches FrameTiming.frameNumber; negative means unavailable',
        'arrival': 'Stopwatch callback receipt; not frame presentation',
        'correlation': correlated == 0
            ? 'unavailable'
            : 'engine_frame_number_identity',
        'wallToMonotonic': 'unavailable; no epoch assumption',
        'engineToWall':
            'rasterFinishWallUs paired per frame; not used to select motion',
        'timingWindow': 'raw subscription samples may include preceding/trailing frames; aggregates only use nonnegative motion frame-number matches',
      },
      frames: frames,
      motion: motion,
      frameOverflow: _frameOverflow,
      motionOverflow: _motionOverflow,
      reportsDuringDrain: _drainReports,
      omittedOutsideMotion: frames.length - correlated,
      incompleteTrailingBatch: true,
      errors: List.of(_errors),
      aggregates: DiagnosticSummary.aggregate(frames, frameNumbers),
    );
    phase = CapturePhase.finished;
    _completion?.complete(record);
    _frames.clear();
    _motion.clear();
    _log.info('Capture finalized as partial evidence');
  }

  void dispose() {
    _limit?.cancel();
    _drain?.cancel();
    source.stop();
    if (_completion case final completion? when !completion.isCompleted) {
      completion.complete(null);
    }
    _completion = null;
    _frames.clear();
    _motion.clear();
    _metadata = const {};
    _errors.clear();
    phase = CapturePhase.disposed;
  }
}

@riverpod
DiagnosticRecorder diagnosticRecorder(Ref ref) {
  final recorder = DiagnosticRecorder(
    clock: SystemProbeClock(),
    source: SchedulerFrameSource(),
  );
  ref.onDispose(recorder.dispose);
  return recorder;
}
