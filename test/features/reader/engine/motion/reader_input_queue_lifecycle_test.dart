import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';
import 'package:shiori/features/reader/engine/motion/page_turn_engine.dart';
import 'package:shiori/features/reader/engine/motion/reader_turn_controller.dart';
import 'package:shiori/features/reader/engine/motion/turn_intent_queue.dart';
import 'package:shiori/features/reader/engine/motion/turn_session.dart';

import 'motion_test_support.dart';

final class _Timing implements TurnTimingSink {
  final List<(TurnTimingEvent, bool)> events = [];
  @override
  void record(
    TurnTimingEvent event,
    double time,
    int generation,
    int queueDepth,
  ) {
    events.add((event, ReaderWorkGuard.inCallback));
  }
}

void main() {
  // readerInputQueue.test.ts:224-239,280-293; browser pointer capture (:241)
  // has no counterpart in Flutter's pointer routing.
  for (final ending in ['cancel', 'suspend']) {
    test(
      'promoted waiting rebound remains cancellable through $ending',
      () async {
        final h = MotionHarness(reduced: false);
        final gate = Completer<TurnNavigation>();
        h.session.navigationGate = gate.future;
        final first = h.controller.turnPage(TurnDirection.next);
        await h.settle();
        expect(h.controller.phase, TurnPhase.committing);
        expect(
          h.controller.pointerDown(2, const GestureInput(200, 100, 0)),
          isTrue,
        );
        h.controller.pointerMove(2, const GestureInput(180, 100, 50));
        h.session.navigationGate = null;
        gate.complete(TurnNavigation.verified(position(11)));
        await h.clock.flush();
        expect((await first).kind, TurnResultKind.committed);
        h.controller.tick();
        await h.clock.advance(80);
        h.controller.tick();
        await h.clock.flush();
        expect(h.controller.offset, -10);
        final rebound = h.controller.pointerUp(
          2,
          const GestureInput(180, 100, 500),
        );
        expect(rebound, isNotNull);
        await h.clock.flush();
        expect(h.controller.phase, TurnPhase.settling);
        if (ending == 'cancel') {
          h.controller.cancel();
        } else {
          h.controller.suspend();
        }
        expect((await rebound!).kind, TurnResultKind.cancelled);
        await h.settle();
        expect(h.accepted.map((p) => p.pageIndex), [11]);
        expect(h.session.live, 0);
      },
    );
  }

  for (final ending in ['failed', 'suspended']) {
    test(
      'cancel flushes queued timing after $ending without waiting for idle',
      () async {
        final clock = TestTurnClock();
        final session = FakeTurnSession();
        final timing = _Timing();
        final controller = ReaderTurnController(
          session: session,
          initial: session.foreground,
          clock: clock,
          width: 400,
          timing: timing,
        );
        final first = controller.turnPage(TurnDirection.next);
        await clock.flush();
        expect(controller.phase, TurnPhase.settling);
        final queued = controller.turnPage(TurnDirection.previous);
        if (ending == 'suspended') {
          controller.suspend();
        } else {
          session.state = TurnSessionState.failed;
          controller.cancel('failure');
        }
        expect((await first).kind, TurnResultKind.cancelled);
        expect((await queued).kind, TurnResultKind.cancelled);
        expect(
          timing.events.where((e) => e.$1 == TurnTimingEvent.queueClosed),
          isEmpty,
        );
        await clock.flush();
        final closed = timing.events.where(
          (e) => e.$1 == TurnTimingEvent.queueClosed,
        );
        expect(closed, hasLength(1));
        expect(closed.single.$2, isFalse);
        expect(session.live, 0);
        controller.close();
        await clock.flush();
      },
    );
  }
}
