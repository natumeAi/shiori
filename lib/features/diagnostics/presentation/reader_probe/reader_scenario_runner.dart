import 'dart:ui' show Rect;

import 'package:flutter/gestures.dart';
import 'package:shiori/features/diagnostics/presentation/reader_probe/scenario_frames.dart';
import 'package:shiori/features/diagnostics/presentation/reader_probe/scenario_target.dart';

part 'package:shiori/features/diagnostics/presentation/reader_probe/scenario_scripts.dart';

final class ScenarioCancelled implements Exception {
  const ScenarioCancelled();
}

/// One move per actual frame. At 120 Hz the nominal step is 8333 microseconds;
/// slower displays retain their actual timestamps and never receive catch-up bursts.
final class ReaderScenarioRunner {
  ReaderScenarioRunner({
    required this.target,
    required this.readerRect,
    ScenarioFrames? frames,
    void Function(PointerEvent)? inject,
  }) : frames = frames ?? SchedulerScenarioFrames(),
       inject = inject ?? GestureBinding.instance.handlePointerEvent;
  static const fixtures = {
    'R01': 'long-content',
    'R02': 'chapters',
    'R03': 'long-content',
    'R04': 'chapters',
    'R05': 'chapters',
    'R06': 'long-content',
    'R07': 'images',
    'R08': 'styles',
    'R09': 'chapters',
    'R10': 'long-content',
    'R11': null,
  };
  static const nominalFrameUs = 8333;
  final ScenarioTarget target;
  final Rect Function() readerRect;
  final ScenarioFrames frames;
  final void Function(PointerEvent) inject;
  bool _cancelled = false;
  int _pointer = 9000;
  bool _down = false;
  Offset _position = Offset.zero;
  Duration _time = Duration.zero;

  void cancel() {
    _cancelled = true;
    if (_down) {
      inject(
        PointerCancelEvent(
          pointer: _pointer,
          position: _position,
          timeStamp: _time,
        ),
      );
      _down = false;
    }
    target.releasePreparation();
  }

  void _check() {
    if (_cancelled) throw const ScenarioCancelled();
  }

  Future<void> _frame() async {
    _check();
    _time = await frames.next();
    _check();
  }

  Future<void> waitFrames(int count) async {
    for (var i = 0; i < count; i++) {
      await _frame();
    }
  }

  Future<void> _waitMs(int milliseconds) async {
    await _frame();
    final start = _time;
    while ((_time - start).inMilliseconds < milliseconds) {
      await _frame();
    }
  }

  Offset _point(double fraction) {
    final rect = readerRect();
    return Offset(rect.left + rect.width * fraction, rect.center.dy);
  }

  Future<void> _press(double fraction) async {
    await _frame();
    _pointer++;
    _position = _point(fraction);
    _down = true;
    inject(
      PointerDownEvent(
        pointer: _pointer,
        position: _position,
        timeStamp: _time,
        kind: PointerDeviceKind.touch,
      ),
    );
  }

  Future<void> _move(double fraction) async {
    await _frame();
    final next = _point(fraction);
    inject(
      PointerMoveEvent(
        pointer: _pointer,
        position: next,
        delta: next - _position,
        timeStamp: _time,
        kind: PointerDeviceKind.touch,
      ),
    );
    _position = next;
  }

  Future<void> _release() async {
    await _frame();
    inject(
      PointerUpEvent(
        pointer: _pointer,
        position: _position,
        timeStamp: _time,
        kind: PointerDeviceKind.touch,
      ),
    );
    _down = false;
  }

  Future<void> tap(bool next, {bool settle = true}) async {
    await _press(next ? .78 : .22);
    await _release();
    if (settle) {
      await _waitMs(500);
    }
  }

  Future<void> drag(
    double from,
    double to,
    int moves, {
    bool reverse = false,
    bool held = false,
  }) async {
    await _press(from);
    for (var i = 1; i <= moves; i++) {
      await _move(from + (to - from) * i / moves);
    }
    if (held) {
      await _waitMs(180);
      target.releasePreparation();
      await _waitMs(160);
    }
    if (reverse) {
      for (var i = 1; i <= moves; i++) {
        await _move(to + (from - to) * i / moves);
      }
    }
    await _release();
    await _waitMs(500);
  }

  Future<void> run(String id) async {
    if (!fixtures.containsKey(id)) throw ArgumentError.value(id);
    _check();
    try {
      await _script(id);
    } finally {
      target.releasePreparation();
    }
  }
}
