import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/diag/reader_export_analysis.dart';
import '../../../tool/diag/reader_export_data.dart';
import '../../../tool/diag/reader_native_resources.dart';

Json raw([String name = 'passing-120hz-a1-1.json']) => object(
  jsonDecode(File('test/fixtures/reader/exports/$name').readAsStringSync()),
  name,
);

void main() {
  test('metadata native mode never fills cadence or presentation counters', () {
    final export = raw();
    final p = object(export['presentation'], 'presentation');
    p['mode'] = 'inventory';
    p['evidence'] = 'metadata';
    p['samples'] = <Object?>[];
    final a = ReaderExportAnalysis(export);
    expect(a.native['inventory'], p['inventory']);
    expect(a.native.containsKey('commitIntervals'), false);
    expect(a.native.containsKey('presented'), false);
    expect(a.native['evidence'], 'metadata');
  });
  test(
    'native mode evidence required streams and contention subset are checked',
    () {
      final p = object(raw()['presentation'], 'presentation');
      expect(
        () => nativeAnalysis({...p, 'mode': 'unknown'}),
        throwsFormatException,
      );
      expect(
        () => nativeAnalysis({...p, 'evidence': 'metadata'}),
        throwsFormatException,
      );
      expect(
        () => nativeAnalysis({...p, 'samples': <Object?>[]}),
        throwsFormatException,
      );
      expect(
        () => nativeAnalysis({...p, 'contentionDrops': 1}),
        throwsFormatException,
      );
      expect(
        () => nativeAnalysis({
          ...p,
          'mode': 'b',
          'evidence': 'system_drawable_presentation_non_product_path',
        }),
        throwsFormatException,
      );
    },
  );
  test('overlapping A2 periods are rejected rather than double-counted', () {
    final p = object(
      raw('failing-budgets-a2.json')['presentation'],
      'presentation',
    );
    final links = objects(
      p['samples'],
      'samples',
    ).where((s) => s['kind'] == 'display_link').toList();
    links[1]['timestamp'] = 10.005;
    expect(() => nativeAnalysis(p), throwsFormatException);
  });
  test('native epoch shifts do not change intervals or join Dart clocks', () {
    final export = raw('stall-b.json');
    final before = ReaderExportAnalysis(export);
    for (final sample in objects(
      object(export['presentation'], 'presentation')['samples'],
      'samples',
    )) {
      sample['timestamp'] = (sample['timestamp'] as num) + 1000000;
      if ((sample['presentedTime'] as num) > 0) {
        sample['presentedTime'] = (sample['presentedTime'] as num) + 1000000;
      }
    }
    final after = ReaderExportAnalysis(export);
    expect(
      after.native['presentationIntervals'],
      before.native['presentationIntervals'],
    );
    expect(after.engine.aggregates, before.engine.aggregates);
    expect(after.readerAggregates, before.readerAggregates);
  });
  test('all-zero B reports no observed presentations without inferring scanout failure', () {
    final export = raw('stall-b.json');
    final p = object(export['presentation'], 'presentation');
    p['available'] = false;
    p['omission'] = 'no_presented_drawables_at_stop';
    for (final s in objects(p['samples'], 'samples')) {
      s['presentedTime'] = 0;
    }
    final a = ReaderExportAnalysis(export);
    expect(a.native['presented'], 0);
    expect(a.native['notPresentedByStop'], 3);
    expect(
      object(a.native['presentationIntervals'], 'intervals')['source'],
      'unavailable_no_samples',
    );
    expect(a.native['omission'], 'no_presented_drawables_at_stop');
  });
  test('50 ms stall threshold is inclusive', () {
    for (final cost in [49999, 50000]) {
      final export = raw();
      final frame = objects(
        object(export['engine'], 'engine')['frames'],
        'frames',
      ).first;
      frame['buildFinishUs'] = (frame['buildStartUs'] as int) + cost;
      final a = ReaderExportAnalysis(export);
      expect(a.stalls['longStageFrames'], cost == 50000 ? 1 : 0);
      expect(a.stalls['observed'], cost == 50000);
    }
  });
  test('open motion windows cannot establish absence of stalls', () {
    final export = raw();
    export['readerEvents'] = objects(
      export['readerEvents'],
      'events',
    ).where((e) => e['event'] != 'settleEnd').toList();
    final a = ReaderExportAnalysis(export);
    expect(a.inputs.openWindows, 2);
    expect(
      a.gates.singleWhere((g) => g.name == 'motion stalls').status,
      'unavailable',
    );
  });
  test(
    'resource slope is OLS over actual time not endpoint delta or sample index',
    () {
      final samples = [
        <String, Object?>{'monotonicUs': 0, 'rssBytes': 10},
        <String, Object?>{'monotonicUs': 1000000, 'rssBytes': 30},
        <String, Object?>{'monotonicUs': 3000000, 'rssBytes': 20},
      ];
      final trend = object(resourceTrends(samples)['rssBytes'], 'rss');
      expect(trend['slopePerSecond'], closeTo(15 / 7, 1e-9));
      expect([trend['first'], trend['last'], trend['max']], [10, 20, 30]);
    },
  );
}
