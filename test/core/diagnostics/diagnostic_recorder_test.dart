import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/diagnostics/diagnostic_recorder.dart';
import 'package:shiori/core/diagnostics/probe_declarations.dart';

import '../../helpers/diagnostics_fixtures.dart';

void main() {
  late DiagnosticTestClock clock;
  late DiagnosticTestFrameSource source;

  setUp(() {
    clock = DiagnosticTestClock();
    source = DiagnosticTestFrameSource();
  });

  DiagnosticRecorder recorder({
    int capacity = 4096,
    Duration maximumDuration = const Duration(seconds: 15),
    Duration drainDuration = const Duration(milliseconds: 1200),
  }) {
    final value = DiagnosticRecorder(
      clock: clock,
      source: source,
      capacity: capacity,
      maximumDuration: maximumDuration,
      drainDuration: drainDuration,
    );
    addTearDown(value.dispose);
    return value;
  }

  void start(DiagnosticRecorder value, {String runId = 'run-1'}) {
    value.start(
      runId: runId,
      declarations: const ProbeDeclarations(),
      metadata: const {'os': 'test'},
    );
  }

  void motion(
    DiagnosticRecorder value,
    int vsyncUs, {
    int frameNumber = 1,
    int periodUs = 8333,
  }) {
    final rawUs = vsyncUs + periodUs;
    value.motion(
      frameNumber: frameNumber,
      schedulerUs: rawUs - 50000,
      rawSchedulerUs: rawUs,
      progress: .5,
    );
  }

  test('invalid bounds fail before subscribing', () {
    for (final capacity in [0, -1]) {
      expect(() => recorder(capacity: capacity), throwsArgumentError);
    }
    for (final duration in [Duration.zero, const Duration(seconds: -1)]) {
      expect(() => recorder(maximumDuration: duration), throwsArgumentError);
    }
    expect(
      () => recorder(drainDuration: const Duration(microseconds: -1)),
      throwsArgumentError,
    );
    expect(source.starts, 0);
  });

  testWidgets('rings evict oldest samples and count each omission', (
    tester,
  ) async {
    final value = recorder(capacity: 2);
    start(value);
    for (var i = 1; i <= 4; i++) {
      motion(value, i * 8333, frameNumber: i);
      source.emit([diagnosticTiming(i * 8333, frameNumber: i)]);
    }
    final completion = value.stop();
    await tester.pump(const Duration(milliseconds: 1200));
    final record = (await completion)!;
    expect(record.frames.map((frame) => frame.frameNumber), [3, 4]);
    expect(record.motion.map((sample) => sample.rawSchedulerUs), [
      33332,
      41665,
    ]);
    expect(record.frameOverflow, 2);
    expect(record.motionOverflow, 2);
    expect(record.aggregates['correlatedMotionFrames'], 2);
    expect(record.incompleteTrailingBatch, isTrue);
    expect(source.subscribed, isFalse);
  });

  testWidgets('drain admits late batches but excludes outside-motion costs', (
    tester,
  ) async {
    final value = recorder();
    start(value);
    motion(value, 100000, frameNumber: 2);
    source.emit([diagnosticTiming(91667, buildUs: 50000)]);
    clock.advance(const Duration(seconds: 1));
    final stoppedAt = clock.wall;
    final stoppedUs = clock.elapsedUs;
    final completion = value.stop(reason: 'background');
    expect(value.phase, CapturePhase.draining);
    expect(source.subscribed, isTrue);
    motion(value, 108333);
    clock.advance(const Duration(milliseconds: 500));
    source.emit([
      diagnosticTiming(100000, frameNumber: 2),
      diagnosticTiming(108333, frameNumber: 3, rasterUs: 50000),
    ]);
    await tester.pump(const Duration(milliseconds: 1199));
    expect(value.phase, CapturePhase.draining);
    clock.advance(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 1));
    final record = (await completion)!;
    expect(record.frames, hasLength(3));
    expect(record.motion, hasLength(1));
    expect(record.omittedOutsideMotion, 2);
    expect(record.reportsDuringDrain, 1);
    expect(record.stopReason, 'background');
    expect(record.stoppedAt, stoppedAt);
    expect(record.stoppedMonotonicUs, stoppedUs);
    expect(record.finalizedMonotonicUs, stoppedUs + 1200000);
    expect(record.frames[1].arrivalMonotonicUs, stoppedUs + 500000);
    expect(record.aggregates['ui'], containsPair('maxUs', 1000));
    expect(record.aggregates['raster'], containsPair('maxUs', 2000));
    expect(record.incompleteTrailingBatch, isTrue);
    source.emit([diagnosticTiming(116666)]);
    motion(value, 116666);
    expect(await value.completed, same(record));
    expect(record.frames, hasLength(3));
    expect(record.motion, hasLength(1));
  });

  testWidgets('repeated stop shares completion and the first stop reason', (
    tester,
  ) async {
    final value = recorder();
    start(value);
    final completion = value.stop(reason: 'first');
    expect(value.stop(reason: 'second'), same(completion));
    expect(value.completed, same(completion));
    expect(() => start(value), throwsStateError);
    await tester.pump(const Duration(milliseconds: 1200));
    final record = (await completion)!;
    expect(record.stopReason, 'first');
    expect(value.stop(), same(completion));
    expect(source.stops, 1);
  });

  testWidgets('duration limit stops once and still drains', (tester) async {
    final value = recorder(maximumDuration: const Duration(seconds: 2));
    start(value);
    expect(() => start(value), throwsStateError);
    await tester.pump(const Duration(milliseconds: 1999));
    expect(value.phase, CapturePhase.recording);
    clock.advance(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 1));
    expect(value.phase, CapturePhase.draining);
    source.emit([diagnosticTiming(100000)]);
    await tester.pump(const Duration(milliseconds: 1200));
    final record = (await value.completed)!;
    expect(record.stopReason, 'duration_limit');
    expect(record.stoppedMonotonicUs - record.startedMonotonicUs, 2000000);
    expect(record.reportsDuringDrain, 1);
    expect(source.stops, 1);
  });

  for (final stopBeforeDispose in [false, true]) {
    testWidgets(
      'dispose resolves pending ${stopBeforeDispose ? 'drain' : 'capture'}',
      (tester) async {
        final value = recorder();
        start(value);
        motion(value, 100000);
        source.emit([diagnosticTiming(100000)]);
        final completion = value.completed;
        // Disposal must resolve the pending drain without waiting for its timer.
        if (stopBeforeDispose) unawaited(value.stop());
        value.dispose();
        expect(await completion, isNull);
        expect(value.phase, CapturePhase.disposed);
        expect(source.subscribed, isFalse);
        source.emit([diagnosticTiming(108333)]);
        motion(value, 108333);
        await tester.pump(const Duration(seconds: 20));
        expect(await value.stop(), isNull);
        expect(value.phase, CapturePhase.disposed);
        expect(() => start(value), throwsStateError);
        value.dispose();
        expect(await value.completed, isNull);
      },
    );
  }

  testWidgets('restart resets samples, overflow, errors and completion', (
    tester,
  ) async {
    final value = recorder(capacity: 1, drainDuration: Duration.zero);
    start(value);
    source.emit([diagnosticTiming(1), diagnosticTiming(2)]);
    final firstCompletion = value.stop();
    await tester.pump(Duration.zero);
    final first = (await firstCompletion)!;
    expect(first.frameOverflow, 1);
    expect(first.errors, contains('motion_samples_unavailable'));
    clock.advance(const Duration(seconds: 3));
    start(value, runId: 'run-2');
    expect(value.completed, isNot(same(firstCompletion)));
    motion(value, 200000, frameNumber: 9);
    source.emit([diagnosticTiming(200000, frameNumber: 9)]);
    final secondCompletion = value.stop();
    await tester.pump(Duration.zero);
    final second = (await secondCompletion)!;
    expect(second.runId, 'run-2');
    expect(second.frames.single.frameNumber, 9);
    expect(second.motion, hasLength(1));
    expect(second.frameOverflow, 0);
    expect(second.motionOverflow, 0);
    expect(second.reportsDuringDrain, 0);
    expect(second.errors, isEmpty);
    expect(source.starts, 2);
    expect(first.frames.single.vsyncUs, 2);
  });

  testWidgets('frame identity correlates distinct target/start timestamps', (
    tester,
  ) async {
    final value = recorder(drainDuration: Duration.zero);
    start(value);
    for (var i = 0; i < 5; i++) {
      motion(value, 100000 + i * 8333, frameNumber: i);
    }
    clock.wall = clock.wall.subtract(const Duration(days: 1));
    clock.elapsedUs = 8000000;
    source.emit([
      for (var i = 0; i < 5; i++)
        diagnosticTiming(
          100000 + i * 8333,
          frameNumber: i,
          buildUs: i == 0
              ? 3000
              : i == 4
              ? 5000
              : 1000,
        ),
      // A target timestamp can equal the next frame's start. It must not match
      // that frame: engine identity, rather than timestamp equality, owns scope.
      diagnosticTiming(141665, frameNumber: 99, buildUs: 90000),
    ]);
    final completion = value.stop();
    await tester.pump(Duration.zero);
    final record = (await completion)!;
    expect(record.motion.first.rawSchedulerUs, 108333);
    expect(record.motion.first.frameNumber, 0);
    expect(record.frames.first.vsyncUs, 100000);
    expect(record.motion.map((m) => m.frameNumber), [0, 1, 2, 3, 4]);
    expect(record.frames.take(5).map((f) => f.frameNumber), [0, 1, 2, 3, 4]);
    expect(record.aggregates['ui'], containsPair('p95Us', 5000));
    expect(record.frames.last.arrivalMonotonicUs, 8000000);
    expect(record.frames.last.rasterFinishWallUs, greaterThan(1000000000000));
    expect(record.aggregates['correlatedMotionFrames'], 5);
    expect(record.aggregates['ui'], containsPair('count', 5));
    expect(record.aggregates['ui'], containsPair('maxUs', 5000));
    expect(record.aggregates['raster'], containsPair('count', 5));
    expect(record.aggregates['vsyncIntervals'], containsPair('count', 4));
    expect(record.aggregates['cadencePattern'], 'observed_near_120hz');
    expect(record.omittedOutsideMotion, 1);
    expect(record.clocks['correlation'], 'engine_frame_number_identity');
    expect(record.clocks['rawScheduler'], contains('vsync target'));
    expect(record.clocks['wallToMonotonic'], startsWith('unavailable'));
    expect(record.stoppedAt.isBefore(record.startedAt), isTrue);
    expect(record.stoppedMonotonicUs, greaterThan(record.startedMonotonicUs));
    expect(record.physicalPresentation, 'unverified');
  });

  testWidgets(
    'unavailable negative identities retain raw evidence and bounded errors',
    (tester) async {
      final value = recorder(drainDuration: Duration.zero);
      start(value);
      for (var i = 0; i < 10; i++) {
        motion(value, 100000 + i * 8333, frameNumber: -1);
      }
      source.emit([
        diagnosticTiming(100000, frameNumber: -1),
        diagnosticTiming(108333, frameNumber: 0),
      ]);
      final completion = value.stop();
      await tester.pump(Duration.zero);
      final record = (await completion)!;
      expect(record.motion, hasLength(10));
      expect(record.motion.first.frameNumber, -1);
      expect(
        record.errors,
        unorderedEquals([
          'motion_frame_number_unavailable',
          'engine_frame_number_unavailable',
          'engine_motion_frame_number_correlation_unavailable',
        ]),
      );
      expect(record.clocks['correlation'], 'unavailable');
      expect(record.omittedOutsideMotion, 2);
      expect(record.aggregates['ui'], containsPair('count', 0));
      expect(record.aggregates['vsyncIntervals'], containsPair('count', 0));
    },
  );

  testWidgets(
    'unavailable identity errors survive eviction and reset on restart',
    (tester) async {
      final value = recorder(capacity: 1, drainDuration: Duration.zero);
      start(value);
      motion(value, 91667, frameNumber: -1);
      source.emit([diagnosticTiming(91667, frameNumber: -1)]);
      motion(value, 100000, frameNumber: 2);
      source.emit([diagnosticTiming(100000, frameNumber: 2)]);
      final completion = value.stop();
      await tester.pump(Duration.zero);
      final first = (await completion)!;
      expect(first.motion.single.frameNumber, 2);
      expect(first.frames.single.frameNumber, 2);
      expect(first.frameOverflow, 1);
      expect(first.motionOverflow, 1);
      expect(
        first.errors,
        unorderedEquals([
          'motion_frame_number_unavailable',
          'engine_frame_number_unavailable',
        ]),
      );
      expect(first.aggregates['correlatedMotionFrames'], 1);
      start(value, runId: 'valid-restart');
      motion(value, 200000, frameNumber: 3);
      source.emit([diagnosticTiming(200000, frameNumber: 3)]);
      final restarted = value.stop();
      await tester.pump(Duration.zero);
      expect((await restarted)!.errors, isEmpty);
    },
  );

  testWidgets(
    'missing or uncorrelated data remains explicit partial evidence',
    (tester) async {
      final value = recorder(drainDuration: Duration.zero);
      expect(await value.stop(), isNull);
      start(value);
      final emptyCompletion = value.stop();
      await tester.pump(Duration.zero);
      final empty = (await emptyCompletion)!;
      expect(
        empty.errors,
        unorderedEquals([
          'engine_timings_unavailable',
          'motion_samples_unavailable',
          'engine_motion_frame_number_correlation_unavailable',
        ]),
      );
      start(value);
      motion(value, 100000);
      source.emit([diagnosticTiming(200000, frameNumber: 2)]);
      final completion = value.stop();
      await tester.pump(Duration.zero);
      final record = (await completion)!;
      expect(record.errors, [
        'engine_motion_frame_number_correlation_unavailable',
      ]);
      expect(record.clocks['correlation'], 'unavailable');
      expect(record.omittedOutsideMotion, 1);
      expect(record.aggregates['vsyncIntervals'], containsPair('count', 0));
      expect(record.incompleteTrailingBatch, isTrue);
    },
  );
}
