import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/engine/motion/page_turn_gesture.dart';

const launches = [0.0, 0.5, 1.0, 1.3, 2.0, 2.5, 3.0];
// pageTurnEasing.test.ts:11-101, all six reference cases.
void main() {
  test('launch3 equals ease-out cubic; endpoints clamp', () {
    for (var i = 0; i <= 200; i++) {
      expect(hermiteEase(3, i / 200), closeTo(easeOutCubic(i / 200), 1e-12));
    }
    for (final v in launches) {
      expect(hermiteEase(v, -1), 0);
      expect(hermiteEase(v, 0), 0);
      expect(hermiteEase(v, 1), closeTo(1, 1e-12));
      expect(hermiteEase(v, 2), closeTo(1, 1e-12));
    }
  });
  test('Hermite monotonicity, no overshoot, launch and end slopes', () {
    for (final v in launches) {
      var previous = 0.0;
      for (var i = 0; i <= 1000; i++) {
        final value = hermiteEase(v, i / 1000);
        expect(value, greaterThanOrEqualTo(previous - 1e-12));
        expect(value, lessThanOrEqualTo(1 + 1e-12));
        previous = value;
      }
      expect(hermiteEase(v, 1e-6) / 1e-6, closeTo(v, 1e-4));
      expect((1 - hermiteEase(v, 1 - 1e-6)) / 1e-6, closeTo(0, 1e-4));
    }
    for (var i = 0; i <= 20; i++) {
      final p = i / 20;
      expect(hermiteEase(9, p), hermiteEase(3, p));
      expect(hermiteEase(-1, p), hermiteEase(0, p));
      expect(hermiteEase(double.nan, p), hermiteEase(3, p));
    }
  });
  test('adaptive keyframes meet 0.0025 error for every launch', () {
    for (final v in launches) {
      final points = sampleEaseKeyframes(v);
      expect(points.first.offset, 0);
      expect(points.last.offset, 1);
      expect(points.length, lessThan(80));
      for (var i = 0; i <= 2000; i++) {
        final p = i / 2000;
        final right = points.indexWhere((k) => k.offset >= p);
        final b = points[right];
        final a = points[right > 0 ? right - 1 : 0];
        final linear = a.offset == b.offset
            ? b.value
            : a.value +
                  (b.value - a.value) * (p - a.offset) / (b.offset - a.offset);
        expect(
          (linear - hermiteEase(v, p)).abs(),
          lessThanOrEqualTo(0.0025 + 1e-9),
        );
      }
    }
    expect(sampleEaseOutCubicKeyframes(), sampleEaseKeyframes(3));
    expect(sampleEaseKeyframes(), sampleEaseKeyframes(3));
  });
  test('tap animation is420ms at launch1.3', () {
    expect(PageTurnRules.tapDurationMs, 420);
    expect(PageTurnRules.turnLaunch, 1.3);
    expect(390 * hermiteEase(1.3, 1000 / 60 / 420), inExclusiveRange(15, 25));
  });
  test(
    'settle continues velocity, caps slope, floors flick and handles reversal',
    () {
      SettleMotion motion(double velocity, [double remaining = 300]) =>
          getSettleMotion(remaining: remaining, width: 400, velocity: velocity);
      final duration = getSettleDuration(300, 400);
      expect(motion(0), (duration: duration, launch: 1.3));
      final medium = motion(2);
      expect(medium.duration, duration);
      expect(medium.launch * 300 / duration, closeTo(2, 1e-12));
      expect(motion(0.5).launch, 1.3);
      expect(motion(4), (duration: 225, launch: 3.0));
      expect(motion(20), (duration: 120, launch: 3.0));
      for (final v in [0.0, 2.0, 50.0]) {
        expect(motion(v, 0), (duration: 260, launch: 1.3));
      }
      for (final v in [
        -3.0,
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        expect(motion(v), (duration: duration, launch: 1.3));
      }
      expect(motion(0, 450), (duration: 420, launch: 1.3));
    },
  );
  test('rubber band is monotone, below60px, initial slope0.35', () {
    var previous = 0.0;
    for (var x = 1; x <= 2000; x++) {
      final v = dampBoundaryDistance(x.toDouble());
      expect(v, inExclusiveRange(previous, 60));
      previous = v;
      expect(dampBoundaryDistance(-x.toDouble()), -v);
    }
    expect(dampBoundaryDistance(0), 0);
    expect(dampBoundaryDistance(112), closeTo(23.7, 0.05));
    expect(dampBoundaryDistance(1e-6) / 1e-6, closeTo(0.35, 1e-6));
  });
  test('tap thirds exact boundaries belong to center; thresholds clamp', () {
    expect(getTapZone(100, 0, 300), TapZone.center);
    expect(getTapZone(200, 0, 300), TapZone.center);
    expect(getTapZone(99, 0, 300), TapZone.previous);
    expect(getTapZone(201, 0, 300), TapZone.next);
    expect(getDistanceThreshold(1), 72);
    expect(getDistanceThreshold(9999), 160);
  });
}
