import 'dart:math' as math;

/// Logical-pixel rules from lan-reader a4bda23, pageTurnGesture.ts.
abstract final class PageTurnRules {
  static const directionLockPx = 10.0;
  static const horizontalRatio = 1.2;
  static const distanceRatio = 0.28;
  static const distanceMinPx = 72;
  static const distanceMaxPx = 160;
  static const velocityThresholdPxPerMs = 0.45;
  static const velocityWindowMs = 100.0;
  static const edgeRubberCoefficient = 0.35;
  static const edgeRubberScalePx = 60.0;
  static const tapLimitMs = 300.0;
  static const tapDurationMs = 420;
  static const turnLaunch = 1.3;
  static const settleLaunchMax = 3.0;
  static const settleFlickMinMs = 120;
  static const dragCatchUpDurationMs = 80;
  static const settleDurationMinMs = 260;
  static const settleDurationMaxMs = 420;
  static const relocatedTimeoutMs = 1200;
}

enum GestureAxis { pending, horizontal, vertical }

enum TapZone { previous, center, next }

typedef VelocitySample = ({double x, double time});
typedef SettleMotion = ({int duration, double launch});
typedef EaseKeyframe = ({double offset, double value});

GestureAxis classifyDirection(double dx, double dy) {
  if (math.max(dx.abs(), dy.abs()) < PageTurnRules.directionLockPx) {
    return GestureAxis.pending;
  }
  return dx.abs() >= dy.abs() * PageTurnRules.horizontalRatio
      ? GestureAxis.horizontal
      : GestureAxis.vertical;
}

int getDistanceThreshold(double width) => !width.isFinite || width <= 0
    ? PageTurnRules.distanceMinPx
    : (width * PageTurnRules.distanceRatio)
          .clamp(PageTurnRules.distanceMinPx, PageTurnRules.distanceMaxPx)
          .round();

double getRecentVelocity(List<VelocitySample> samples) {
  if (samples.length < 2) return 0;
  final last = samples.last;
  final cutoff = last.time - PageTurnRules.velocityWindowMs;
  final first = samples.firstWhere(
    (sample) => sample.time >= cutoff,
    orElse: () => samples.first,
  );
  final elapsed = last.time - first.time;
  return elapsed > 0 ? (last.x - first.x) / elapsed : 0;
}

int decidePageDelta({
  required double distanceX,
  required double velocityX,
  required double pageWidth,
}) {
  final distance = distanceX.abs() >= getDistanceThreshold(pageWidth);
  final velocity = velocityX.abs() >= PageTurnRules.velocityThresholdPxPerMs;
  if (!distance && !velocity) return 0;
  final deciding = distance ? distanceX : velocityX;
  return deciding < 0
      ? 1
      : deciding > 0
      ? -1
      : 0;
}

double clampDragDistance(double distance, double width) =>
    !width.isFinite || width <= 0 ? 0 : distance.clamp(-width, width);

double dampBoundaryDistance(double distance) {
  final stretch =
      distance.abs() *
      PageTurnRules.edgeRubberCoefficient /
      PageTurnRules.edgeRubberScalePx;
  return distance.sign *
      (1 - 1 / (stretch + 1)) *
      PageTurnRules.edgeRubberScalePx;
}

int getSettleDuration(double remaining, double width) {
  final ratio = width > 0 ? (remaining.abs() / width).clamp(0.0, 1.0) : 1.0;
  return (PageTurnRules.settleDurationMinMs +
          (PageTurnRules.settleDurationMaxMs -
                  PageTurnRules.settleDurationMinMs) *
              ratio)
      .round();
}

SettleMotion getSettleMotion({
  required double remaining,
  required double width,
  required double velocity,
}) {
  final speed = velocity.isFinite && velocity > 0 ? velocity : 0.0;
  final distance = remaining.abs();
  final duration = getSettleDuration(distance, width);
  if (!distance.isFinite || distance <= 0) {
    return (duration: duration, launch: PageTurnRules.turnLaunch);
  }
  final matched = speed * duration / distance;
  if (matched > PageTurnRules.settleLaunchMax) {
    return (
      duration: math.max(
        PageTurnRules.settleFlickMinMs,
        (PageTurnRules.settleLaunchMax * distance / speed).round(),
      ),
      launch: PageTurnRules.settleLaunchMax,
    );
  }
  return (
    duration: duration,
    launch: math.max(PageTurnRules.turnLaunch, matched),
  );
}

TapZone getTapZone(double x, double left, double width) {
  final ratio = width > 0 ? (x - left) / width : 0.5;
  return ratio < 1 / 3
      ? TapZone.previous
      : ratio > 2 / 3
      ? TapZone.next
      : TapZone.center;
}

double hermiteEase(double launch, double progress) {
  final v = (launch.isFinite ? launch : PageTurnRules.settleLaunchMax).clamp(
    0.0,
    PageTurnRules.settleLaunchMax,
  );
  final p = progress.clamp(0.0, 1.0);
  return v * (p * p * p - 2 * p * p + p) + 3 * p * p - 2 * p * p * p;
}

double easeOutCubic(double progress) {
  final rest = 1 - progress.clamp(0.0, 1.0);
  return 1 - rest * rest * rest;
}

List<EaseKeyframe> sampleEaseKeyframes([
  double launch = PageTurnRules.settleLaunchMax,
  double maxErrorRatio = 0.0025,
]) {
  final tolerance = maxErrorRatio.isFinite && maxErrorRatio > 0
      ? maxErrorRatio
      : 0.0025;
  double ease(double p) => hermiteEase(launch, p);
  final points = <EaseKeyframe>[(offset: 0, value: ease(0))];
  void append(double left, double right, int depth) {
    final a = ease(left);
    final b = ease(right);
    final exceeds = [0.25, 0.5, 0.75].any(
      (ratio) =>
          (ease(left + (right - left) * ratio) - (a + (b - a) * ratio)).abs() >
          tolerance,
    );
    if (exceeds && depth < 12) {
      final mid = (left + right) / 2;
      append(left, mid, depth + 1);
      append(mid, right, depth + 1);
    } else {
      points.add((offset: right, value: b));
    }
  }

  append(0, 1, 0);
  return points;
}

List<EaseKeyframe> sampleEaseOutCubicKeyframes([double tolerance = 0.0025]) =>
    sampleEaseKeyframes(PageTurnRules.settleLaunchMax, tolerance);
