import 'reader_export_data.dart';

/// Acquisition and presentation use the native clock only. A pipeline can have
/// pending drawables acquired before the preceding presentation, so absence of
/// acquisitions inside a presentation gap alone does not prove engine idle.
Json drawableGapAnalysis(List<Json> drawables, {required bool loss}) {
  final presented =
      drawables.where((d) => (d['presentedTime'] as num) > 0).toList()..sort(
        (a, b) =>
            (a['presentedTime'] as num).compareTo(b['presentedTime'] as num),
      );
  int bound(double value, {bool after = false}) {
    var low = 0, high = drawables.length;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      final time = drawables[middle]['timestamp'] as num;
      if (time < value || (after && time == value)) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low;
  }

  final gaps = <Json>[];
  var without = 0, withAcquisition = 0, timely = 0, acquisitionGaps = 0;
  var reordered = 0;
  for (var i = 1; i < presented.length; i++) {
    final a = presented[i - 1], b = presented[i];
    final start = (a['presentedTime'] as num).toDouble();
    final end = (b['presentedTime'] as num).toDouble();
    final interval = ((end - start) * 1e6).round();
    if (interval < ReaderGates.missedIntervalUs) continue;
    final count = bound(end) - bound(start, after: true);
    if (count == 0) {
      without++;
    } else {
      withAcquisition++;
    }
    final delta = (((b['timestamp'] as num) - (a['timestamp'] as num)) * 1e6)
        .round();
    final classification = delta < 0
        ? 'reorderedAcquisitions'
        : delta < ReaderGates.missedIntervalUs
        ? 'timelyAcquisitionPresentationGap'
        : 'acquisitionGap';
    if (delta < 0) {
      reordered++;
    } else if (delta < ReaderGates.missedIntervalUs) {
      timely++;
    } else {
      acquisitionGaps++;
    }
    gaps.add({
      'startNativeSeconds': start,
      'endNativeSeconds': end,
      'intervalUs': interval,
      'acquisitionsStrictlyBetween': count,
      'endpointAcquisitionDeltaUs': delta,
      'class': classification,
    });
  }
  final zero = drawables.where((d) => d['presentedTime'] == 0).toList();
  final lastPresentation = presented.isEmpty
      ? null
      : presented.last['presentedTime'] as num;
  return {
    'thresholdUs': ReaderGates.missedIntervalUs,
    'intervalsAtLeastThreshold': gaps.length,
    'noAcquisitionBetweenPresentations': without,
    'withAcquisitionBetweenPresentations': withAcquisition,
    'timelyAcquisitionPresentationGap': timely,
    'acquisitionGap': acquisitionGaps,
    'reorderedAcquisitions': reordered,
    'notObservedPresentedByStop': zero.length,
    'unpresentedAcquiredBeforeLastPresentation': lastPresentation == null
        ? 0
        : zero.where((d) => (d['timestamp'] as num) < lastPresentation).length,
    'nativeLossQualifiesAbsence': loss,
    'unpresentedAcquiredAtLeastThresholdBeforeLastAcquisition':
        drawables.isEmpty
        ? 0
        : zero
              .where(
                (d) =>
                    (((drawables.last['timestamp'] as num) -
                                (d['timestamp'] as num)) *
                            1e6)
                        .round() >=
                    ReaderGates.missedIntervalUs,
              )
              .length,
    'acquisitionToPresentation': distribution(
      presented.map(
        (d) => (((d['presentedTime'] as num) - (d['timestamp'] as num)) * 1e6)
            .round(),
      ),
      engine: true,
    ),
    'gaps': gaps,
    'interpretation': 'timely means consecutive presented drawables acquired <12500 us apart; presentation pacing gap, not a deadline or scan-out proof. Other gaps include slower acquisition, not proven idle. No interior acquisition alone cannot prove idle with pending drawables or loss. Zero presentation may be pending/lost callback, not a proven miss.',
  };
}
