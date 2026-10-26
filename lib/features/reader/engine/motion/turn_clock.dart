import 'dart:async';

/// Time and ordinary-task scheduling; tests advance both explicitly.
abstract interface class TurnClock {
  double get now;
  void post(void Function() task);
  void Function() after(Duration duration, void Function() task);
}

final class StopwatchTurnClock implements TurnClock {
  StopwatchTurnClock() {
    _watch.start();
  }
  final Stopwatch _watch = Stopwatch();
  @override
  double get now => _watch.elapsedMicroseconds / 1000;
  @override
  void post(void Function() task) => Timer.run(task);
  @override
  void Function() after(Duration duration, void Function() task) {
    final timer = Timer(duration, task);
    return timer.cancel;
  }
}
