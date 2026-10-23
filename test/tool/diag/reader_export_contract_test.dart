import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/diag/reader_export_analysis.dart';
import '../../../tool/diag/reader_export_data.dart';
import '../../../tool/diag/reader_export_report.dart';

Json fixture([String name = 'passing-120hz-a1-1.json']) => object(
  jsonDecode(File('test/fixtures/reader/exports/$name').readAsStringSync()),
  name,
);
String result(ReaderExportAnalysis run, String name) =>
    run.gates.singleWhere((g) => g.name == name).status;

void main() {
  test(
    'refuses unknown kind and noninteger missing or unknown schema versions',
    () {
      expect(
        () =>
            ReaderExportAnalysis({...fixture(), 'kind': 'synthetic_transform'}),
        throwsFormatException,
      );
      for (final version in [null, 0, 2, '1', 1.0]) {
        expect(
          () => ReaderExportAnalysis({...fixture(), 'schemaVersion': version}),
          throwsFormatException,
        );
      }
      final raw = fixture();
      object(raw['engine'], 'engine')['schemaVersion'] = 2;
      expect(() => ReaderExportAnalysis(raw), throwsFormatException);
    },
  );
  test(
    'S1 and reader percentile conventions remain independently reproducible',
    () {
      expect(distribution([1, 2, 3, 4])['p50Us'], 2);
      expect(distribution([1, 2, 3, 4], engine: true)['p50Us'], 3);
      expect(distribution([], engine: true), {
        'count': 0,
        'source': 'unavailable_no_samples',
      });
      expect(distribution([])['p95Us'], isNull);
    },
  );
  test(
    'budget and missed interval thresholds have distinct inclusive boundaries',
    () {
      expect(distribution([8333, 8334], engine: true)['over8333Us'], 1);
      expect(
        distribution(
          [8334, 12499, 12500],
          engine: true,
          interval: true,
        )['atLeast12500Us'],
        1,
      );
    },
  );
  test('99 percent gate accepts exactly 99 and fails 98 independently', () {
    for (final over in [1, 2]) {
      final raw = fixture();
      final engine = object(raw['engine'], 'engine');
      final frame = objects(engine['frames'], 'frames').first;
      final motion = objects(engine['motion'], 'motion').first;
      engine['frames'] = [
        for (var i = 0; i < 100; i++)
          {
            ...frame,
            'frameNumber': i,
            'vsyncUs': i * 8333,
            'buildFinishUs':
                (frame['buildStartUs'] as int) + (i < over ? 8334 : 8333),
          },
      ];
      engine['motion'] = [
        for (var i = 0; i < 100; i++) {...motion, 'frameNumber': i},
      ];
      final a = ReaderExportAnalysis(raw);
      expect(result(a, 'ui motion budget'), over == 1 ? 'pass' : 'fail');
      expect(result(a, 'raster motion budget'), 'pass');
    }
  });
  test('receipt timing cannot establish the 16.7 ms admission gate', () {
    for (final latency in [16700, 16701]) {
      final raw = fixture();
      final events = objects(raw['readerEvents'], 'events');
      events.firstWhere(
        (e) => e['event'] == 'firstMotionSubmission' && e['inputId'] == 2,
      )['monotonicUs'] = 7110000 + latency;
      expect(
        result(
          ReaderExportAnalysis(raw),
          'warm admitted input to first submission',
        ),
        'unavailable',
      );
    }
  });
  test('incomplete warm identity joins are not filled or marked passing', () {
    final raw = fixture();
    raw['readerEvents'] = objects(
      raw['readerEvents'],
      'events',
    ).where((e) => e['event'] != 'inputReceived' || e['inputId'] != 1).toList();
    final a = ReaderExportAnalysis(raw);
    expect(a.inputs.incompleteWarmInputs, 1);
    expect(
      object(
        a.readerAggregates['warmInputToFirstSubmission'],
        'latency',
      )['count'],
      1,
    );
    expect(result(a, 'warm admitted input to first submission'), 'unavailable');
  });
  test('capture epochs and opaque IDs are never joined across input files', () {
    final first = fixture(), second = fixture('passing-120hz-a1-2.json');
    first['readerEvents'] = objects(
      first['readerEvents'],
      'events',
    ).where((e) => e['event'] != 'firstMotionSubmission').toList();
    second['readerEvents'] = objects(
      second['readerEvents'],
      'events',
    ).where((e) => e['event'] != 'inputReceived').toList();
    final a = ReaderExportAnalysis(first), b = ReaderExportAnalysis(second);
    expect(
      object(a.readerAggregates['warmInputToFirstSubmission'], 'a')['count'],
      0,
    );
    expect(
      object(b.readerAggregates['warmInputToFirstSubmission'], 'b')['count'],
      0,
    );
    expect(
      renderReaderReport([a, b]),
      contains('recognized admission is not recorded'),
    );
  });
  test(
    'proof failures and duplicate accepted destinations fail observed gates',
    () {
      final raw = fixture();
      final events = objects(raw['readerEvents'], 'events');
      // objects() returns a list projection, so replace the raw list after append.
      raw['readerEvents'] = [
        ...events,
        {...events.first, 'event': 'proofFailed'},
        {...events.first, 'event': 'accepted'},
      ];
      final a = ReaderExportAnalysis(raw);
      expect(a.correctness['proofFailures'], 1);
      expect(result(a, 'proof failures'), 'fail');
      expect(
        result(a, 'correctness / committed destinations / stale callbacks'),
        'fail',
      );
    },
  );
  test('missing destination identity is unavailable rather than guessed', () {
    final raw = fixture();
    raw['readerEvents'] = objects(raw['readerEvents'], 'events')
        .map(
          (e) => e['event'] == 'accepted' ? ({...e}..remove('destination')) : e,
        )
        .toList();
    expect(
      result(
        ReaderExportAnalysis(raw),
        'correctness / committed destinations / stale callbacks',
      ),
      'unavailable',
    );
  });
  test(
    'empty raw arrays produce unavailable rows instead of numeric fills',
    () {
      final raw = fixture();
      for (final key in ['readerEvents', 'resources', 'layoutCosts']) {
        raw[key] = <Object?>[];
      }
      final engine = object(raw['engine'], 'engine');
      engine['frames'] = <Object?>[];
      engine['motion'] = <Object?>[];
      final a = ReaderExportAnalysis(raw);
      expect(result(a, 'ui motion budget'), 'unavailable');
      expect(result(a, 'motion stalls'), 'unavailable');
      expect(a.readerAggregates['staticFallbackRate'], isNull);
      expect(a.readerAggregates['rssDeltaBytes'], isNull);
    },
  );
  test(
    'omissions native unavailability and evidence boundaries survive markdown',
    () {
      final a = ReaderExportAnalysis(
        fixture('resources-100-turns-unavailable.json'),
      );
      final markdown = renderReaderReport([a]);
      expect(markdown, contains('synthetic_native_unavailable'));
      expect(markdown, contains('trailingTimingBatch'));
      expect(markdown, contains('missing declared resource caps'));
      expect(
        markdown,
        contains(
          'does not establish physical presentation or touch-to-photon latency',
        ),
      );
      expect(result(a, 'native evidence (a1)'), 'unavailable');
      expect(
        result(a, 'physical presentation / touch-to-photon'),
        'unavailable',
      );
    },
  );
  test('summary covers three repeats without pooling their percentiles', () {
    final runs = [
      for (var n = 1; n <= 3; n++)
        ReaderExportAnalysis(fixture('passing-120hz-a1-$n.json')),
    ];
    final markdown = renderReaderReport(runs);
    expect(markdown, contains('pass: 3 required repeats present'));
    expect(markdown, contains('1, 2, 3'));
    expect(
      renderReaderReport([runs.first, runs.first]),
      contains('missing, duplicate or inconsistent repeats'),
    );
  });
  test('mismatch comparison catches every path missing and unexpected aggregate keys', () {
    final raw = fixture();
    final aggregates = object(raw['aggregates'], 'aggregates');
    aggregates['acceptedTurns'] = 9;
    aggregates.remove('proofFailures');
    aggregates['unexpected'] = 1;
    object(
      object(raw['engine'], 'engine')['aggregates'],
      'aggregates',
    )['cadencePattern'] = 'wrong';
    final a = ReaderExportAnalysis(raw);
    expect(a.mismatches, hasLength(4));
    final markdown = renderReaderReport([a]);
    for (final name in [
      'acceptedTurns',
      'proofFailures',
      'unexpected',
      'engine.aggregates.cadencePattern',
    ]) {
      expect(markdown, contains(name));
    }
  });
}
