import 'reader_export_data.dart';

/// Independently checks the v1 sizing declaration against raw retained streams.
/// A sizing envelope is not proof of delivery, physical display or iOS safety.
GateRow captureBudgetGate(Json raw) {
  final engine = object(raw['engine'], 'engine');
  final metadata = object(engine['metadata'], 'metadata');
  final presentation = object(raw['presentation'], 'presentation');
  final inventory = object(presentation['inventory'], 'inventory');
  final nativeVersion = inventory['captureBudgetVersion'];
  if (nativeVersion != null && (nativeVersion is! int || nativeVersion != 1)) {
    throw const FormatException('Unsupported native capture budget version');
  }
  final declaration = metadata['readerCaptureBudget'];
  final overflow = object(raw['overflow'], 'overflow');
  var loss = false;
  for (final key in [
    'events',
    'layoutCosts',
    'resources',
    'frames',
    'motion',
    'native',
  ]) {
    final count = integer(overflow[key], 'overflow.$key');
    if (count < 0) throw const FormatException('Negative capture loss');
    loss |= count > 0;
  }
  loss |=
      integer(presentation['overflow'], 'native overflow') > 0 ||
      integer(presentation['unmatchedCallbacks'] ?? 0, 'unmatched callbacks') >
          0;
  GateRow result(String status, String reason) => GateRow(
    'long capture capacity / loss',
    declaration == null ? 'legacy' : 'v1',
    '10 min / 120 Hz envelope; zero losses in every stream',
    status,
    reason,
  );
  if (declaration == null) {
    return result(
      loss ? 'fail' : 'unavailable',
      'legacy: no versioned capture budget',
    );
  }
  final budget = object(declaration, 'readerCaptureBudget');
  if (budget['version'] is! int ||
      budget['version'] != 1 ||
      budget['storage'] != 'packed_numeric_rows' ||
      budget['repeatPolicy'] != 'stop_export_reset') {
    throw const FormatException('Unsupported reader capture budget');
  }
  const contract = {
    'maximumFrames': 72144,
    'maximumTurns': 4096,
    'eventsPerFrame': 8,
    'eventsPerTurn': 24,
    'requiredEvents': 675456,
    'nativeCapacity': 262144,
  };
  for (final entry in contract.entries) {
    if (integer(budget[entry.key], entry.key) != entry.value) {
      throw FormatException('Invalid capture envelope: ${entry.key}');
    }
  }
  final events = objects(raw['readerEvents'], 'events');
  final frames = objects(engine['frames'], 'frames');
  final motion = objects(engine['motion'], 'motion');
  final costs = objects(raw['layoutCosts'], 'costs');
  final resources = objects(raw['resources'], 'resources');
  final native = objects(presentation['samples'], 'native samples');
  final eventCapacity = integer(budget['eventCapacity'], 'eventCapacity');
  final auxiliaryCapacity = integer(
    budget['auxiliaryCapacity'],
    'auxiliaryCapacity',
  );
  final engineCapacity = integer(budget['engineCapacity'], 'engineCapacity');
  final maximumMs = integer(budget['maximumCaptureMs'], 'maximumCaptureMs');
  if (eventCapacity < 1 ||
      auxiliaryCapacity < 1 ||
      engineCapacity < 1 ||
      maximumMs < 1 ||
      events.length > eventCapacity ||
      costs.length > auxiliaryCapacity ||
      resources.length > auxiliaryCapacity ||
      frames.length > engineCapacity ||
      motion.length > engineCapacity ||
      native.length > 262144 && nativeVersion == 1) {
    throw const FormatException('Capture exceeds declared storage');
  }
  if (loss) {
    return result(
      'fail',
      'observed loss; retained samples cannot prove completeness',
    );
  }
  for (var i = 0; i < events.length; i++) {
    if (integer(events[i]['sequence'], 'event sequence') != i + 1) {
      return result(
        'fail',
        'event sequence is not contiguous from capture start',
      );
    }
  }
  final durationUs =
      integer(engine['stoppedMonotonicUs'], 'stop') -
      integer(engine['startedMonotonicUs'], 'start');
  final recognized = events
      .where((e) => e['event'] == 'inputRecognized')
      .length;
  final configured =
      eventCapacity >= 675456 &&
      auxiliaryCapacity >= 16384 &&
      engineCapacity >= 72144 &&
      maximumMs == 600000;
  final inEnvelope =
      durationUs >= 0 &&
      durationUs <= 600000000 &&
      frames.length <= 72144 &&
      motion.length <= 72144 &&
      recognized <= 4096;
  final nativeReady =
      presentation['available'] == true &&
      presentation['lossAccountingVersion'] == 1 &&
      nativeVersion == 1 &&
      inventory['ringCapacity'] == 262144;
  return result(
    configured && inEnvelope && nativeReady && events.isNotEmpty
        ? 'pass'
        : 'unavailable',
    'configured=$configured; withinEnvelope=$inEnvelope; nativeReady=$nativeReady; '
    'raw events=${events.length}, frames=${frames.length}, native=${native.length}; '
    'repeats require separate exports; trailing delivery remains qualified',
  );
}
