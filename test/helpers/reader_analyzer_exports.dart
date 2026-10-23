import 'dart:convert';

import 'package:shiori/core/diagnostics/diagnostic_summary.dart';
import 'package:shiori/core/diagnostics/motion_sample.dart';
import 'package:shiori/features/diagnostics/data/presentation_payload.dart';
import 'package:shiori/features/diagnostics/data/presentation_probe.dart';
import 'package:shiori/features/diagnostics/data/reader_feasibility_record.dart';
import 'package:shiori/features/diagnostics/data/reader_probe_summary.dart';

import 'diagnostics_fixtures.dart';
import 'presentation_probe_fixtures.dart';

typedef ExportJson = Map<String, Object?>;

/// Hand-built raw samples, with BOTH aggregate sets computed by production app
/// code. No analyzer import is allowed here: this is the NC6 reference side.
Map<String, ExportJson> readerAnalyzerExports() {
  final result = <String, ExportJson>{};
  for (var repeat = 1; repeat <= 3; repeat++) {
    result['passing-120hz-a1-$repeat.json'] = _record(repeat: repeat);
  }
  result['failing-budgets-a2.json'] = _record(
    variant: 'budget',
    mode: PresentationMode.a2,
  );
  result['stall-b.json'] = _record(variant: 'stall', mode: PresentationMode.b);
  result['negative-missing-frames.json'] = _record(variant: 'gaps');
  result['overflowed-rings.json'] = _record(variant: 'overflow');
  result['resources-100-turns-unavailable.json'] = _record(
    variant: 'resources',
  );
  result['resources-100-turns-bounded.json'] = _record(variant: 'bounded');
  result['double-acceptance.json'] = _record(variant: 'double');
  result['cap-breach.json'] = _record(variant: 'cap');
  result['unknown-schema.json'] = {..._record(), 'schemaVersion': 2};
  return result;
}

ExportJson _event(String kind, int us, [int? id]) => {
  'sequence': 0,
  'event': kind,
  'monotonicUs': us,
  'generation': kind == 'firstMotionSubmission' ? 2 : 1,
  'queueDepth': 0,
  'inputId': id,
  'captureEpoch': 1,
  'activeGeneration': kind == 'firstMotionSubmission' ? 2 : 1,
  if (kind == 'accepted')
    'destination': {
      'sectionIndex': 0,
      'pageIndex': id ?? 0,
      'layoutGeneration': 1,
      'pageIdentity': 'b' * 64,
    },
  if (kind == 'firstMotionSubmission') 'frameNumber': 1,
};

List<ExportJson> _events() => [
  _event('inputReceived', 7000000, 1),
  _event('pointerAdmitted', 7001000, 1),
  _event('preparationStart', 7001000, 1),
  _event('preparationHit', 7001000, 1),
  _event('prepared', 7002000, 1),
  _event('firstMotionSubmission', 7010000, 1),
  _event('settleEnd', 7100000, 1),
  _event('proofPassed', 7100000, 1),
  _event('accepted', 7100000, 1),
  _event('inputReceived', 7110000, 2),
  _event('admitted', 7111000, 2),
  _event('firstMotionSubmission', 7126000, 2),
  _event('settleEnd', 7180000, 2),
  _event('proofPassed', 7180000, 2),
  _event('accepted', 7180000, 2),
  _event('inputReceived', 7200000, 3),
  _event('queued', 7200000, 3),
  _event('admitted', 7230000, 3),
  _event('proofPassed', 7270000, 3),
  _event('accepted', 7270000, 3),
  _event('inputReceived', 7300000, 4),
  _event('admitted', 7301000, 4),
  _event('preparationStart', 7301000, 4),
  _event('preparationMiss', 7301000, 4),
  _event('prepared', 7341000, 4),
  _event('staticFallback', 7342000, 4),
  _event('proofPassed', 7343000, 4),
  _event('accepted', 7343000, 4),
  {
    ..._event('sectionPreparationStart', 7301000),
    'section': 0,
    'cacheHit': false,
  },
  {
    ..._event('sectionPreparationEnd', 7351000),
    'section': 0,
    'cacheHit': false,
  },
  _event('inputReceived', 7360000, 5),
  _event('rejected', 7360000, 5),
  _event('generationInvalidated', 7361000),
];

ExportJson _record({
  String variant = 'pass',
  int repeat = 1,
  PresentationMode mode = PresentationMode.a1,
}) {
  final events = _events();
  final resourceRun = {'resources', 'bounded', 'cap'}.contains(variant);
  if (resourceRun) {
    for (var id = 6; id <= 101; id++) {
      events.addAll([
        _event('inputReceived', 7362000 + id * 100, id),
        _event('admitted', 7362001 + id * 100, id),
        _event('proofPassed', 7362002 + id * 100, id),
        _event('accepted', 7362003 + id * 100, id),
      ]);
    }
  }
  for (final accepted
      in events.where((e) => e['event'] == 'accepted').toList()) {
    events.add(
      _event(
        'inputCommitted',
        (accepted['monotonicUs'] as int) - 1,
        accepted['inputId'] as int,
      ),
    );
  }
  if (variant == 'double') events.add(_event('accepted', 7344000, 4));
  if (variant == 'resources') {
    // A retained legacy schema-v1 export must remain explicitly unavailable.
    for (final event in events) {
      event.remove('captureEpoch');
      event.remove('activeGeneration');
      event.remove('destination');
    }
    events.removeWhere((e) => e['event'] == 'inputCommitted');
  }
  final frames = [
    for (var i = 0; i < 6; i++)
      diagnosticFrame(
        100000 + i * 8333 + (variant == 'stall' && i >= 3 ? 50000 : 0),
        frameNumber: variant == 'gaps' ? [-1, 1, 2, 4, 5, 6][i] : i + 1,
        buildUs: variant == 'budget'
            ? 9000 + i
            : [1000, 2000, 3000, 4000, 5000, 8333][i],
        rasterUs: variant == 'budget'
            ? 10000 + i
            : [2000, 3000, 4000, 5000, 6000, 8333][i],
      ),
  ];
  final motion = [
    for (var i = 0; i < 6; i++)
      if (variant != 'gaps' || i != 4)
        MotionSample(
          frameNumber: frames[i].frameNumber,
          schedulerUs: i * 8333,
          rawSchedulerUs: frames[i].vsyncUs + 8333,
          monotonicUs:
              7010000 + i * 8333 + (variant == 'stall' && i >= 3 ? 50000 : 0),
          progress: i / 6,
        ),
  ];
  final costs = [
    for (final cost in [100, 200, 300, 1000])
      <String, Object?>{
        'monotonicUs': 7000000,
        'section': 0,
        'layoutUs': cost,
        'codeUnits': 10,
        'lines': 2,
        'sectionPageCount': 8,
      },
  ];
  final resources = [
    for (var i = 0; i < 3; i++)
      <String, Object?>{
        'monotonicUs': 7000000 + i * 1000000,
        'liveSurfaces': 3,
        'pictureBytes': variant == 'cap' ? 20000000 : 1000 + i * 100,
        'imageBytes': 2000,
        'rssBytes': variant == 'resources' ? 10000 + i * 1000 : 10000,
      },
  ];
  final overflow = variant == 'overflow';
  if (overflow) {
    events.removeRange(0, 3);
    frames.removeAt(0);
    motion.removeAt(0);
    costs.removeAt(0);
    resources.removeAt(0);
  }
  events.sort(
    (a, b) => (a['monotonicUs'] as int).compareTo(b['monotonicUs'] as int),
  );
  for (var i = 0; i < events.length; i++) {
    events[i]['sequence'] = i + 1;
  }
  final engine = diagnosticRecord().copyWith(
    scenarioId: resourceRun ? 'R10' : 'R01',
    metadata: {
      ...diagnosticRecord().metadata,
      if (variant != 'resources') ...{
        'readerCorrectnessVersion': 1,
        'captureEpoch': 1,
        'resourceCaps': {
          'liveSurfaceCap': 3,
          'liveSurfaceReserve': 1,
          'pictureCacheBytes': 16 * 1024 * 1024,
          'imageCacheBytes': 48 * 1024 * 1024,
        },
      },
    },
    runId: 'synthetic-$variant-$repeat',
    buildId: 'synthetic',
    stoppedAt: DateTime.utc(2026, 10, 22, 12, 0, 3),
    stoppedMonotonicUs: 10000000,
    finalizedMonotonicUs: 11200000,
    frames: frames,
    motion: motion,
    frameOverflow: overflow ? 1 : 0,
    motionOverflow: overflow ? 1 : 0,
    omittedOutsideMotion: frames
        .where(
          (f) =>
              f.frameNumber < 0 ||
              !motion.any((m) => m.frameNumber == f.frameNumber),
        )
        .length,
    errors: variant == 'gaps'
        ? ['engine_frame_number_unavailable', 'motion_frame_number_unavailable']
        : [],
    aggregates: DiagnosticSummary.aggregate(
      frames,
      motion.map((m) => m.frameNumber).toSet(),
    ),
  );
  final native = _native(
    mode,
    unavailable: variant == 'resources',
    overflow: overflow,
  );
  final record = ReaderFeasibilityRecord(
    bookSha256: 'a' * 64,
    fixtureId: 'synthetic-export',
    scenarioId: resourceRun ? 'R10' : 'R01',
    repeatIndex: repeat,
    repeatCount: 3,
    input: 'synthetic_injected',
    engine: engine,
    readerEvents: events,
    layoutCosts: costs,
    resources: resources,
    presentation: native,
    aggregates: ReaderProbeSummary.aggregate(events, costs, resources),
    overflow: {
      'events': overflow ? 3 : 0,
      'layoutCosts': overflow ? 1 : 0,
      'resources': overflow ? 1 : 0,
      'frames': overflow ? 1 : 0,
      'motion': overflow ? 1 : 0,
      'native': overflow ? 2 : 0,
    },
    omissions: {
      'native': native['omission'],
      'trailingTimingBatch': true,
      'manualMinimumMet': true,
      'physicalPresentation': 'unverified',
      'touchToPhoton': 'unverified',
    },
  );
  return (jsonDecode(jsonEncode(record.toJson())) as Map<String, Object?>);
}

ExportJson _native(
  PresentationMode mode, {
  required bool unavailable,
  required bool overflow,
}) {
  final payload = presentationPayload(
    mode,
    omission: unavailable ? 'synthetic_native_unavailable' : null,
    overflow: overflow ? 2 : 0,
  );
  if (!unavailable) {
    payload['samples'] = switch (mode) {
      PresentationMode.inventory => <ExportJson>[],
      PresentationMode.a1 => [
        for (var i = 0; i < 4; i++)
          <String, Object?>{
            'kind': 'layer_commit',
            'timestamp': 10 + i * .008333,
          },
      ],
      PresentationMode.a2 => [
        for (var i = 0; i < 3; i++)
          <String, Object?>{
            'kind': 'display_link',
            'timestamp': 10 + i * .01,
            'targetTimestamp': 10 + (i + 1) * .01,
          },
        for (final time in [10.01, 10.021, 10.025, 10.04])
          <String, Object?>{'kind': 'layer_commit', 'timestamp': time},
      ],
      PresentationMode.b => [
        for (var i = 0; i < 3; i++)
          <String, Object?>{
            'kind': 'drawable',
            'timestamp': 10 + i * .008333,
            'drawableId': i == 0 ? '18446744073709551615' : '$i',
            'presentedTime': i == 2 ? 0.0 : 10.01 + i * .008333,
          },
      ],
    };
  }
  return {
    ...PresentationPayload.parse(payload, mode).toJson(),
    'mode': mode.name,
  };
}
