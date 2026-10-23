import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/engine/motion/page_turn_engine.dart';
import 'package:shiori/features/reader/engine/motion/turn_intent_queue.dart';
import 'package:shiori/features/reader/engine/motion/turn_session.dart';

import 'motion_test_support.dart';

const next = TurnDirection.next;
const prev = TurnDirection.previous;
GestureInput point(double x, double time, [double y = 0]) =>
    GestureInput(x, y, time);
void main() {
  test(
    'FIFO one current eight waiting and explicit overflow in owned handoff',
    () async {
      final h = MotionHarness();
      final gate = Completer<TurnNavigation>();
      h.session.navigationGate = gate.future;
      final first = h.controller.turnPage(next);
      await h.clock.flush();
      h.session.state = TurnSessionState.handoff;
      final directions = [next, prev, next, prev, next, prev, next, prev];
      final waiting = directions.map(h.controller.turnPage).toList();
      expect(h.controller.queueDepth, 8);
      expect(
        (await h.controller.turnPage(prev)).kind,
        TurnResultKind.queueFull,
      );
      h.session.navigationGate = null;
      h.session.state = TurnSessionState.ready;
      gate.complete(TurnNavigation.verified(position(11)));
      await h.settle();
      expect(
        (await Future.wait([first, ...waiting])).map((r) => r.kind),
        everyElement(TurnResultKind.committed),
      );
      expect(h.accepted.map((p) => p.pageIndex), [
        11,
        12,
        11,
        12,
        11,
        12,
        11,
        12,
        11,
      ]);
      expect(h.session.optional.where((x) => x).length, 1);
    },
  );
  test(
    'second waiting pointer is busy without affecting owned handoff',
    () async {
      final h = MotionHarness();
      final gate = Completer<TurnNavigation>();
      h.session.navigationGate = gate.future;
      final first = h.controller.turnPage(next);
      await h.clock.flush();
      expect(h.controller.pointerDown(1, point(200, 0)), true);
      expect(h.controller.pointerDown(2, point(200, 0)), false);
      h.controller.cancel();
      gate.complete(TurnNavigation.verified(position(11)));
      await h.clock.flush();
      expect((await first).kind, TurnResultKind.cancelled);
    },
  );
  test(
    '100 capacity-controlled alternating inputs use sequential origins',
    () async {
      final h = MotionHarness();
      for (var i = 0; i < 100; i++) {
        expect(
          (await h.turn(i.isEven ? next : prev)).kind,
          TurnResultKind.committed,
        );
      }
      expect(h.accepted.length, 100);
      expect(h.controller.accepted.pageIndex, 10);
    },
  );
  for (final initial in [0, 20]) {
    test('pending opposite swipe rebases old boundary at $initial', () async {
      final h = MotionHarness(initial: initial);
      final first = h.controller.turnPage(initial == 0 ? next : prev);
      h.controller.pointerDown(1, point(200, 0));
      final sign = initial == 0 ? 1.0 : -1.0;
      h.controller.pointerMove(1, point(200 + sign * 140, 200));
      final second = h.controller.pointerUp(1, point(200 + sign * 140, 400));
      await h.settle();
      expect((await first).kind, TurnResultKind.committed);
      expect((await second!).kind, TurnResultKind.committed);
      expect(h.controller.accepted.pageIndex, initial);
    });
  }
  test(
    'held pointer reserves FIFO and promotes at accepted position',
    () async {
      final h = MotionHarness();
      final first = h.controller.turnPage(next);
      h.controller.pointerDown(1, point(200, 0));
      h.controller.pointerMove(1, point(60, 200));
      final last = h.controller.turnPage(prev);
      await h.clock.flush();
      expect(h.controller.accepted.pageIndex, 11);
      expect(h.controller.queueDepth, 1);
      expect((await first).kind, TurnResultKind.committed);
      final held = h.controller.pointerUp(1, point(60, 400));
      await h.settle();
      expect((await held!).kind, TurnResultKind.committed);
      expect((await last).kind, TurnResultKind.committed);
      expect(h.accepted.map((p) => p.pageIndex), [11, 12, 11]);
    },
  );
  for (final action in ['center', 'cancel', 'vertical']) {
    test('pending $action never changes preceding turn or opens UI', () async {
      final h = MotionHarness();
      final first = h.controller.turnPage(next);
      h.controller.pointerDown(1, point(200, 0));
      Future<TurnResult>? pending;
      if (action == 'cancel') {
        h.controller.pointerCancel(1);
      } else {
        if (action == 'vertical') {
          h.controller.pointerMove(1, point(200, 20, 100));
        }
        pending = h.controller.pointerUp(1, point(200, 40));
      }
      await h.settle();
      expect((await first).kind, TurnResultKind.committed);
      if (pending != null) await pending;
      expect(h.accepted.length, 1);
      expect(h.controller.queueDepth, 0);
    });
  }
  for (final state in [
    TurnSessionState.failed,
    TurnSessionState.closed,
    TurnSessionState.suspended,
    TurnSessionState.loading,
  ]) {
    test('own handoff does not override engine $state', () async {
      final h = MotionHarness();
      h.session.state = state;
      expect((await h.controller.turnPage(next)).kind, TurnResultKind.blocked);
    });
  }
  for (final failure in [false, true]) {
    test(
      'cancel terminates FIFO and ignores late ${failure ? 'failure' : 'success'}',
      () async {
        final h = MotionHarness();
        final gate = Completer<TurnNavigation>();
        h.session.navigationGate = gate.future;
        final first = h.controller.turnPage(next);
        final waiting = h.controller.turnPage(prev);
        await h.clock.flush();
        h.controller.cancel();
        if (failure) {
          gate.completeError(StateError('late'));
        } else {
          gate.complete(TurnNavigation.verified(position(11)));
        }
        await h.clock.flush();
        expect((await first).kind, TurnResultKind.cancelled);
        expect((await waiting).kind, TurnResultKind.cancelled);
        expect(h.accepted, isEmpty);
      },
    );
  }
  test('failure clears FIFO even after successful origin recovery', () async {
    final h = MotionHarness();
    h.session.proof = false;
    final first = h.controller.turnPage(next);
    final queued = h.controller.turnPage(prev);
    await h.settle();
    expect((await first).kind, TurnResultKind.failed);
    expect((await queued).kind, TurnResultKind.failed);
    expect(h.session.restores, 1);
  });
  test(
    'ordinary boundary consumes one entry and permits following reverse',
    () async {
      final h = MotionHarness(initial: 20);
      final first = h.controller.turnPage(next);
      final reverse = h.controller.turnPage(prev);
      await h.settle();
      expect((await first).kind, TurnResultKind.boundary);
      expect((await reverse).kind, TurnResultKind.committed);
    },
  );
  for (final phase in ['preparing', 'settling']) {
    test('queues during $phase without consulting geometry', () async {
      final h = MotionHarness(reduced: false);
      final prepare = Completer<PreparedTurn?>();
      if (phase == 'preparing') h.session.prepareGate = prepare.future;
      final first = h.controller.turnPage(next);
      await h.clock.flush();
      expect(h.controller.phase.name, phase);
      expect(h.controller.pointerDown(1, point(200, 0)), true);
      expect(h.controller.queueDepth, 1);
      h.controller.cancel();
      prepare.complete(null);
      await h.clock.flush();
      expect((await first).kind, TurnResultKind.cancelled);
    });
  }
  for (final ending in ['settings', 'layout', 'suspend', 'close', 'disabled']) {
    test(
      '$ending terminates waiting turns and pointer without replay',
      () async {
        final h = MotionHarness(reduced: false);
        final first = h.controller.turnPage(next);
        final queued = h.controller.turnPage(prev);
        h.controller.pointerDown(1, point(200, 0));
        await h.clock.flush();
        switch (ending) {
          case 'settings':
            h.controller.settingsChanged();
          case 'layout':
            h.controller.layoutChanged();
          case 'suspend':
            h.controller.suspend();
          case 'close':
            h.controller.close();
          case 'disabled':
            h.controller.configure(disabled: true);
        }
        await h.settle();
        expect((await first).kind, TurnResultKind.cancelled);
        expect((await queued).kind, TurnResultKind.cancelled);
        expect(h.accepted, isEmpty);
      },
    );
  }
  for (final ending in ['cancel', 'callback-reject']) {
    test('accepted result stays committed after $ending', () async {
      final callback = Completer<void>();
      final h = MotionHarness(callback: () => callback.future);
      final first = h.controller.turnPage(next);
      await h.clock.flush();
      final queued = h.controller.turnPage(prev);
      if (ending == 'cancel') {
        h.controller.cancel();
        callback.complete();
      } else {
        callback.completeError(StateError('callback'));
      }
      await h.clock.flush();
      expect((await first).kind, TurnResultKind.committed);
      expect(
        (await queued).kind,
        ending == 'cancel' ? TurnResultKind.cancelled : TurnResultKind.failed,
      );
      expect(h.controller.accepted.pageIndex, 11);
      expect(h.accepted.length, 1);
    });
  }
}
