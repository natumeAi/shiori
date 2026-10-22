import 'package:shiori/core/diagnostics/probe_clock.dart';

class SystemProbeClock implements ProbeClock {
  SystemProbeClock() : _watch = Stopwatch()..start();
  final Stopwatch _watch;

  @override
  DateTime utcNow() => DateTime.now().toUtc();

  @override
  int get monotonicUs => _watch.elapsedMicroseconds;
}
