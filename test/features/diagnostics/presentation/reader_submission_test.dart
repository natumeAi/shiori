import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/diagnostics/data/reader_probe_recorder.dart';
import 'package:shiori/features/diagnostics/presentation/reader_probe/reader_scenario_runner.dart';
import 'package:shiori/features/diagnostics/presentation/reader_probe/scenario_target.dart';
import 'package:shiori/features/reader/engine/motion/page_turn_engine.dart';
import 'package:shiori/features/reader/engine/motion/turn_session.dart';
import 'package:shiori/features/reader/engine/surface/prepared_reader.dart';

import '../../../helpers/diagnostics_fixtures.dart';
import '../../../helpers/reader_probe_fixtures.dart';
import '../../reader/engine/surface/surface_test_support.dart';

Widget _view(SurfaceHarness h, {int Function()? frameNumber}) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: const MediaQueryData(),
    child: Center(
      child: SizedBox(
        width: 400,
        height: 600,
        child: PreparedReader(
          controller: h.controller,
          session: h.session,
          frameNumberForTesting: frameNumber,
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'injected drag reaches the real gesture controller and post-frame engine correlation',
    (tester) async {
      tester.binding.shouldPropagateDevicePointerEvents = true;
      try {
        final source = DiagnosticTestFrameSource();
        final rec = readerRecorder(capacity: 1024, source: source);
        addTearDown(rec.dispose);
        final sink = _RecordingSink(rec);
        final h = await SurfaceHarness.open(timing: sink);
        addTearDown(h.close);
        await h.session.warm(TurnDirection.next);
        await startReader(rec);
        var frame = 1000;
        final postFrameReads = <int>[];
        await tester.pumpWidget(
          _view(
            h,
            frameNumber: () {
              expect(
                SchedulerBinding.instance.schedulerPhase,
                SchedulerPhase.postFrameCallbacks,
              );
              postFrameReads.add(frame);
              source.emit([diagnosticTiming(frame * 8333, frameNumber: frame)]);
              return frame;
            },
          ),
        );
        final reader = find.byType(PreparedReader);
        final origin = h.controller.accepted;
        final rect = tester.getTopLeft(reader) & tester.getSize(reader);
        final runner = ReaderScenarioRunner(
          target: _UnusedTarget(),
          readerRect: () => rect,
        );
        var finished = false;
        final task = runner.drag(.78, .22, 30);
        unawaited(task.whenComplete(() => finished = true));
        for (var i = 0; i < 150 && !finished; i++) {
          frame++;
          h.clock.now += 8.333;
          await tester.pump(const Duration(microseconds: 8333));
          await h.clock.flush();
        }
        expect(finished, true);
        await task;
        expect(sink.failures, isEmpty);
        expect(
          h.controller.accepted.pageIndex,
          origin.pageIndex + 1,
          reason:
              'phase=${h.controller.phase}; events=${rec.events.snapshot().map((e) => e['event']).toList()}',
        );
        final stopped = rec.stop();
        await tester.pump(Duration.zero);
        final record = (await stopped)!;
        expect(record.engine.motion, isNotEmpty);
        expect(
          record.engine.clocks['correlation'],
          'engine_frame_number_identity',
        );
        final received = record.readerEvents.singleWhere(
          (e) => e['event'] == 'inputReceived',
        );
        final firstSubmission = record.readerEvents.singleWhere(
          (e) => e['event'] == 'firstMotionSubmission',
        );
        final accepted = record.readerEvents.singleWhere(
          (e) => e['event'] == 'accepted',
        );
        expect(received['inputId'], isNotNull);
        expect(firstSubmission['inputId'], received['inputId']);
        expect(accepted['inputId'], received['inputId']);
        expect(firstSubmission['frameNumber'], postFrameReads.first);
        expect(record.engine.motion.first.frameNumber, postFrameReads.first);
        expect(
          record.engine.frames.map((f) => f.frameNumber),
          contains(postFrameReads.first),
        );
        expect(sink.receivedInputs, hasLength(1));
        expect(sink.submittedInputs, isNotEmpty);
        expect(
          sink.submittedInputs.every(
            (input) => identical(input, sink.receivedInputs.single),
          ),
          true,
        );
        expect(
          record.readerEvents.where((e) => e['event'] == 'accepted').length,
          1,
        );
        expect(
          record.readerEvents
              .where((e) => e['event'] == 'firstMotionSubmission')
              .length,
          1,
        );
        await tester.pumpWidget(const SizedBox());
        await h.clock.flush();
      } finally {
        tester.binding.shouldPropagateDevicePointerEvents = false;
      }
    },
  );
  for (final invalidate in ['capture', 'generation']) {
    testWidgets('queued post-frame submission ignores changed $invalidate', (
      tester,
    ) async {
      final sink = _EpochSink();
      final h = await SurfaceHarness.open(timing: sink);
      addTearDown(h.close);
      await tester.pumpWidget(_view(h));
      final turn = h.controller.turnPage(TurnDirection.next);
      await h.clock.flush();
      h.clock.now = 0;
      h.controller.tick();
      SchedulerBinding.instance.scheduleFrameCallback((_) {
        h.clock.now = 100;
        h.controller.tick();
        if (invalidate == 'capture') {
          sink.epoch++;
        } else {
          h.controller.cancel();
        }
      });
      await tester.pump(const Duration(milliseconds: 16));
      await h.clock.flush();
      expect(sink.submissions, 0);
      h.controller.cancel();
      await h.clock.flush();
      await turn;
      await tester.pumpWidget(const SizedBox());
      await h.clock.flush();
    });
  }
}

class _UnusedTarget extends Fake implements ScenarioTarget {}

final class _RecordingSink
    implements TurnTimingSink, TurnTraceSink, TurnFrameSink, TurnFailureSink {
  _RecordingSink(this.recorder);
  final ReaderProbeRecorder recorder;
  final failures = <Object>[];
  final receivedInputs = <Object?>[];
  final submittedInputs = <Object?>[];
  @override
  int get frameEpoch => recorder.frameEpoch;
  @override
  void record(
    TurnTimingEvent event,
    double time,
    int generation,
    int queueDepth,
  ) => recorder.record(event, time, generation, queueDepth);
  @override
  void recordTurn(
    TurnTimingEvent event,
    double time,
    int generation,
    int queueDepth,
    Object? input,
  ) {
    if (event == TurnTimingEvent.inputReceived) receivedInputs.add(input);
    recorder.recordTurn(event, time, generation, queueDepth, input);
  }

  @override
  void submitted({
    required int frameNumber,
    required int schedulerUs,
    required int rawSchedulerUs,
    required int generation,
    required double offset,
    Object? input,
  }) {
    submittedInputs.add(input);
    recorder.submitted(
      frameNumber: frameNumber,
      schedulerUs: schedulerUs,
      rawSchedulerUs: rawSchedulerUs,
      generation: generation,
      offset: offset,
      input: input,
    );
  }

  @override
  void failure(Object error, StackTrace stack) {
    failures.add(error);
  }
}

final class _EpochSink implements TurnTimingSink, TurnFrameSink {
  int epoch = 0, submissions = 0;
  @override
  int get frameEpoch => epoch;
  @override
  void record(
    TurnTimingEvent event,
    double time,
    int generation,
    int queueDepth,
  ) {}
  @override
  void submitted({
    required int frameNumber,
    required int schedulerUs,
    required int rawSchedulerUs,
    required int generation,
    required double offset,
    Object? input,
  }) {
    submissions++;
  }
}
