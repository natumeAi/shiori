import 'dart:convert';

import 'package:shiori/core/diagnostics/diagnostic_summary.dart';
import 'package:shiori/core/diagnostics/frame_sample.dart';
import 'package:shiori/features/diagnostics/data/reader_feasibility_record.dart';
import 'package:shiori/features/diagnostics/data/reader_probe_summary.dart';

import 'reader_analyzer_exports.dart';

/// Synthetic-only extensions to the documented production-encoder generator.
/// Expected aggregates use App reducers, never the independent analyzer.
Map<String, ExportJson> readerDeviceAnalysisExports() {
  final base = readerAnalyzerExports();
  final result = <String, ExportJson>{};
  ExportJson copy(String name) =>
      jsonDecode(jsonEncode(base[name])) as ExportJson;
  List<ExportJson> rows(Object? value) => (value as List).cast<ExportJson>();
  void save(String name, ExportJson raw) {
    raw['aggregates'] = ReaderProbeSummary.aggregate(
      rows(raw['readerEvents']),
      rows(raw['layoutCosts']),
      rows(raw['resources']),
    );
    final engine = raw['engine'] as ExportJson;
    engine['aggregates'] = DiagnosticSummary.aggregate(
      rows(engine['frames']).map(FrameSample.fromJson).toList(),
      rows(engine['motion']).map((m) => m['frameNumber'] as int).toSet(),
    );
    result[name] = jsonDecode(
      jsonEncode(ReaderFeasibilityRecord.fromJson(raw).toJson()),
    ) as ExportJson;
  }

  final latency = copy('passing-120hz-a1-1.json');
  final events = rows(latency['readerEvents']);
  events.firstWhere(
    (e) => e['event'] == 'admitted' && e['inputId'] == 2,
  )['monotonicUs'] = 7130000;
  events.sort(
    (a, b) => (a['monotonicUs'] as int).compareTo(b['monotonicUs'] as int),
  );
  save('latency-release-after-motion.json', latency);

  final stalled = copy('stall-b.json')..['scenarioId'] = 'R03';
  save('stall-script-intent-unresolved.json', stalled);

  final stage = copy('passing-120hz-a1-1.json');
  final frame = rows((stage['engine'] as ExportJson)['frames']).first;
  frame['buildFinishUs'] = (frame['buildStartUs'] as int) + 50000;
  save('stall-long-stage.json', stage);

  final display = copy('failing-budgets-a2.json');
  final samples = rows((display['presentation'] as ExportJson)['samples']);
  final links = samples.where((s) => s['kind'] == 'display_link').toList();
  links[1]['timestamp'] = 10.008;
  links[2]['timestamp'] = 10.0199999;
  save('display-phase-and-epsilon.json', display);

  final cancelled = copy('passing-120hz-a1-1.json')..['scenarioId'] = 'R04';
  cancelled['readerEvents'] = [
    for (final e in rows(cancelled['readerEvents']))
      if (e['inputId'] == 1 &&
          {
            'inputReceived',
            'pointerAdmitted',
            'firstMotionSubmission',
          }.contains(e['event']))
        e,
    for (var id = 2; id <= 16; id++)
      <String, Object?>{
        'event': id <= 9 ? 'queued' : 'overflow',
        'monotonicUs': 7020000 + id,
        'inputId': id,
        'captureEpoch': 1,
        'generation': 1,
        'activeGeneration': 1,
      },
    <String, Object?>{
      'event': 'generationInvalidated',
      'monotonicUs': 7050000,
      'inputId': 1,
      'captureEpoch': 1,
      'generation': 3,
      'activeGeneration': 3,
    },
  ];
  save('queue-cancelled-open-window.json', cancelled);

  final rss = copy('resources-100-turns-bounded.json');
  rows(rss['resources']).last['rssBytes'] = 11000;
  save('rss-cold-growth.json', rss);

  final drawable = copy('stall-b.json');
  (drawable['presentation'] as ExportJson)['samples'] = [
    for (final (index, times) in [
      (10.0, 10.016),
      (10.008, 10.032),
      (10.032, 10.048),
      (10.034, 0.0),
      (10.060, 0.0),
    ].indexed)
      <String, Object?>{
        'kind': 'drawable',
        'timestamp': times.$1,
        'presentedTime': times.$2,
        'drawableId': '$index',
      },
  ];
  save('drawable-gap-classes.json', drawable);
  return result;
}
