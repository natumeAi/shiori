abstract interface class ProbeClock {
  DateTime utcNow();
  int get monotonicUs;
}
