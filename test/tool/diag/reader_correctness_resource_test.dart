import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/diag/reader_export_analysis.dart';
import '../../../tool/diag/reader_export_data.dart';

Json load(String name) => object(
  jsonDecode(
    File('test/fixtures/reader/exports/$name.json').readAsStringSync(),
  ),
  name,
);
const correctness = 'correctness / committed destinations / stale callbacks';
const resource = 'resource trend >=100 turns';
GateRow gate(Json raw, String name) =>
    ReaderExportAnalysis(raw).gates.singleWhere((g) => g.name == name);

void main() {
  test('double acceptance fails correctness with perfect aggregate parity', () {
    final raw = load('double-acceptance');
    final a = ReaderExportAnalysis(raw);
    expect(a.mismatches, isEmpty);
    expect(a.correctness['committedWithoutSingleAcceptance'], 1);
    expect(gate(raw, correctness).status, 'fail');
  });
  for (final remove in ['inputCommitted', 'accepted']) {
    test(
      'missing $remove fails explicit committed destination cardinality',
      () {
        final raw = load('passing-120hz-a1-1');
        raw['readerEvents'] = objects(
          raw['readerEvents'],
          'events',
        ).where((e) => e['event'] != remove || e['inputId'] != 1).toList();
        expect(gate(raw, correctness).status, 'fail');
      },
    );
  }
  test(
    'stale rejection is safe; a publication by its rejected token fails',
    () {
      final raw = load('passing-120hz-a1-1');
      final events = objects(raw['readerEvents'], 'events');
      final acceptance = events.firstWhere((e) => e['event'] == 'accepted');
      events.insert(events.indexOf(acceptance), {
        ...acceptance,
        'event': 'staleCallbackRejected',
        'generation': 0,
        'activeGeneration': 1,
      });
      raw['readerEvents'] = events;
      expect(gate(raw, correctness).status, 'pass');
      acceptance['generation'] = 0;
      expect(gate(raw, correctness).status, 'fail');
    },
  );
  for (final field in ['captureEpoch', 'generationInvalidated']) {
    test('$field prevents stale publication from looking accepted', () {
      final raw = load('passing-120hz-a1-1');
      final events = objects(raw['readerEvents'], 'events');
      final accepted = events.firstWhere((e) => e['event'] == 'accepted');
      if (field == 'captureEpoch') {
        accepted['captureEpoch'] = 0;
      } else {
        events.insert(events.indexOf(accepted), {
          ...accepted,
          'event': 'generationInvalidated',
        });
      }
      raw['readerEvents'] = events;
      expect(gate(raw, correctness).status, 'fail');
    });
  }
  test('proof failure is a definite correctness failure', () {
    final raw = load('passing-120hz-a1-1');
    objects(
      raw['readerEvents'],
      'events',
    ).firstWhere((e) => e['event'] == 'proofPassed')['event'] = 'proofFailed';
    expect(gate(raw, correctness).status, 'fail');
  });
  test(
    'legacy and missing destination fields stay unavailable with reasons',
    () {
      final old = load('resources-100-turns-unavailable');
      expect(gate(old, correctness).status, 'unavailable');
      expect(gate(old, resource).reason, contains('missing declared'));
      final raw = load('passing-120hz-a1-1');
      objects(
        raw['readerEvents'],
        'events',
      ).firstWhere((e) => e['event'] == 'accepted').remove('destination');
      expect(gate(raw, correctness).status, 'unavailable');
      expect(gate(raw, correctness).reason, contains('missing correctness'));
    },
  );
  test('100-turn resource fixture passes and cap-breach fixture fails', () {
    final raw = load('resources-100-turns-bounded');
    expect(gate(raw, correctness).status, 'pass');
    expect(gate(raw, resource).status, 'pass');
    final cap = load('cap-breach');
    expect(ReaderExportAnalysis(cap).mismatches, isEmpty);
    expect(gate(cap, resource).status, 'fail');
    expect(gate(cap, resource).reason, contains('pictureBytes'));
  });
  for (final field in [
    'generation',
    'activeGeneration',
    'inputId',
    'captureEpoch',
  ]) {
    test(
      'missing acceptance $field cannot fabricate a cardinality failure',
      () {
        final raw = load('passing-120hz-a1-1');
        objects(
          raw['readerEvents'],
          'events',
        ).firstWhere((e) => e['event'] == 'accepted').remove(field);
        expect(gate(raw, correctness).status, 'unavailable');
      },
    );
  }
  for (final cap in [
    'liveSurfaceCap',
    'pictureCacheBytes',
    'imageCacheBytes',
  ]) {
    test('$cap is enforced from declaration', () {
      final raw = load('resources-100-turns-bounded');
      final caps = object(
        object(
          object(raw['engine'], 'engine')['metadata'],
          'metadata',
        )['resourceCaps'],
        'caps',
      );
      caps[cap] = 0;
      expect(gate(raw, resource).status, 'fail');
    });
  }
  test(
    'RSS endpoint and OLS projected growth use inclusive named 5% bound',
    () {
      expect(ReaderGates.maximumRssGrowthFraction, .05);
      for (final growth in [500, 501]) {
        final raw = load('resources-100-turns-bounded');
        objects(raw['resources'], 'resources').last['rssBytes'] =
            10000 + growth;
        expect(gate(raw, resource).status, growth == 500 ? 'pass' : 'fail');
      }
      final raw = load('resources-100-turns-bounded');
      final samples = objects(raw['resources'], 'resources');
      samples[1]['monotonicUs'] = 8500000;
      samples[1]['rssBytes'] = 15000;
      expect(gate(raw, resource).status, 'fail');
      expect(gate(raw, resource).reason, contains('OLS'));
    },
  );
  test(
    'insufficient turns, overflow or missing resource samples cannot pass',
    () {
      expect(gate(load('passing-120hz-a1-1'), resource).status, 'unavailable');
      for (final kind in ['events', 'resources', 'samples']) {
        final raw = load('resources-100-turns-bounded');
        if (kind == 'samples') {
          raw['resources'] = <Json>[];
        } else {
          object(raw['overflow'], 'overflow')[kind] = 1;
        }
        expect(gate(raw, resource).status, 'unavailable');
        if (kind == 'events') {
          expect(gate(raw, correctness).status, 'unavailable');
        }
      }
    },
  );
}
