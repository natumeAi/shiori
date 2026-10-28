import 'dart:convert';

import 'reader_export_analysis.dart';
import 'reader_export_data.dart';

String _cell(Object? value) => (value == null ? 'unavailable' : '$value')
    .replaceAll('|', '&#124;')
    .replaceAll(String.fromCharCode(10), ' ');

void _table(StringBuffer out, List<String> headers, List<List<Object?>> rows) {
  out.writeln('| ${headers.join(' | ')} |');
  out.writeln('| ${headers.map((_) => '---').join(' | ')} |');
  for (final row in rows) {
    out.writeln('| ${row.map(_cell).join(' | ')} |');
  }
  out.writeln();
}

String renderReaderReport(List<ReaderExportAnalysis> runs) {
  final out = StringBuffer()
    ..writeln('# Reader feasibility export analysis')
    ..writeln();
  out.writeln(
    'Independent raw-sample recomputation. Engine frame-number matches '
    'are engine identity only. Native seconds stay separate from Dart time. '
    'These tables do not establish physical presentation or touch-to-photon latency.',
  );
  out.writeln();
  for (final run in runs) {
    out.writeln(
      '## ${run.scenario} / repeat ${run.repeat} of ${run.repeatCount}',
    );
    out.writeln();
    out.writeln(
      'Fixture: ${_cell(run.raw['fixtureId'])}; book digest: ${_cell(run.raw['bookSha256'])}; '
      'input: ${_cell(run.raw['input'])}; native mode: ${run.native['mode']}.',
    );
    out.writeln();
    _table(
      out,
      ['Gate', 'Observed', 'Threshold', 'Result', 'Reason'],
      [
        for (final gate in run.gates)
          [gate.name, gate.value, gate.threshold, gate.status, gate.reason],
      ],
    );
    final distributions = <String, Object?>{
      for (final name in ['ui', 'raster', 'vsyncIntervals'])
        name: run.engine.aggregates[name],
      for (final name in [
        'paragraphLayout',
        'preparation',
        'coldSectionPreparation',
        'queueWait',
      ])
        name: run.readerAggregates[name],
      'warm receipt to first submission (informational; legacy App aggregate)':
          run.readerAggregates['warmInputToFirstSubmission'],
      'recognized admission to first submission': run.demand.latency,
      'stall engine intervals': run.stalls['engineIntervals'],
      'stall submission gaps': run.stalls['submissionGaps'],
      'coldInputPreparation': run.inputs.coldInputPreparation,
    };
    _table(
      out,
      ['Distribution (us)', 'count', 'P50', 'P95', 'P99', 'max', 'exceedance'],
      [
        for (final entry in distributions.entries)
          [
            entry.key,
            ...[
              'count',
              'p50Us',
              'p95Us',
              'p99Us',
              'maxUs',
            ].map((k) => object(entry.value, entry.key)[k]),
            _exceedance(object(entry.value, entry.key)),
          ],
      ],
    );
    _table(
      out,
      ['Counter / evidence', 'Value'],
      [
        ['correlatedMotionFrames', run.engine.active.length],
        [
          'unavailable negative/missing frame numbers',
          run.engine.unavailableFrameNumbers,
        ],
        ['engine cadence pattern', run.engine.aggregates['cadencePattern']],
        [
          'capture declarations',
          jsonEncode(object(run.raw['engine'], 'engine')['declarations']),
        ],
        ['eventCounts', jsonEncode(run.inputs.counts)],
        for (final key in [
          'staticFallbacks',
          'acceptedTurns',
          'staticFallbackRate',
          'resourceSnapshots',
          'rssDeltaBytes',
        ])
          [key, run.readerAggregates[key]],
        ['demand timeline', jsonEncode(run.demand.report)],
        ['correctness', jsonEncode(run.correctness)],
        ['longStageFrames >=50 ms', run.stalls['longStageFrames']],
        ['stall classes', jsonEncode(run.stalls['classes'])],
        [
          'stall candidates (all retained)',
          jsonEncode(run.stalls['candidates']),
        ],
        ['incompleteWarmInputs', run.inputs.incompleteWarmInputs],
        ['omissions (verbatim fields)', jsonEncode(run.omissions)],
        ['overflow (retained samples only)', jsonEncode(run.overflow)],
        [
          'engine errors',
          jsonEncode(object(run.raw['engine'], 'engine')['errors']),
        ],
        [
          'incomplete trailing batch',
          object(run.raw['engine'], 'engine')['incompleteTrailingBatch'],
        ],
      ],
    );
    _table(
      out,
      ['Resource', 'first', 'last', 'max', 'OLS slope / second', 'Reason'],
      [
        for (final entry in run.resources.entries)
          [
            entry.key,
            ...[
              'first',
              'last',
              'max',
              'slopePerSecond',
              'reason',
            ].map((k) => object(entry.value, entry.key)[k]),
          ],
      ],
    );
    out.writeln(
      'Native mode ${run.native['mode']}: ${run.native['evidence']}. '
      'Not establishing physical presentation or touch-to-photon latency.',
    );
    out.writeln();
    _table(
      out,
      ['Native metric', 'Value'],
      [
        for (final key in [
          'available',
          'omission',
          'overflow',
          'contentionDrops',
          'unmatchedCallbacks',
          'inventory',
          'commitIntervals',
          'commitsPerDisplayPeriod',
          'presented',
          'notPresentedByStop',
          'presentationIntervals',
          'drawableGapClasses',
          'interpretation',
        ])
          if (run.native.containsKey(key)) [key, jsonEncode(run.native[key])],
      ],
    );
    out.writeln(
      'App aggregate comparison: ${run.mismatches.isEmpty ? 'MATCH (reader and engine)' : 'MISMATCH'}.',
    );
    out.writeln();
    for (final mismatch in run.mismatches) {
      out.writeln('- ${_cell(mismatch)}');
    }
    out.writeln();
  }
  out.writeln('## Summary across repeats');
  out.writeln();
  out.writeln(
    'Repeats are never pooled across book, fixture, input or native mode. '
    'Counts summarize gate rows; no averaged percentile replaces a failed repeat.',
  );
  out.writeln();
  final groups = <String, List<ReaderExportAnalysis>>{};
  for (final run in runs) {
    final key = jsonEncode([
      run.scenario,
      run.raw['bookSha256'],
      run.raw['fixtureId'],
      run.raw['input'],
      run.native['mode'],
    ]);
    groups.putIfAbsent(key, () => []).add(run);
  }
  _table(
    out,
    [
      'Scenario / fixture / mode',
      'Repeats',
      'pass rows',
      'fail rows',
      'unavailable rows',
      'Repeat coverage',
      'App mismatches',
    ],
    [for (final group in groups.values) _summary(group)],
  );
  return out.toString();
}

String _exceedance(Json d) {
  if (d.containsKey('over8333Us')) return 'over8333Us=${d['over8333Us']}';
  if (d.containsKey('atLeast12500Us')) {
    return 'atLeast12500Us=${d['atLeast12500Us']}';
  }
  return d['source'] as String? ?? 'reported separately';
}

List<Object?> _summary(List<ReaderExportAnalysis> runs) {
  final first = runs.first;
  final indices = runs.map((r) => r.repeat).toSet().toList()..sort();
  final required = first.scenario == 'R11' ? 1 : ReaderGates.minimumRepeats;
  final complete =
      indices.length == runs.length &&
      indices.length >= required &&
      runs.every((r) => r.repeatCount == first.repeatCount) &&
      indices.length == first.repeatCount &&
      indices.first == 1 &&
      indices.last == first.repeatCount;
  return [
    '${first.scenario} / ${first.raw['fixtureId']} / ${first.native['mode']}',
    indices.join(', '),
    for (final status in ['pass', 'fail', 'unavailable'])
      runs.expand((r) => r.gates).where((g) => g.status == status).length,
    complete
        ? 'pass: $required required repeats present'
        : 'unavailable: missing, duplicate or inconsistent repeats (need >=$required)',
    runs.fold<int>(0, (n, r) => n + r.mismatches.length),
  ];
}
