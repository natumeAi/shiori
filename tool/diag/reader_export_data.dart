// Independent JSON boundary: this tool deliberately imports no application code.
typedef Json = Map<String, Object?>;

abstract final class ReaderGates {
  static const stageBudgetUs = 8333;
  static const minimumWithinBudget = .99;
  static const missedIntervalUs = 12500;
  static const stallUs = 50000;
  static const warmSubmissionP95Us = 16700;
  static const minimumResourceTurns = 100;
  static const minimumRepeats = 3;
  static const correctnessFailures = 0;
  static const destinationsPerCommit = 1;

  /// Observational RSS bound over the whole capture: endpoint growth AND
  /// positive OLS slope projected across its duration must each be <=5%
  /// of first RSS. This permits allocator noise, not an indefinite leak.
  static const maximumRssGrowthFraction = .05;
}

Json object(Object? value, String path) {
  if (value is! Map<String, Object?>) {
    throw FormatException('$path must be an object');
  }
  return value;
}

List<Json> objects(Object? value, String path) {
  if (value is! List<Object?>) {
    throw FormatException('$path must be an array');
  }
  return [for (var i = 0; i < value.length; i++) object(value[i], '$path[$i]')];
}

int integer(Object? value, String path) {
  if (value is! int) throw FormatException('$path must be an integer');
  return value;
}

num number(Object? value, String path) {
  if (value is! num || !value.isFinite) {
    throw FormatException('$path must be finite numeric data');
  }
  return value;
}

String string(Object? value, String path) {
  if (value is! String) throw FormatException('$path must be a string');
  return value;
}

/// S1 uses ceil((n-1)*p); the reader summary uses ceil(n*p)-1.
Json distribution(
  Iterable<int> input, {
  bool engine = false,
  bool interval = false,
}) {
  final values = input.toList()..sort();
  if (engine && values.isEmpty) {
    return {'count': 0, 'source': 'unavailable_no_samples'};
  }
  int? percentile(double p) => values.isEmpty
      ? null
      : values[engine
            ? ((values.length - 1) * p).ceil()
            : (values.length * p).ceil() - 1];
  return {
    'count': values.length,
    'p50Us': percentile(.5),
    'p95Us': percentile(.95),
    'p99Us': percentile(.99),
    'maxUs': values.isEmpty ? null : values.last,
    if (engine)
      interval ? 'atLeast12500Us' : 'over8333Us': values
          .where(
            (v) => interval
                ? v >= ReaderGates.missedIntervalUs
                : v > ReaderGates.stageBudgetUs,
          )
          .length,
  };
}

/// Symmetric comparison catches missing AND unexpected app-side aggregate keys.
List<String> differences(
  Object? actual,
  Object? expected, [
  String path = 'aggregates',
]) {
  if (actual is Map<String, Object?> && expected is Map<String, Object?>) {
    return [
      for (final key in {...actual.keys, ...expected.keys}.toList()..sort())
        if (!actual.containsKey(key) || !expected.containsKey(key))
          '$path.$key: missing in ${actual.containsKey(key) ? 'recomputed' : 'app'}'
        else
          ...differences(actual[key], expected[key], '$path.$key'),
    ];
  }
  if (actual == expected) return [];
  if (actual is num &&
      expected is num &&
      (actual - expected).abs() <= 1e-9 * (1 + expected.abs())) {
    return [];
  }
  return ['$path: app=$actual; recomputed=$expected'];
}

final class GateRow {
  const GateRow(
    this.name,
    this.value,
    this.threshold,
    this.status, [
    this.reason = '',
  ]);
  final String name, value, threshold, status, reason;
}
