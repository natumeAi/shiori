import 'reader_export_data.dart';

Json resourceTrends(List<Json> samples) {
  final ordered = samples.toList()
    ..sort(
      (a, b) => integer(
        a['monotonicUs'],
        'resource time',
      ).compareTo(integer(b['monotonicUs'], 'resource time')),
    );
  return {
    for (final field in [
      'liveSurfaces',
      'pictureBytes',
      'imageBytes',
      'rssBytes',
    ])
      field: _trend(ordered, field),
  };
}

Json _trend(List<Json> samples, String field) {
  if (samples.isEmpty || samples.any((s) => s[field] is! num)) {
    return {
      'count': samples.length,
      'reason': 'unavailable: missing $field samples',
    };
  }
  final start = integer(samples.first['monotonicUs'], 'resource time');
  final x = samples
      .map((s) => (integer(s['monotonicUs'], 'resource time') - start) / 1e6)
      .toList();
  final y = samples.map((s) => number(s[field], field)).toList();
  final meanX = x.reduce((a, b) => a + b) / x.length;
  final meanY = y.reduce((a, b) => a + b) / y.length;
  double numerator = 0, denominator = 0;
  for (var i = 0; i < x.length; i++) {
    numerator += (x[i] - meanX) * (y[i] - meanY);
    denominator += (x[i] - meanX) * (x[i] - meanX);
  }
  return {
    'count': y.length,
    'first': y.first,
    'last': y.last,
    'max': y.reduce((a, b) => a > b ? a : b),
    'slopePerSecond': denominator == 0 ? null : numerator / denominator,
    'slopeMethod': 'ordinary least squares over recorder monotonic seconds',
    if (denominator == 0)
      'reason': 'unavailable slope: fewer than two distinct sample times',
  };
}

Json nativeAnalysis(Json presentation) {
  const evidence = {
    'inventory': 'metadata',
    'a1': 'layer_commit_cadence',
    'a2': 'layer_commit_cadence_per_display_period',
    'b': 'system_drawable_presentation_non_product_path',
  };
  final mode = string(presentation['mode'], 'presentation.mode');
  final available = presentation['available'];
  if (!evidence.containsKey(mode) ||
      available is! bool ||
      (presentation['evidence'] != evidence[mode] &&
          !(available == false && presentation['evidence'] == 'unverified'))) {
    throw const FormatException(
      'Invalid presentation mode/evidence/availability',
    );
  }
  final overflow = integer(presentation['overflow'], 'presentation.overflow');
  final contention = integer(
    presentation['contentionDrops'],
    'presentation.contentionDrops',
  );
  final unmatched = integer(
    presentation['unmatchedCallbacks'] ?? 0,
    'presentation.unmatchedCallbacks',
  );
  if (unmatched < 0) {
    throw const FormatException('Invalid native unmatched callback count');
  }
  if (overflow < 0 || contention < 0 || contention > overflow) {
    throw const FormatException('Invalid native overflow/contention subset');
  }
  if (!available && presentation['omission'] is! String) {
    throw const FormatException(
      'Unavailable native mode requires an omission reason',
    );
  }
  final samples = objects(presentation['samples'], 'presentation.samples');
  final commits = <double>[], presented = <double>[];
  final links = <Json>[];
  var unpresented = 0;
  for (final sample in samples) {
    final timestamp = number(
      sample['timestamp'],
      'presentation.timestamp',
    ).toDouble();
    if (timestamp < 0) throw const FormatException('negative native timestamp');
    switch (sample['kind']) {
      case 'layer_commit':
        if (mode != 'a1' && mode != 'a2') {
          throw const FormatException('layer_commit requires A1/A2');
        }
        commits.add(timestamp);
      case 'display_link':
        if (mode != 'a2') {
          throw const FormatException('display_link requires A2');
        }
        final target = number(sample['targetTimestamp'], 'targetTimestamp');
        if (target <= timestamp) {
          throw const FormatException('display-link period must be positive');
        }
        links.add({'start': timestamp, 'end': target});
      case 'drawable':
        if (mode != 'b') throw const FormatException('drawable requires B');
        final time = number(
          sample['presentedTime'],
          'presentedTime',
        ).toDouble();
        if (time < 0) throw const FormatException('negative presentedTime');
        if (time == 0) {
          unpresented++;
        } else {
          presented.add(time);
        }
      default:
        throw FormatException(
          'Unknown presentation sample kind: ${sample['kind']}',
        );
    }
  }
  commits.sort();
  presented.sort();
  if (available &&
      ((mode == 'a1' && commits.isEmpty) ||
          (mode == 'a2' && (commits.isEmpty || links.isEmpty)) ||
          (mode == 'b' && presented.isEmpty && unpresented == 0))) {
    throw const FormatException(
      'Available native mode has no required raw stream',
    );
  }
  links.sort((a, b) => (a['start'] as num).compareTo(b['start'] as num));
  var zero = 0, one = 0, many = 0, outside = 0;
  for (var i = 0; i < links.length; i++) {
    final link = links[i];
    if (i > 0 && (link['start'] as num) < (links[i - 1]['end'] as num)) {
      throw const FormatException('Overlapping display-link periods');
    }
    final count = commits
        .where((t) => t >= (link['start'] as num) && t < (link['end'] as num))
        .length;
    if (count == 0) {
      zero++;
    } else if (count == 1) {
      one++;
    } else {
      many++;
    }
  }
  outside = commits
      .where(
        (t) => !links.any(
          (l) => t >= (l['start'] as num) && t < (l['end'] as num),
        ),
      )
      .length;
  List<int> deltas(List<double> times) => [
    for (var i = 1; i < times.length; i++)
      ((times[i] - times[i - 1]) * 1e6).round(),
  ];
  return {
    'mode': presentation['mode'],
    'evidence': presentation['evidence'],
    'available': presentation['available'],
    'omission': presentation['omission'],
    'overflow': presentation['overflow'],
    'contentionDrops': presentation['contentionDrops'],
    'unmatchedCallbacks': unmatched,
    'inventory': presentation['inventory'],
    if (mode == 'a1' || mode == 'a2')
      'commitIntervals': distribution(
        deltas(commits),
        engine: true,
        interval: true,
      ),
    if (mode == 'a2')
      'commitsPerDisplayPeriod': {
        'periods': links.length,
        'zero': zero,
        'one': one,
        'atLeastTwo': many,
        'outsideRecordedPeriods': outside,
        'boundary':
            '[timestamp, targetTimestamp); missing periods are not invented',
      },
    if (mode == 'b') 'presented': presented.length,
    if (mode == 'b') 'notPresentedByStop': unpresented,
    if (mode == 'b')
      'presentationIntervals': distribution(
        deltas(presented),
        engine: true,
        interval: true,
      ),
    'interpretation': 'native clock only; no Dart correlation; does not establish physical presentation or touch-to-photon latency; B is a non-product path; zero may include pending/lost callbacks',
  };
}
