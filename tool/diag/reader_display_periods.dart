import 'reader_export_data.dart';

/// Clip overlapping periods at the next recorded link start, without filling
/// holes after a target. Each commit belongs to at most one half-open period.
Json displayPeriodAnalysis(List<Json> links, List<double> commits) {
  var zero = 0, one = 0, many = 0, covered = 0, cursor = 0;
  final overlaps = <double>[], gaps = <double>[];
  for (var i = 0; i < links.length; i++) {
    final start = links[i]['start'] as double;
    var end = (links[i]['end'] as num).toDouble();
    if (i + 1 < links.length) {
      final next = links[i + 1]['start'] as double;
      final differenceUs = (end - next) * 1e6;
      if (differenceUs > 0) {
        overlaps.add(differenceUs);
        end = next;
      } else if (differenceUs < 0) {
        gaps.add(-differenceUs);
      }
    }
    while (cursor < commits.length && commits[cursor] < start) {
      cursor++;
    }
    var count = 0;
    while (cursor < commits.length && commits[cursor] < end) {
      count++;
      cursor++;
    }
    covered += count;
    if (count == 0) {
      zero++;
    } else if (count == 1) {
      one++;
    } else {
      many++;
    }
  }
  double maximum(List<double> values) =>
      values.fold(0, (a, b) => a > b ? a : b);
  return {
    'periods': links.length,
    'zero': zero,
    'one': one,
    'atLeastTwo': many,
    'outsideRecordedPeriods': commits.length - covered,
    'boundary': '[timestamp, min(targetTimestamp, next link timestamp)); last ends at target; holes are not filled; ties belong to next period',
    'anomalies': {
      'overlapCount': overlaps.length,
      'maximumOverlapUs': maximum(overlaps),
      'epsilonOverlapCount': overlaps.where((v) => v <= 1).length,
      'phaseOverlapCount': overlaps.where((v) => v > 1).length,
      'epsilonDefinition':
          '<=1 us (reporting category only; every overlap is retained)',
      'overlapUs': overlaps,
      'gapCount': gaps.length,
      'maximumGapUs': maximum(gaps),
    },
  };
}
