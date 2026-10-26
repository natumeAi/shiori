import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/diag/reader_export_analysis.dart';
import '../../../tool/diag/reader_export_data.dart';
import '../../../tool/diag/reader_export_report.dart';
import '../../../tool/diag/reader_native_resources.dart';

Json fixture(String name) => object(
  jsonDecode(
    File('test/fixtures/reader/exports/$name.json').readAsStringSync(),
  ),
  name,
);
String status(ReaderExportAnalysis run, String name) =>
    run.gates.singleWhere((g) => g.name == name).status;

void main() {
  test(
    'recognized admission unavailable when release follows first motion',
    () {
      final a = ReaderExportAnalysis(fixture('latency-release-after-motion'));
      expect(a.mismatches, isEmpty);
      final gate = a.gates.singleWhere(
        (g) => g.name == 'warm admitted input to first submission',
      );
      expect(gate.status, 'unavailable');
      expect(gate.threshold, 'P95 <=16700 us');
      expect(
        object(
          a.readerAggregates['warmInputToFirstSubmission'],
          'warm',
        )['p95Us'],
        16000,
      );
      expect(
        renderReaderReport([a]),
        contains('informational; legacy App aggregate'),
      );
    },
  );

  test('R03 script intent cannot explain an unrecorded hold or idle', () {
    final a = ReaderExportAnalysis(fixture('stall-script-intent-unresolved'));
    final classes = object(a.stalls['classes'], 'classes');
    expect(classes, {
      'recordedDeliberateHold': 0,
      'provenIdleNoFrameRequested': 0,
      'dueLateOrMissing': 0,
      'unresolved': 2,
    });
    expect(objects(a.stalls['candidates'], 'candidates'), hasLength(2));
    expect(status(a, 'motion stalls'), 'fail');
  });

  test('recorded long stage proves a late execution frame at 50000 us', () {
    final a = ReaderExportAnalysis(fixture('stall-long-stage'));
    expect(object(a.stalls['classes'], 'classes')['dueLateOrMissing'], 1);
    expect(status(a, 'motion stalls'), 'fail');
  });

  test('A2 phase shift and epsilon overlap retain bins and all anomalies', () {
    final a = ReaderExportAnalysis(fixture('display-phase-and-epsilon'));
    final bins = object(a.native['commitsPerDisplayPeriod'], 'bins');
    expect(
      [
        bins['zero'],
        bins['one'],
        bins['atLeastTwo'],
        bins['outsideRecordedPeriods'],
      ],
      [1, 1, 1, 1],
    );
    final anomalies = object(bins['anomalies'], 'anomalies');
    expect(anomalies['overlapCount'], 2);
    expect(anomalies['phaseOverlapCount'], 1);
    expect(anomalies['epsilonOverlapCount'], 1);
    expect(anomalies['maximumOverlapUs'], closeTo(2000, .000001));
    expect(a.mismatches, isEmpty);
  });

  test('A2 clipped boundary assigns a commit once and preserves holes', () {
    final p = object(fixture('display-phase-and-epsilon')['presentation'], 'p');
    final samples = objects(p['samples'], 'samples');
    p['samples'] = [
      ...samples.where((s) => s['kind'] == 'display_link'),
      for (final time in [10.008, 10.0199999, 10.03, 10.04])
        <String, Object?>{'kind': 'layer_commit', 'timestamp': time},
    ];
    final bins = object(nativeAnalysis(p)['commitsPerDisplayPeriod'], 'bins');
    expect(
      [
        bins['zero'],
        bins['one'],
        bins['atLeastTwo'],
        bins['outsideRecordedPeriods'],
      ],
      [1, 2, 0, 2],
    );
  });

  test(
    'native unsorted negative nonnumeric and nonpositive periods reject',
    () {
      for (final value in [-1, 'bad', double.nan, 10.04]) {
        final p = object(
          fixture('display-phase-and-epsilon')['presentation'],
          'p',
        );
        final links = objects(
          p['samples'],
          's',
        ).where((s) => s['kind'] == 'display_link').toList();
        links[1]['timestamp'] = value;
        expect(() => nativeAnalysis(p), throwsFormatException);
      }
      final p = object(
        fixture('display-phase-and-epsilon')['presentation'],
        'p',
      );
      final links = objects(
        p['samples'],
        's',
      ).where((s) => s['kind'] == 'display_link').toList();
      links[1]['timestamp'] = 9.99;
      expect(() => nativeAnalysis(p), throwsFormatException);
      links[1]['timestamp'] = links[0]['timestamp'];
      expect(() => nativeAnalysis(p), throwsFormatException);
    },
  );

  test(
    'queue overflow cancellation proves neither a commit nor settlement',
    () {
      final a = ReaderExportAnalysis(fixture('queue-cancelled-open-window'));
      expect(a.inputs.counts['queued'], 8);
      expect(a.inputs.counts['overflow'], 7);
      expect(a.correctness['failures'], 0);
      expect(
        status(a, 'correctness / committed destinations / stale callbacks'),
        'unavailable',
      );
      expect(a.inputs.openWindows, 1);
      expect(status(a, 'motion stalls'), 'unavailable');
    },
  );

  test('cold RSS growth remains failed and is never trimmed as warmup', () {
    final a = ReaderExportAnalysis(fixture('rss-cold-growth'));
    expect(status(a, 'resource trend >=100 turns'), 'fail');
    expect(a.readerAggregates['acceptedTurns'], 100);
    expect(object(a.resources['rssBytes'], 'rss')['first'], 10000);
  });

  test('B gap classes preserve pending pipeline and zero presentations', () {
    final a = ReaderExportAnalysis(fixture('drawable-gap-classes'));
    final c = object(a.native['drawableGapClasses'], 'c');
    expect(c['intervalsAtLeastThreshold'], 2);
    expect(c['noAcquisitionBetweenPresentations'], 1);
    expect(c['withAcquisitionBetweenPresentations'], 1);
    expect(c['timelyAcquisitionPresentationGap'], 1);
    expect(c['acquisitionGap'], 1);
    expect(c['notObservedPresentedByStop'], 2);
    expect(c['unpresentedAcquiredBeforeLastPresentation'], 1);
    expect(c['unpresentedAcquiredAtLeastThresholdBeforeLastAcquisition'], 1);
    expect(c['nativeLossQualifiesAbsence'], false);
    expect(
      objects(c['gaps'], 'gaps').first['class'],
      'timelyAcquisitionPresentationGap',
    );
    final p = object(a.raw['presentation'], 'p');
    p['overflow'] = 1;
    p['contentionDrops'] = 1;
    expect(
      object(
        nativeAnalysis(p)['drawableGapClasses'],
        'c',
      )['nativeLossQualifiesAbsence'],
      true,
    );
  });
}
