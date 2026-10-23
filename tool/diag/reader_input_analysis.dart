import 'reader_export_data.dart';

/// Input IDs are opaque and scoped to ONE export/capture epoch. Generation is
/// deliberately not a join key: dragging and release can change it for one ID.
final class InputAnalysis {
  InputAnalysis(List<Json> events, List<Json> costs, List<Json> resources) {
    final inputs = <(int?, int), _Input>{};
    final sections = <int, int>{};
    final sectionCosts = <int>[], preparation = <int>[];
    final waits = <int>[], warm = <int>[];
    for (final event in events) {
      final kind = string(event['event'], 'readerEvents.event');
      final time = integer(event['monotonicUs'], 'readerEvents.monotonicUs');
      counts.update(kind, (v) => v + 1, ifAbsent: () => 1);
      final section = event['section'];
      if (section is int && kind == 'sectionPreparationStart') {
        sections[section] = time;
      }
      if (section is int && kind == 'sectionPreparationEnd') {
        final start = sections.remove(section);
        if (start != null && event['cacheHit'] == false) {
          sectionCosts.add(time - start);
        }
      }
      final id = event['inputId'];
      if (id is! int) {
        if (kind == 'accepted' || kind == 'proofPassed') {
          unidentifiedOutcomes++;
        }
        continue;
      }
      final rawEpoch = event['captureEpoch'];
      final epoch = rawEpoch == null
          ? null
          : integer(rawEpoch, 'readerEvents.captureEpoch');
      final input = inputs.putIfAbsent((epoch, id), _Input.new);
      switch (kind) {
        case 'inputReceived':
          input.received = time;
        case 'queued':
          input.queued = true;
        case 'admitted' || 'pointerAdmitted':
          input.admitted ??= time;
        case 'preparationStart':
          input.preparing = time;
        case 'preparationMiss':
          input.warm = false;
        case 'prepared':
          if (input.preparing case final start?) {
            preparation.add(time - start);
            if (!input.warm) coldInputCosts.add(time - start);
          }
          input.preparing = null;
        case 'firstMotionSubmission':
          input.first ??= time;
          input.windowStart ??= time;
        case 'settleEnd':
          if (input.windowStart case final start? when time >= start) {
            windows.add({
              'captureEpoch': epoch,
              'inputId': id,
              'startUs': start,
              'endUs': time,
            });
          }
          input.windowStart = null;
        case 'proofPassed':
          input.proofs++;
        case 'accepted':
          input.accepted++;
      }
    }
    for (final entry in inputs.entries) {
      final input = entry.value;
      if (input.windowStart != null) {
        openWindows++;
      }
      final received = input.received,
          admitted = input.admitted,
          first = input.first;
      if (input.warm &&
          !input.queued &&
          admitted != null &&
          (received == null || first == null)) {
        incompleteWarmInputs++;
      }
      if (received != null && admitted != null) {
        if (input.queued) {
          waits.add(admitted - received);
        }
        if (input.warm && !input.queued && first != null) {
          warm.add(first - received);
        }
      }
      if (input.accepted > 0 || input.proofs > 0) {
        destinations.add({
          'captureEpoch': entry.key.$1,
          'inputId': entry.key.$2,
          'proofPassed': input.proofs,
          'accepted': input.accepted,
        });
      }
    }
    final accepted = counts['accepted'] ?? 0;
    appAggregates = {
      'eventCounts': counts,
      'paragraphLayout': distribution(
        costs.map((c) => integer(c['layoutUs'], 'layoutCosts.layoutUs')),
      ),
      'preparation': distribution(preparation),
      'coldSectionPreparation': distribution(sectionCosts),
      'queueWait': distribution(waits),
      'warmInputToFirstSubmission': distribution(warm),
      'staticFallbacks': counts['staticFallback'] ?? 0,
      'acceptedTurns': accepted,
      'proofFailures': counts['proofFailed'] ?? 0,
      'staticFallbackRate': accepted == 0
          ? null
          : (counts['staticFallback'] ?? 0) / accepted,
      'resourceSnapshots': resources.length,
      'rssDeltaBytes': resources.length < 2
          ? null
          : integer(resources.last['rssBytes'], 'resources.rssBytes') -
                integer(resources.first['rssBytes'], 'resources.rssBytes'),
      'stageBudgetUs': ReaderGates.stageBudgetUs,
    };
  }

  late final Json appAggregates;
  final counts = <String, int>{};
  final windows = <Json>[];
  final destinations = <Json>[];
  final coldInputCosts = <int>[];
  Json get coldInputPreparation => distribution(coldInputCosts);
  int openWindows = 0, unidentifiedOutcomes = 0, incompleteWarmInputs = 0;
}

final class _Input {
  int? received, admitted, first, preparing, windowStart;
  int accepted = 0, proofs = 0;
  bool warm = true, queued = false;
}
