import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/engine/motion/page_turn_engine.dart';
import 'package:shiori/features/reader/engine/motion/turn_intent_queue.dart';
import 'package:shiori/features/reader/engine/motion/turn_session.dart';

import 'motion_test_support.dart';

// readerTurnProof.test.ts:111-253, with numeric frame and control clocks.
void main() {
  test('prepared turn accepts exactly once and releases its cover', () async {
    final h = MotionHarness(reduced: false);
    expect((await h.turn(TurnDirection.next)).kind, TurnResultKind.committed);
    expect(h.accepted.map((p) => p.pageIndex), [11]);
    expect(h.session.origins.map((p) => p.pageIndex), [10]);
    expect(h.session.live, 0);
  });
  for (final reason in ['anchor', 'page', 'origin']) {
    test(
      'engine $reason mismatch restores without publishing or turning again',
      () async {
        final h = MotionHarness(reduced: false);
        h.session.response = TurnNavigation(
          TurnNavigationKind.mismatch,
          reason: reason,
        );
        final first = h.controller.turnPage(TurnDirection.next);
        final queued = h.controller.turnPage(TurnDirection.next);
        await h.settle();
        expect((await first).kind, TurnResultKind.failed);
        expect((await queued).kind, TurnResultKind.failed);
        expect(h.session.origins.length, 1);
        expect(h.session.restores, 1);
        expect(h.controller.accepted.pageIndex, 10);
        expect(h.accepted, isEmpty);
        expect(
          h.session.trace.indexOf('restore'),
          lessThan(h.session.trace.indexOf('release')),
        );
        h.session.response = null;
        expect(
          (await h.turn(TurnDirection.next)).kind,
          TurnResultKind.committed,
        );
      },
    );
  }
  for (final response in [
    TurnNavigationKind.boundary,
    TurnNavigationKind.unavailable,
  ]) {
    test('shown preview followed by $response is proof conflict', () async {
      final h = MotionHarness(reduced: false);
      h.session.response = TurnNavigation(response);
      expect((await h.turn(TurnDirection.next)).kind, TurnResultKind.failed);
      expect(h.session.restores, 1);
      expect(h.accepted, isEmpty);
      expect(h.session.origins.length, 1);
    });
  }
  test('verified foreground disagreeing with preview is rejected', () async {
    final h = MotionHarness(reduced: false);
    h.session.response = TurnNavigation.verified(position(12));
    expect((await h.turn(TurnDirection.next)).kind, TurnResultKind.failed);
    expect(h.controller.accepted.pageIndex, 10);
    expect(h.session.restores, 1);
  });
  test('static turn keeps plain boundary and verified paths', () async {
    final h = MotionHarness();
    h.session.response = const TurnNavigation(TurnNavigationKind.boundary);
    expect((await h.turn(TurnDirection.next)).kind, TurnResultKind.boundary);
    h.session.response = null;
    expect((await h.turn(TurnDirection.next)).kind, TurnResultKind.committed);
    expect(h.session.restores, 0);
    expect(h.session.trace, isNot(contains('prepare')));
  });
  for (final lifecycle in ['suspend', 'settings', 'close']) {
    for (final failure in [false, true]) {
      test(
        '$lifecycle during handoff ignores late ${failure ? 'failure' : 'success'}',
        () async {
          final h = MotionHarness(reduced: false);
          final gate = Completer<TurnNavigation>();
          h.session.navigationGate = gate.future;
          final result = h.controller.turnPage(TurnDirection.next);
          await h.settle();
          expect(h.controller.phase.name, 'committing');
          switch (lifecycle) {
            case 'suspend':
              h.controller.suspend();
            case 'settings':
              h.controller.settingsChanged();
            case 'close':
              h.controller.close();
          }
          if (failure) {
            gate.completeError(StateError('late'));
          } else {
            gate.complete(TurnNavigation.verified(position(11)));
          }
          await h.clock.flush();
          expect((await result).kind, TurnResultKind.cancelled);
          expect(h.accepted, isEmpty);
          expect(h.controller.accepted.pageIndex, 10);
          expect(h.session.live, 0);
        },
      );
    }
  }
  test('queued turns publish once from their own accepted origin', () async {
    final h = MotionHarness();
    final turns = [
      h.controller.turnPage(TurnDirection.next),
      h.controller.turnPage(TurnDirection.next),
      h.controller.turnPage(TurnDirection.previous),
    ];
    await h.settle();
    expect(
      (await Future.wait(turns)).map((r) => r.kind),
      everyElement(TurnResultKind.committed),
    );
    expect(h.accepted.map((p) => p.pageIndex), [11, 12, 11]);
    expect(h.session.origins.map((p) => p.pageIndex), [10, 11, 12]);
  });
}
