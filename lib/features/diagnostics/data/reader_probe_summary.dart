/// Pure raw-sample reduction, shared with the offline analyzer in part 3.
abstract final class ReaderProbeSummary {
  static Map<String, Object?> distribution(Iterable<int> input) {
    final values = input.toList()..sort();
    int? percentile(double p) => values.isEmpty
        ? null
        : values[((values.length * p).ceil() - 1).clamp(0, values.length - 1)];
    return {
      'count': values.length,
      'p50Us': percentile(.50),
      'p95Us': percentile(.95),
      'p99Us': percentile(.99),
      'maxUs': values.isEmpty ? null : values.last,
    };
  }

  static Map<String, Object?> aggregate(
    List<Map<String, Object?>> events,
    List<Map<String, Object?>> costs,
    List<Map<String, Object?>> resources,
  ) {
    final counts = <String, int>{};
    final preparations = <int>[];
    final queueWait = <int>[];
    final submission = <int>[];
    final inputs = <(int?, int), _InputTiming>{};
    final sections = <int, int>{};
    final sectionCosts = <int>[];
    for (final event in events) {
      final kind = event['event'] as String;
      final time = event['monotonicUs'] as int;
      counts.update(kind, (v) => v + 1, ifAbsent: () => 1);
      final id = event['inputId'];
      // Legacy samples have no epoch; never merge them with an explicit one.
      final epoch = event['captureEpoch'] as int?;
      final input = id is int
          ? inputs.putIfAbsent((epoch, id), _InputTiming.new)
          : null;
      final section = event['section'];
      if (kind == 'sectionPreparationStart' && section is int) {
        sections[section] = time;
      }
      if (kind == 'sectionPreparationEnd' && section is int) {
        final start = sections.remove(section);
        if (start != null && event['cacheHit'] == false) {
          sectionCosts.add(time - start);
        }
      }
      if (input == null) continue;
      switch (kind) {
        case 'inputReceived':
          input.received = time;
        case 'queued':
          input.queued = true;
        case 'pointerAdmitted' || 'admitted':
          input.admitted ??= time;
        case 'preparationStart':
          input.preparationStart = time;
        case 'preparationMiss':
          input.warm = false;
        case 'prepared':
          if (input.preparationStart case final start?) {
            preparations.add(time - start);
          }
          input.preparationStart = null;
        case 'firstMotionSubmission':
          input.firstMotion ??= time;
      }
    }
    for (final input in inputs.values) {
      final received = input.received;
      final admitted = input.admitted;
      final first = input.firstMotion;
      if (received == null || admitted == null) continue;
      if (input.queued) queueWait.add(admitted - received);
      if (input.warm && !input.queued && first != null) {
        submission.add(first - received);
      }
    }
    final accepted = counts['accepted'] ?? 0;
    return {
      'eventCounts': counts,
      'paragraphLayout': distribution(costs.map((c) => c['layoutUs'] as int)),
      'preparation': distribution(preparations),
      'coldSectionPreparation': distribution(sectionCosts),
      'queueWait': distribution(queueWait),
      'warmInputToFirstSubmission': distribution(submission),
      'staticFallbacks': counts['staticFallback'] ?? 0,
      'acceptedTurns': accepted,
      'proofFailures': counts['proofFailed'] ?? 0,
      'staticFallbackRate': accepted == 0
          ? null
          : (counts['staticFallback'] ?? 0) / accepted,
      'resourceSnapshots': resources.length,
      'rssDeltaBytes': resources.length < 2
          ? null
          : (resources.last['rssBytes'] as int) -
                (resources.first['rssBytes'] as int),
      'stageBudgetUs': 8333,
    };
  }
}

final class _InputTiming {
  int? received, admitted, firstMotion, preparationStart;
  bool queued = false, warm = true;
}
