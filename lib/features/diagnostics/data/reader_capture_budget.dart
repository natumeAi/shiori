/// Versioned, per-repeat envelope; repeats are stopped/exported independently.
abstract final class ReaderCaptureBudget {
  static const version = 1;
  static const eventCapacity = 786432;
  static const auxiliaryCapacity = 16384;
  static const engineCapacity = 131072;
  static const nativeCapacity = 262144;
  static const maximumDuration = Duration(minutes: 10);
  static const maximumFrames = 72144; // 120 Hz, including the 1.2 s drain.
  static const maximumTurns = 4096;
  static const eventsPerFrame = 8;
  static const eventsPerTurn = 24;
  static const requiredEvents =
      maximumFrames * eventsPerFrame + maximumTurns * eventsPerTurn;

  static Map<String, Object?> describe({
    required int events,
    required int auxiliary,
    required int engine,
    required int maximumMs,
  }) => {
    'version': version,
    'storage': 'packed_numeric_rows',
    'eventCapacity': events,
    'auxiliaryCapacity': auxiliary,
    'engineCapacity': engine,
    'maximumCaptureMs': maximumMs,
    'maximumFrames': maximumFrames,
    'maximumTurns': maximumTurns,
    'eventsPerFrame': eventsPerFrame,
    'eventsPerTurn': eventsPerTurn,
    'requiredEvents': requiredEvents,
    'nativeCapacity': nativeCapacity,
    'repeatPolicy': 'stop_export_reset',
  };
}
