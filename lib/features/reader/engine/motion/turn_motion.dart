import 'dart:async';

import 'package:shiori/features/reader/engine/motion/page_turn_gesture.dart';

/// A single elapsed-time settlement; no layout, leases or callbacks on tick.
final class TurnMotion {
  TurnMotion({required this.from, required this.to, required this.motion});
  final double from;
  final double to;
  final SettleMotion motion;
  final Completer<bool> _done = Completer();
  double? _start;
  bool _finished = false;
  Future<bool> get future => _done.future;
  bool get finished => _finished;

  double sample(double now) {
    _start ??= now;
    final progress = motion.duration <= 0
        ? 1.0
        : ((now - _start!) / motion.duration).clamp(0.0, 1.0);
    _finished = progress == 1;
    return from + (to - from) * hermiteEase(motion.launch, progress);
  }

  /// Called in an ordinary control task after the finishing tick.
  void complete(bool success) {
    if (!_done.isCompleted) _done.complete(success);
  }
}

/// A late surface follows the latest sample, even when the finger is held.
final class DragCatchUp {
  DragCatchUp(this.from);
  final double from;
  double? _start;
  bool finished = false;
  double sample(double now, double latest) {
    _start ??= now;
    final progress = ((now - _start!) / PageTurnRules.dragCatchUpDurationMs)
        .clamp(0.0, 1.0);
    finished = progress == 1;
    return from + (latest - from) * easeOutCubic(progress);
  }
}
