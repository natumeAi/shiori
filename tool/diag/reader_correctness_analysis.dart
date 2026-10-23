import 'reader_export_data.dart';

/// Replays explicit controller evidence; proofPassed alone is never a commit.
Json correctnessAnalysis(List<Json> events, Json metadata) {
  if (metadata['readerCorrectnessVersion'] != 1 ||
      metadata['captureEpoch'] is! int) {
    return {
      'available': false,
      'reason':
          'missing correctness capability or capture epoch (legacy export)',
    };
  }
  final inputs = <(int, int), _Evidence>{};
  var proofs = 0, rejections = 0, publications = 0, withoutCommit = 0;
  var missing = 0, unidentified = 0, unknownCommits = 0;
  for (final event in events) {
    final kind = event['event'];
    if (kind == 'proofFailed') proofs++;
    if (kind == 'staleCallbackRejected') rejections++;
    if (!{
      'inputCommitted',
      'accepted',
      'generationInvalidated',
      'staleCallbackRejected',
    }.contains(kind)) {
      continue;
    }
    final epoch = event['captureEpoch'], id = event['inputId'];
    if (epoch is! int || id is! int) {
      if (kind == 'inputCommitted' || kind == 'accepted') {
        missing++;
        unidentified++;
        if (kind == 'inputCommitted') unknownCommits++;
      }
      continue;
    }
    final input = inputs.putIfAbsent((epoch, id), _Evidence.new);
    final generation = event['generation'];
    final active = event['activeGeneration'];
    if (generation is! int || active is! int) {
      missing++;
    }
    switch (kind) {
      case 'inputCommitted':
        input.commits++;
      case 'generationInvalidated':
        input.invalidated = true;
      case 'staleCallbackRejected':
        if (generation is int && active is int && generation != active) {
          input.rejected.add(generation);
        }
      case 'accepted':
        if (input.commits == 0 && unknownCommits == 0) withoutCommit++;
        input.acceptances++;
        if ((generation is int && active is int && generation != active) ||
            input.invalidated ||
            input.rejected.contains(generation) ||
            epoch != metadata['captureEpoch']) {
          publications++;
        }
        final destination = event['destination'];
        if (destination is! Json ||
            destination['sectionIndex'] is! int ||
            destination['pageIndex'] is! int ||
            destination['layoutGeneration'] is! int ||
            destination['pageIdentity'] is! String ||
            !RegExp(r'^[0-9a-f]{64}$')
                .hasMatch(destination['pageIdentity'] as String)) {
          missing++;
        } else {
          input.destinations.add(destination);
        }
    }
  }
  final committed = inputs.values.where((i) => i.commits > 0).toList();
  final cardinality = committed
      .where(
        (i) =>
            i.commits != 1 ||
            i.acceptances > ReaderGates.destinationsPerCommit ||
            (unidentified == 0 && i.acceptances == 0),
      )
      .length;
  final failures = proofs + publications + withoutCommit + cardinality;
  return {
    'available': missing == 0 && committed.isNotEmpty,
    'reason': missing > 0
        ? 'missing correctness event fields: $missing'
        : committed.isEmpty
        ? 'no committed inputs'
        : 'explicit controller evidence',
    'proofFailures': proofs,
    'staleCallbackRejections': rejections,
    'staleCallbackPublications': publications,
    'acceptanceWithoutCommit': withoutCommit,
    'committedInputs': committed.length,
    'committedWithoutSingleAcceptance': cardinality,
    'failures': failures,
    'acceptedDestinationsPerInput': [
      for (final entry in inputs.entries)
        if (entry.value.commits > 0 || entry.value.acceptances > 0)
          {
            'captureEpoch': entry.key.$1,
            'inputId': entry.key.$2,
            'commits': entry.value.commits,
            'accepted': entry.value.acceptances,
            'destinations': entry.value.destinations,
          },
    ],
  };
}

final class _Evidence {
  int commits = 0, acceptances = 0;
  bool invalidated = false;
  final Set<int> rejected = {};
  final List<Json> destinations = [];
}
