import 'reader_export_data.dart';

/// Definite breaches fail even on partial exports. Absence needs all evidence.
GateRow resourceGate(
  Json trends,
  List<Json> samples,
  Json metadata,
  int turns, {
  required bool overflow,
}) {
  const name = 'resource trend >=100 turns';
  const threshold = '>=100 turns; maxima <=caps; RSS endpoint/OLS growth <=5%';
  final raw = metadata['resourceCaps'];
  if (raw is! Json ||
      [
        'liveSurfaceCap',
        'liveSurfaceReserve',
        'pictureCacheBytes',
        'imageCacheBytes',
      ].any((k) => raw[k] is! int || (raw[k] as int) < 0)) {
    return const GateRow(
      name,
      'unverified',
      threshold,
      'unavailable',
      'missing declared resource caps (legacy export)',
    );
  }
  final caps = {
    'liveSurfaces':
        (raw['liveSurfaceCap'] as int) + (raw['liveSurfaceReserve'] as int),
    'pictureBytes': raw['pictureCacheBytes'] as int,
    'imageBytes': raw['imageCacheBytes'] as int,
  };
  final breaches = <String>[];
  var missing = false;
  for (final entry in caps.entries) {
    final max = object(trends[entry.key], entry.key)['max'];
    if (max is! num) {
      missing = true;
    } else if (max > entry.value) {
      breaches.add('${entry.key} max=$max > cap=${entry.value}');
    }
  }
  final rss = object(trends['rssBytes'], 'rssBytes');
  final first = rss['first'], last = rss['last'], slope = rss['slopePerSecond'];
  final times =
      samples.map((s) => integer(s['monotonicUs'], 'resource time')).toList()
        ..sort();
  if (first is! num ||
      first <= 0 ||
      last is! num ||
      slope is! num ||
      times.length < 2 ||
      times.last <= times.first) {
    missing = true;
  } else {
    final duration = (times.last - times.first) / 1e6;
    final allowed = first * ReaderGates.maximumRssGrowthFraction;
    if (last - first > allowed || slope * duration > allowed) {
      breaches.add(
        'RSS endpoint or projected OLS growth exceeds '
        '${ReaderGates.maximumRssGrowthFraction * 100}% of first RSS',
      );
    }
  }
  return GateRow(
    name,
    '$turns accepted turns',
    threshold,
    breaches.isNotEmpty
        ? 'fail'
        : missing || overflow || turns < ReaderGates.minimumResourceTurns
        ? 'unavailable'
        : 'pass',
    breaches.isNotEmpty
        ? 'unbounded: ${breaches.join('; ')}'
        : missing
        ? 'missing resource samples or distinct sample times'
        : overflow
        ? 'resource/event overflow: retained samples only'
        : turns < ReaderGates.minimumResourceTurns
        ? 'fewer than 100 accepted turns'
        : 'bounded over observed capture; caps=$caps; RSS rule: '
              'maximumRssGrowthFraction; scenario establishes alternating-turn coverage',
  );
}
