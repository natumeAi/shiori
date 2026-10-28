// A0b-only alternative report. Shared A2 geometry/D4 helpers stay unchanged.
import 'dart:math' as math;

import 'harfbuzz_probe_scene.dart';

Map<String, Object?> probeGateB(
  HbScene scene,
  List<Map<String, Object?>> refs,
  Map<String, Object?> current,
) {
  final channels = (current['channels'] as List)
      .cast<Map<String, Object?>>()
      .where((c) {
        final range = c['utf16'] as List;
        return c['channel'] == 'cluster-start' ||
            (c['channel'] == 'cluster-rotation-displacement' &&
                (range[1] as int) - (range[0] as int) == 1);
      })
      .toList();
  for (final ref in refs) {
    final run = scene.runs.singleWhere((r) => r.text == ref['text']);
    final index = scene.runs.indexOf(run);
    final advance =
        scene.clusters.firstWhere((c) => c['runIndex'] == index)['runAdvance']
            as num;
    final expected = ref['computedTextLength'] as num;
    final delta = (advance - expected).abs();
    channels.add({
      'channel': 'run-total-advance',
      'text': run.text,
      'native': advance,
      'reference': expected,
      'maximumCssPxDelta': delta,
      'pass': delta <= .5,
    });
  }
  final maximum = channels
      .map((c) => (c['maximumCssPxDelta'] as num).toDouble())
      .reduce(math.max);
  return {
    'definition':
        'starts; computedTextLength; single-component rotation; unchanged D4',
    'comparisons': channels.length,
    'maximumCssPxDelta': maximum,
    'channels': channels,
    'pass': maximum <= .5,
    'diagnostics': (current['channels'] as List)
        .where((c) => !channels.contains(c))
        .toList(),
  };
}
