import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/engine/motion/page_turn_engine.dart';
import 'package:shiori/features/reader/engine/motion/page_turn_gesture.dart';

GestureInput input(num x, num time, [num y = 0]) =>
    GestureInput(x.toDouble(), y.toDouble(), time.toDouble());
PageTurnEngine gesture({
  bool next = true,
  bool previous = true,
  bool rtl = false,
}) => PageTurnEngine(
  GestureSnapshot(
    width: 400,
    canNext: next,
    canPrevious: previous,
    direction: rtl ? ReadingDirection.rtl : ReadingDirection.ltr,
  ),
)..begin(input(0, 0));

// readerPageTurnEngine.test.ts:13-146: all fourteen reference cases.
void main() {
  test(
    'axis lock deadzone, vertical rejection and persistent horizontal lock',
    () {
      final e = gesture();
      expect(e.move(input(9, 10, 8)).phase, GesturePhase.tracking);
      expect(e.move(input(10, 20, 20)).phase, GesturePhase.cancelled);
      expect(e.release(input(200, 30)).kind, ReleaseKind.cancelled);
      e.begin(input(0, 40));
      expect(e.move(input(12, 50, 10)).phase, GesturePhase.dragging);
      expect(e.move(input(15, 60, 300)).phase, GesturePhase.dragging);
    },
  );
  test('tap at 300 ms; longer hold ignored', () {
    expect(gesture().release(input(0, 300)).kind, ReleaseKind.tap);
    expect(gesture().release(input(0, 301)).kind, ReleaseKind.cancelled);
  });
  test('slow threshold commits; immediately below rebounds', () {
    for (final (distance, kind) in [
      (-111, ReleaseKind.rebound),
      (-112, ReleaseKind.commit),
    ]) {
      final e = gesture()..move(input(distance, 400));
      final r = e.release(input(distance, 600));
      expect(r.kind, kind);
      expect(r.direction, TurnDirection.next);
      expect(r.velocity, 0);
    }
  });
  test('recent flick commits; stopped short drag rebounds', () {
    final flick = gesture()..move(input(-20, 20));
    expect(flick.release(input(-40, 40)).kind, ReleaseKind.commit);
    final stopped = gesture()
      ..move(input(-20, 20))
      ..move(input(-20, 200));
    expect(stopped.release(input(-20, 220)).kind, ReleaseKind.rebound);
  });
  test(
    'distance wins opposite velocity; velocity reversal starts at origin',
    () {
      final far = gesture()
        ..move(input(-200, 200))
        ..move(input(-160, 220));
      final a = far.release(input(-120, 240));
      expect(a.kind, ReleaseKind.commit);
      expect(a.direction, TurnDirection.next);
      final near = gesture()
        ..move(input(-80, 200))
        ..move(input(-40, 220));
      final b = near.release(input(-10, 240));
      expect(b.kind, ReleaseKind.commit);
      expect(b.direction, TurnDirection.previous);
      expect(b.visualDistance, 0);
    },
  );
  test('zero crossing changes neighbor and full width clamps', () {
    final e = gesture();
    expect(e.move(input(-800, 200)).visualDistance, -400);
    final zero = e.move(input(0, 300));
    expect(zero.direction, TurnDirection.previous);
    expect(zero.visualDistance, 10);
    expect(e.move(input(200, 400)).visualDistance, 210);
  });
  test('lock offset prevents a jump and retains locked side at zero', () {
    for (final sign in [-1, 1]) {
      final e = gesture();
      final lock = e.move(input(12 * sign, 10));
      expect(lock.distance, 12 * sign);
      expect(lock.visualDistance, 2 * sign);
      for (final x in [40, 90, 150]) {
        expect(e.move(input(x * sign, x)).visualDistance, (x - 10) * sign);
      }
      final zero = e.move(input(10 * sign, 200));
      expect(zero.visualDistance, 0);
      expect(
        zero.direction,
        sign < 0 ? TurnDirection.next : TurnDirection.previous,
      );
    }
    expect(gesture().move(input(-10, 10, 5)).visualDistance, 0);
  });
  test('boundary rubber band never commits', () {
    final e = gesture(next: false);
    final m = e.move(input(-200, 20));
    expect(m.boundary, true);
    expect(m.visualDistance, dampBoundaryDistance(-190));
    expect(m.visualDistance, inExclusiveRange(-60, -30));
    expect(e.move(input(-5000, 30)).visualDistance, greaterThan(-60));
    expect(e.release(input(-200, 40)).kind, ReleaseKind.rebound);
  });
  test('release velocity projects onto settlement direction', () {
    final flick = gesture()..move(input(-50, 50));
    final r = flick.release(input(-150, 100));
    expect(r.visualDistance, -40);
    expect((
      duration: r.duration,
      launch: r.launch,
    ), getSettleMotion(remaining: 360, width: 400, velocity: 1.5));
    final back = gesture()
      ..move(input(-60, 20))
      ..move(input(-60, 300));
    final b = back.release(input(-50, 340));
    expect(b.kind, ReleaseKind.rebound);
    expect(b.visualDistance, -50);
    expect((
      duration: b.duration,
      launch: b.launch,
    ), getSettleMotion(remaining: 50, width: 400, velocity: 0.25));
    final away = gesture()
      ..move(input(-60, 20))
      ..move(input(-60, 300));
    expect(away.release(input(-70, 340)).launch, 1.3);
  });
  test('RTL physical direction and boundary map consistently', () {
    final e = gesture(rtl: true, previous: false);
    expect(e.move(input(-200, 100)).boundary, true);
    expect(e.move(input(200, 200)).direction, TurnDirection.next);
    expect(e.release(input(200, 400)).kind, ReleaseKind.commit);
  });
  test('frozen ruler; release and cancel cannot repeat', () {
    final e = gesture();
    e.move(input(-800, 100));
    expect(e.release(input(-800, 300)).kind, ReleaseKind.commit);
    expect(e.release(input(-800, 301)).kind, ReleaseKind.cancelled);
    e.begin(input(0, 400));
    e.cancel();
    expect(e.move(input(200, 500)).phase, GesturePhase.cancelled);
  });
  test(
    'release retains last proposed visual instead of final input sample',
    () {
      final e = gesture()..move(input(-120, 200));
      final r = e.release(input(-200, 400));
      expect(r.distance, -200);
      expect(r.visualDistance, -110);
      expect(r.duration, 376);
      expect(r.launch, 1.3);
    },
  );
  test('60, 120 and 240 Hz retain the whole velocity window', () {
    double x(double t) => t <= 200
        ? -0.1 * t
        : t <= 220
        ? -20 - 1.2 * (t - 200)
        : -44 - 0.3 * (t - 220);
    for (final hz in [60, 120, 240]) {
      final e = gesture();
      for (var i = 1; i < 300 * hz / 1000; i++) {
        final time = i * 1000 / hz;
        e.move(input(x(time), time));
      }
      final r = e.release(input(x(300), 300));
      expect(r.kind, ReleaseKind.commit);
      expect(r.velocity, closeTo(-0.48, 1e-9));
    }
  });
  test('same-timestamp storm stays bounded without changing decision', () {
    final e = gesture()..move(input(-20, 200));
    for (var i = 0; i < 5000; i++) {
      e.move(input(-30, 250));
    }
    expect(e.sampleCount, lessThanOrEqualTo(256));
    final r = e.release(input(-40, 260));
    expect(r.kind, ReleaseKind.rebound);
    expect(r.velocity, closeTo(-1 / 3, 1e-9));
  });
}
