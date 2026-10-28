import 'dart:math' as math;

/// Same-definition gates; callers retain the old measurements as diagnostics.
Map<String, Object?> compareSpikeGeometry(
  String row,
  List<Map<String, Object?>> fragments,
  Map<String, Object?> reference, {
  required bool nested,
  required Map<String, Object?> componentDiagnostics,
}) {
  final channels = <Map<String, Object?>>[];
  void add(String channel, Map<String, Object?> detail, double delta) {
    channels.add({
      'channel': channel,
      ...detail,
      'maximumCssPxDelta': delta,
      'pass': delta <= .5,
    });
  }

  if (row == 'svg-text') {
    for (final run
        in (reference['svgTexts'] as List).cast<Map<String, Object?>>()) {
      final declaration = (run['fixtureRun'] ?? run) as Map<String, Object?>;
      final clusters = (declaration['clusterMap'] as List).cast<List>();
      final native = fragments
          .where((f) => f['textRun'] == run['text'])
          .toList();
      final expected = (run['characters'] as List).cast<Map<String, Object?>>();
      for (final cluster in clusters) {
        final start = cluster[0] as int, end = cluster[1] as int;
        final first = native.firstWhere((f) => f['svgIndex'] == start);
        final last = native.firstWhere((f) => f['svgIndex'] == end - 1);
        final detail = <String, Object?>{
          'text': run['text'],
          'utf16': [start, end],
          'clusterSource': declaration['clusterSource'] ?? 'fixture-declared',
          'coordinateSpace': 'svg-user-space-before-outer-7-9-transform',
        };
        add('cluster-start', {
          ...detail,
          'native': first['start'],
          'reference': expected[start]['start'],
        }, _distance(first['start'], expected[start]['start']));
        add('cluster-end', {
          ...detail,
          'native': last['end'],
          'reference': expected[end - 1]['end'],
        }, _distance(last['end'], expected[end - 1]['end']));
        final advance = _distance(
          expected[start]['start'],
          expected[end - 1]['end'],
        );
        // Both painted boundary slices must respect the cluster rotation.
        // Raw angles are preserved; only induced displacement is gated.
        for (final pair in [
          (first, expected[start]),
          (last, expected[end - 1]),
        ]) {
          final angle =
              ((pair.$1['rotation'] as num) - (pair.$2['rotation'] as num))
                  .abs()
                  .toDouble();
          add('cluster-rotation-displacement', {
            ...detail,
            'svgIndex': pair.$1['svgIndex'],
            'angleDeltaDegrees': angle,
            'clusterAdvanceCssPx': advance,
          }, angle * math.pi / 180 * advance);
        }
      }
    }
  } else if (row == 'foreign-object' && reference['texts'] != null) {
    for (final node
        in (reference['texts'] as List).cast<Map<String, Object?>>()) {
      final native = fragments
          .where((f) => f['sourceText'] == node['text'])
          .toList();
      final baseline = node['baseline'] as Map<String, Object?>;
      final run = node['fixtureRun'] as Map<String, Object?>;
      final prefix =
          (node['advance'] as Map<String, Object?>)['prefixWidths'] as List;
      final boundaries = <int>{
        for (final c in run['clusterMap'] as List) ...[
          c[0] as int,
          c[1] as int,
        ],
      }.toList()..sort();
      for (final f in native) {
        final y = (f['baseline'] as num).toDouble() + (nested ? 9 : 0);
        add('baseline-y', {
          'node': f['node'],
          'utf16': f['utf16Start'],
          'native': y,
          'reference': baseline['y'],
        }, (y - (baseline['y'] as num)).abs());
      }
      final positions = native.first['boundaryPositions'] as List;
      for (final boundary in boundaries) {
        final x = (positions[boundary] as num).toDouble() + (nested ? 7 : 0);
        final expectedX = (baseline['x'] as num) + (prefix[boundary] as num);
        add('cluster-boundary-x', {
          'node': native.first['node'],
          'utf16': boundary,
          'native': x,
          'reference': expectedX,
          'coordinateSpace': 'viewport-css-px',
        }, (x - expectedX).abs());
      }
    }
  }
  return {
    'comparisons': channels.length,
    'maximumCssPxDelta': channels.isEmpty
        ? null
        : channels
              .map((c) => c['maximumCssPxDelta'] as double)
              .reduce(math.max),
    'channels': channels,
    'provisional': row == 'svg-text',
    if (row == 'svg-text')
      'clusterConfirmation': 'A0b must confirm shaped membership',
    'componentDiagnostics': componentDiagnostics,
  };
}

double _distance(Object? a, Object? b) {
  final aa = (a as List).cast<num>(), bb = (b as List).cast<num>();
  return math.sqrt(math.pow(aa[0] - bb[0], 2) + math.pow(aa[1] - bb[1], 2));
}
