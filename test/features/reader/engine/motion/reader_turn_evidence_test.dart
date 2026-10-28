import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/engine/motion/page_turn_engine.dart';
import 'package:shiori/features/reader/engine/motion/reader_turn_controller.dart';
import 'package:shiori/features/reader/engine/motion/turn_session.dart';

import 'motion_test_support.dart';

typedef Evidence = ({
  TurnTimingEvent event,
  double time,
  int token,
  int active,
  Object? input,
  TurnPosition? destination,
});

final class _Sink implements TurnTimingSink, TurnEvidenceSink {
  final List<Evidence> events = [];
  @override
  void record(
    TurnTimingEvent event,
    double time,
    int generation,
    int queueDepth,
  ) {}
  @override
  void recordEvidence(
    TurnTimingEvent event,
    double time,
    int generation,
    int activeGeneration,
    int queueDepth,
    Object? input, {
    TurnPosition? destination,
  }) {
    events.add((
      event: event,
      time: time,
      token: generation,
      active: activeGeneration,
      input: input,
      destination: destination,
    ));
  }
}

void main() {
  test(
    'preview proof conflict is observable before a navigation handoff',
    () async {
      final clock = TestTurnClock(), sink = _Sink();
      final session = FakeTurnSession();
      session.prepareGate = Future.value(
        session.preview(
          session.foreground,
          TurnDirection.next,
          target: position(11, generation: 99),
        ),
      );
      final controller = ReaderTurnController(
        session: session,
        initial: session.foreground,
        clock: clock,
        width: 400,
        timing: sink,
      );
      final result = controller.turnPage(TurnDirection.next);
      await clock.flush();
      await result;
      expect(
        sink.events.where((e) => e.event == TurnTimingEvent.proofFailed),
        hasLength(1),
      );
      expect(
        sink.events.where((e) => e.event == TurnTimingEvent.inputCommitted),
        isEmpty,
      );
      controller.close();
      await clock.flush();
      expect(session.live, 0);
    },
  );
  test(
    'navigation decision and accepted identity share the original opaque input',
    () async {
      final clock = TestTurnClock(), sink = _Sink();
      final session = FakeTurnSession();
      final controller = ReaderTurnController(
        session: session,
        initial: session.foreground,
        clock: clock,
        width: 400,
        timing: sink,
      )..reducedMotion = true;
      final result = controller.turnPage(TurnDirection.next);
      await clock.flush();
      await result;
      final commit = sink.events.singleWhere(
        (e) => e.event == TurnTimingEvent.inputCommitted,
      );
      final accept = sink.events.singleWhere(
        (e) => e.event == TurnTimingEvent.accepted,
      );
      expect(identical(commit.input, accept.input), true);
      expect(identical(commit.input, sink.events.first.input), true);
      expect(
        sink.events.indexOf(commit),
        lessThan(sink.events.indexOf(accept)),
      );
      expect(accept.destination?.pageIndex, 11);
      expect(
        accept.destination?.pageIdentity,
        controller.accepted.pageIdentity,
      );
      expect(accept.token, accept.active);
      controller.close();
      await clock.flush();
    },
  );
  for (final stage in ['navigation', 'preparation']) {
    test(
      'stale $stage rejection retains original input and callback token',
      () async {
        final clock = TestTurnClock(), sink = _Sink();
        final session = FakeTurnSession();
        final navigation = Completer<TurnNavigation>();
        final preparation = Completer<PreparedTurn?>();
        if (stage == 'navigation') {
          session.navigationGate = navigation.future;
        } else {
          session.prepareGate = preparation.future;
        }
        final controller = ReaderTurnController(
          session: session,
          initial: session.foreground,
          clock: clock,
          width: 400,
          timing: sink,
        )..reducedMotion = stage == 'navigation';
        final result = controller.turnPage(TurnDirection.next);
        await clock.flush();
        final input = sink.events.first.input;
        final token = controller.generation;
        controller.cancel();
        if (stage == 'navigation') {
          navigation.complete(TurnNavigation.verified(position(11)));
        } else {
          preparation.complete(
            session.preview(session.foreground, TurnDirection.next),
          );
        }
        await clock.flush();
        await result;
        final rejected = sink.events.where(
          (e) => e.event == TurnTimingEvent.staleCallbackRejected,
        );
        expect(rejected, isNotEmpty);
        expect(rejected.every((e) => identical(e.input, input)), true);
        expect(
          rejected.every((e) => e.token == token && e.active > token),
          true,
        );
        expect(
          sink.events.where((e) => e.event == TurnTimingEvent.accepted),
          isEmpty,
        );
        expect(controller.accepted.pageIndex, 10);
        controller.close();
        await clock.flush();
        expect(session.live, 0);
      },
    );
  }
  test(
    'pointer dwell is excluded; dirty, hold and release demand are explicit',
    () async {
      final clock = TestTurnClock(), sink = _Sink();
      final session = FakeTurnSession()..warm.add(TurnDirection.next);
      final controller = ReaderTurnController(
        session: session,
        initial: session.foreground,
        clock: clock,
        width: 400,
        timing: sink,
      );
      controller.pointerDown(1, GestureInput(200, 100, 0));
      await clock.flush();
      await clock.advance(1000);
      expect(
        sink.events.where((e) => e.event == TurnTimingEvent.inputRecognized),
        isEmpty,
      );
      controller.pointerMove(1, GestureInput(100, 100, 1000));
      await clock.flush();
      final recognized = sink.events.singleWhere(
        (e) => e.event == TurnTimingEvent.inputRecognized,
      );
      final admitted = sink.events.singleWhere(
        (e) => e.event == TurnTimingEvent.recognizedAdmission,
      );
      expect(recognized.time, 1000);
      expect(admitted.time, 1000);
      expect(
        sink.events.where((e) => e.event == TurnTimingEvent.frameDemandStart),
        hasLength(1),
      );
      controller.tick();
      expect(
        sink.events.where((e) => e.event == TurnTimingEvent.dragClean),
        hasLength(1),
      );
      expect(
        sink.events.where((e) => e.event == TurnTimingEvent.holdStart),
        hasLength(1),
      );
      await clock.advance(500);
      controller.pointerMove(1, GestureInput(80, 100, 1500));
      expect(
        sink.events.where((e) => e.event == TurnTimingEvent.holdEnd),
        hasLength(1),
      );
      expect(
        sink.events.where((e) => e.event == TurnTimingEvent.frameDemandStart),
        hasLength(2),
      );
      controller.pointerCancel(1);
      await clock.flush();
      final cancelled = sink.events.singleWhere(
        (e) => e.event == TurnTimingEvent.cancelled,
      );
      expect(cancelled.input, same(recognized.input));
      expect(
        sink.events.where((e) => e.event == TurnTimingEvent.frameDemandEnd),
        hasLength(2),
      );
      controller.close();
      await clock.flush();
      expect(session.live, 0);
    },
  );
  test(
    'queued input has recognition at receipt and admission only at promotion',
    () async {
      final clock = TestTurnClock(),
          sink = _Sink(),
          session = FakeTurnSession();
      final gate = Completer<TurnNavigation>();
      session.navigationGate = gate.future;
      final controller = ReaderTurnController(
        session: session,
        initial: session.foreground,
        clock: clock,
        width: 400,
        timing: sink,
      )..reducedMotion = true;
      final first = controller.turnPage(TurnDirection.next);
      await clock.flush();
      clock.now = 100;
      final second = controller.turnPage(TurnDirection.next);
      await clock.flush();
      final queued = sink.events.singleWhere(
        (e) => e.event == TurnTimingEvent.queued,
      );
      expect(
        sink.events
            .where(
              (e) =>
                  e.event == TurnTimingEvent.inputRecognized &&
                  identical(e.input, queued.input),
            )
            .single
            .time,
        100,
      );
      expect(
        sink.events.where(
          (e) =>
              e.event == TurnTimingEvent.recognizedAdmission &&
              identical(e.input, queued.input),
        ),
        isEmpty,
      );
      session.navigationGate = null;
      clock.now = 200;
      gate.complete(TurnNavigation.verified(position(11)));
      await clock.flush();
      await first;
      await second;
      expect(
        sink.events
            .where(
              (e) =>
                  e.event == TurnTimingEvent.recognizedAdmission &&
                  identical(e.input, queued.input),
            )
            .single
            .time,
        200,
      );
      controller.close();
      await clock.flush();
    },
  );
  test('a genuinely cached programmatic turn is classified warm', () async {
    final clock = TestTurnClock(), sink = _Sink();
    final session = FakeTurnSession()..warm.add(TurnDirection.next);
    final controller = ReaderTurnController(
      session: session,
      initial: session.foreground,
      clock: clock,
      width: 400,
      timing: sink,
    );
    final result = controller.turnPage(TurnDirection.next);
    await clock.flush();
    expect(
      sink.events.where((e) => e.event == TurnTimingEvent.preparationHit),
      hasLength(1),
    );
    expect(
      sink.events.where((e) => e.event == TurnTimingEvent.preparationMiss),
      isEmpty,
    );
    expect(session.trace, contains('prepare'));
    controller.close();
    await clock.flush();
    await result;
    expect(session.live, 0);
  });
}
