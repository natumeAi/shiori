import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/diagnostics/data/reader_capture_budget.dart';
import 'package:shiori/features/diagnostics/data/reader_export_repository.dart';

import '../../../../tool/diag/reader_export_analysis.dart';
import 'reader_capture_fixture.dart';

void main() {
  test('100 alternating turns x three independent repeats lose zero samples', () async {
    final fixture = CaptureFixture();
    addTearDown(fixture.recorder.dispose);
    List<Map<String, Object?>>? previous;
    for (var repeat = 1; repeat <= 3; repeat++) {
      await fixture.start(repeat);
      for (var turn = 0; turn < 100; turn++) {
        runZoned(
          () => fixture.turn(
            turn,
            variant: ['warm', 'cold', 'held', 'reverse'][turn % 4],
          ),
          zoneSpecification: ZoneSpecification(
            scheduleMicrotask: (_, _, _, _) =>
                fail('microtask scheduled in motion'),
            createTimer: (_, _, _, _, _) => throw StateError('timer in motion'),
            createPeriodicTimer: (_, _, _, _, _) =>
                throw StateError('periodic timer in motion'),
          ),
        );
      }
      // Actual motion writes have not materialized even one event map or
      // invoked native stop/export. All storage was allocated before motion.
      expect(fixture.recorder.events.materializedRows, 0);
      expect(fixture.recorder.events.numericBytes, 70778880);
      expect(fixture.native.stops, repeat - 1);
      final record = (await fixture.recorder.stop())!;
      expect(record.readerEvents.length, 33625); // 25*(310+315+410+310).
      expect(record.engine.motion.length, 5000);
      expect(record.presentation['samples'], hasLength(10000));
      expect(record.overflow.values, everyElement(0));
      final encoded = jsonEncode(record.toJson());
      final decoded = ReaderExportRepository.decode(encoded);
      final analysis = ReaderExportAnalysis(decoded.toJson());
      expect(analysis.mismatches, isEmpty);
      for (final name in [
        'long capture capacity / loss',
        'motion stalls',
        'warm admitted input to first submission',
        'native sample loss',
        'correctness / committed destinations / stale callbacks',
      ]) {
        expect(
          analysis.gates.singleWhere((g) => g.name == name).status,
          'pass',
          reason: name,
        );
      }
      expect(analysis.readerAggregates['acceptedTurns'], 100);
      final pages = record.readerEvents
          .where((e) => e['event'] == 'accepted')
          .map((e) => (e['destination'] as Map)['pageIndex'])
          .toList();
      expect(pages, [for (var i = 0; i < 100; i++) i.isEven ? 1 : 0]);
      if (previous != null) {
        expect(previous.first['sequence'], 1);
        expect(previous.first['captureEpoch'], repeat - 1);
        expect(previous.last['sequence'], 33625);
      }
      previous = record.readerEvents;
      // Useful reproducible wire sizing; excludes object/VM overhead.
      stdout.writeln(
        'repeat=$repeat events=33625 wireBytes=${utf8.encode(encoded).length} '
        'hostRss=${ProcessInfo.currentRss} hostPeakRss=${ProcessInfo.maxRss}',
      );
    }
  });

  test('R06-style ten-minute 120Hz traversal preserves all streams', () async {
    final fixture = CaptureFixture();
    addTearDown(fixture.recorder.dispose);
    await fixture.start(1, scenario: 'R06');
    for (var turn = 0; turn < 3000; turn++) {
      fixture.turn(turn, frames: 24, alternating: false);
    }
    expect(fixture.recorder.events.materializedRows, 0);
    final captureRss = ProcessInfo.currentRss;
    final record = (await fixture.recorder.stop())!;
    final finalizedRss = ProcessInfo.currentRss;
    expect(record.readerEvents, hasLength(462000));
    expect(record.engine.frames, hasLength(72000));
    expect(record.engine.motion, hasLength(72000));
    expect(record.presentation['samples'], hasLength(144000));
    expect(record.resources, hasLength(3001));
    expect(record.overflow.values, everyElement(0));
    final analysis = ReaderExportAnalysis(record.toJson());
    expect(analysis.mismatches, isEmpty);
    expect(analysis.captureBudget.status, 'pass');
    expect(analysis.demand.openIntervals, 0);
    expect(analysis.demand.candidates, isEmpty);
    final encoded = jsonEncode(record.toJson());
    // This controlled export has ASCII-only identities and metadata.
    expect(encoded.codeUnits.every((unit) => unit < 128), true);
    stdout.writeln(
      'R06 events=462000 frames=72000 native=144000 '
      'numericBytes=${fixture.recorder.events.numericBytes} '
      'wireBytes=${encoded.length} captureRss=$captureRss finalizedRss=$finalizedRss '
      'hostRss=${ProcessInfo.currentRss} hostPeakRss=${ProcessInfo.maxRss}',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('worst envelope fits fixed bounds, including held-frame expansion', () {
    expect(ReaderCaptureBudget.requiredEvents, 675456);
    expect(
      ReaderCaptureBudget.eventCapacity,
      greaterThan(ReaderCaptureBudget.requiredEvents),
    );
    expect(ReaderCaptureBudget.nativeCapacity, greaterThan(72144 * 3));
    expect(ReaderCaptureBudget.engineCapacity, greaterThan(72144));
  });

  test(
    'native source retains nonblocking bounded capture and matching capacity',
    () {
      final swift = File('ios/Runner/AppDelegate.swift').readAsStringSync();
      expect(
        swift,
        contains(
          'static let sampleCapacity = ${ReaderCaptureBudget.nativeCapacity}',
        ),
      );
      expect(swift, contains('"captureBudgetVersion": 1'));
      expect(swift, contains('if lock.try() { return true }'));
      expect(swift, contains('ShioriProbeCounterDrop(contention, ticket)'));
      final start = swift.indexOf('private func append(');
      final end = swift.indexOf('func end()', start);
      final motion = swift.substring(start, end);
      for (final forbidden in [
        'lock.lock()',
        'result(',
        'invokeMethod',
        'JSONSerialization',
        '.allocate(',
        'DispatchQueue',
      ]) {
        expect(motion, isNot(contains(forbidden)), reason: forbidden);
      }
      final dart = File(
        'lib/features/diagnostics/data/reader_event_buffer.dart',
      ).readAsStringSync();
      final append = dart.substring(
        dart.indexOf('  void add('),
        dart.indexOf('  List<Map<String, Object?>> snapshot('),
      );
      for (final forbidden in [
        '_Rows(',
        'Map',
        'List<',
        'Future',
        'Timer',
        'jsonEncode',
        'File(',
        '.snapshot(',
        '.sort(',
      ]) {
        expect(append, isNot(contains(forbidden)), reason: forbidden);
      }
    },
  );
}
