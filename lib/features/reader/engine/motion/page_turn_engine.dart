import 'dart:math' as math;

import 'package:shiori/features/reader/engine/motion/page_turn_gesture.dart';

enum TurnDirection { previous, next }

enum ReadingDirection { ltr, rtl }

enum GesturePhase { tracking, dragging, cancelled }

enum ReleaseKind { tap, cancelled, commit, rebound }

final class GestureSnapshot {
  const GestureSnapshot({
    required this.width,
    this.direction = ReadingDirection.ltr,
    required this.canPrevious,
    required this.canNext,
  });
  final double width;
  final ReadingDirection direction;
  final bool canPrevious;
  final bool canNext;
}

final class GestureInput {
  const GestureInput(this.x, this.y, this.time);
  final double x;
  final double y;
  final double time;
}

final class GestureMove {
  const GestureMove(
    this.phase, {
    this.direction,
    this.distance = 0,
    this.visualDistance = 0,
    this.boundary = false,
  });
  final GesturePhase phase;
  final TurnDirection? direction;
  final double distance;
  final double visualDistance;
  final bool boundary;
}

final class GestureRelease {
  const GestureRelease(
    this.kind, {
    this.direction,
    this.distance = 0,
    this.visualDistance = 0,
    this.velocity = 0,
    this.elapsedMs = 0,
    this.duration = 0,
    this.launch = 0,
  });
  final ReleaseKind kind;
  final TurnDirection? direction;
  final double distance;
  final double visualDistance;
  final double velocity;
  final double elapsedMs;
  final int duration;
  final double launch;
}

/// Numeric state only; the controller owns preparation and rendered distance.
final class PageTurnEngine {
  PageTurnEngine(this._snapshot);
  GestureSnapshot _snapshot;
  GestureInput? _origin;
  bool _horizontal = false;
  double _lockOffset = 0;
  double _visual = 0;
  final List<VelocitySample> _samples = [];
  int get sampleCount => _samples.length;
  void rebase(GestureSnapshot next) => _snapshot = next;
  void begin(GestureInput input) {
    cancel();
    _origin = input;
    _samples.add((x: input.x, time: input.time));
  }

  TurnDirection _logical(double distance) =>
      (distance < 0) != (_snapshot.direction == ReadingDirection.rtl)
      ? TurnDirection.next
      : TurnDirection.previous;
  bool _boundary(TurnDirection direction) => direction == TurnDirection.next
      ? !_snapshot.canNext
      : !_snapshot.canPrevious;

  GestureMove move(GestureInput input) {
    final origin = _origin;
    if (origin == null) return const GestureMove(GesturePhase.cancelled);
    final distance = input.x - origin.x;
    if (!_horizontal) {
      final axis = classifyDirection(distance, input.y - origin.y);
      if (axis == GestureAxis.vertical) {
        cancel();
        return const GestureMove(GesturePhase.cancelled);
      }
      if (axis == GestureAxis.pending) {
        return GestureMove(GesturePhase.tracking, distance: distance);
      }
      _horizontal = true;
      _lockOffset = distance.sign * PageTurnRules.directionLockPx;
    }
    final length = _samples.length;
    final sample = (x: input.x, time: input.time);
    if (length >= 2 &&
        _samples[length - 1].time == input.time &&
        _samples[length - 2].time == input.time) {
      _samples[length - 1] = sample;
    } else {
      _samples.add(sample);
    }
    final cutoff = input.time - PageTurnRules.velocityWindowMs;
    var stale = 0;
    while (stale < _samples.length - 1 && _samples[stale].time < cutoff) {
      stale++;
    }
    stale = math.max(stale, _samples.length - 256);
    if (stale > 0) _samples.removeRange(0, stale);
    final shown = distance - _lockOffset;
    final next = _logical(shown != 0 ? shown : distance);
    final boundary = _boundary(next);
    _visual = boundary
        ? dampBoundaryDistance(shown)
        : clampDragDistance(shown, _snapshot.width);
    return GestureMove(
      GesturePhase.dragging,
      direction: next,
      distance: distance,
      visualDistance: _visual,
      boundary: boundary,
    );
  }

  GestureRelease release(GestureInput input) {
    final origin = _origin;
    if (origin == null) return const GestureRelease(ReleaseKind.cancelled);
    final distance = input.x - origin.x;
    final elapsed = input.time - origin.time;
    if (!_horizontal) {
      cancel();
      return GestureRelease(
        elapsed <= PageTurnRules.tapLimitMs
            ? ReleaseKind.tap
            : ReleaseKind.cancelled,
        distance: distance,
        elapsedMs: elapsed,
      );
    }
    _samples.add((x: input.x, time: input.time));
    final velocity = getRecentVelocity(_samples);
    final delta = decidePageDelta(
      distanceX: distance,
      velocityX: velocity,
      pageWidth: _snapshot.width,
    );
    final next = delta != 0 ? _logical(-delta.toDouble()) : _logical(distance);
    final commit = delta != 0 && !_boundary(next);
    final start = commit && _visual != 0 && _logical(_visual) != next
        ? 0.0
        : _visual;
    final heading = commit
        ? ((next == TurnDirection.next) !=
                  (_snapshot.direction == ReadingDirection.rtl)
              ? -1.0
              : 1.0)
        : -start.sign;
    final motion = getSettleMotion(
      remaining: commit
          ? math.max(0, _snapshot.width - start.abs())
          : start.abs(),
      width: _snapshot.width,
      velocity: math.max(0, velocity * heading),
    );
    cancel();
    return GestureRelease(
      commit ? ReleaseKind.commit : ReleaseKind.rebound,
      direction: next,
      distance: distance,
      visualDistance: start,
      velocity: velocity,
      elapsedMs: elapsed,
      duration: motion.duration,
      launch: motion.launch,
    );
  }

  void cancel() {
    _origin = null;
    _horizontal = false;
    _lockOffset = 0;
    _visual = 0;
    _samples.clear();
  }
}
