import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/diagnostics/bounded_ring.dart';
import 'package:shiori/core/diagnostics/diagnostic_recorder.dart';
import 'package:shiori/features/diagnostics/data/presentation_probe.dart';
import 'package:shiori/features/diagnostics/data/reader_probe_recorder.dart';
import 'package:shiori/features/diagnostics/data/reader_export_repository.dart';
import 'package:shiori/features/reader/engine/motion/turn_session.dart';

import '../../../../tool/diag/reader_export_analysis.dart';
import '../../../helpers/diagnostics_fixtures.dart';
import '../../../helpers/reader_probe_fixtures.dart';

void main() {
  test('100 synthetic dirty-drag turns expose all Dart ring loss', () async {
    final rec = readerRecorder(capacity: 16384);
    addTearDown(rec.dispose);
    await startReader(rec);
    for (var turn = 0; turn < 100; turn++) {
      final input = Object();
      for (final event in [
        TurnTimingEvent.inputReceived,
        TurnTimingEvent.inputRecognized,
        TurnTimingEvent.recognizedAdmission,
      ]) {
        rec.recordTurn(event, 0, turn, 0, input);
      }
      for (var frame = 0; frame < 50; frame++) {
        for (final event in [
          TurnTimingEvent.dragDirty,
          TurnTimingEvent.frameDemandStart,
          TurnTimingEvent.dragClean,
          TurnTimingEvent.visualMutation,
          TurnTimingEvent.frameDemandEnd,
          TurnTimingEvent.holdStart,
          TurnTimingEvent.holdEnd,
        ]) {
          rec.recordTurn(event, 0, turn, 0, input);
        }
        rec.submitted(
          frameNumber: turn * 50 + frame,
          schedulerUs: frame * 8333,
          rawSchedulerUs: frame * 8333,
          generation: turn,
          offset: frame.toDouble(),
          input: input,
        );
      }
    }
    final record = (await rec.stop())!;
    expect(record.readerEvents, hasLength(16384));
    expect(record.overflow['events'], 24016);
    final analysis = ReaderExportAnalysis(record.toJson());
    expect(
      analysis.gates.singleWhere((g) => g.name == 'motion stalls').status,
      'unavailable',
    );
    expect(
      analysis.gates
          .singleWhere(
            (g) => g.name == 'warm admitted input to first submission',
          )
          .status,
      'unavailable',
    );
  });
  test('first submission identity includes the capture epoch', () async {
    final rec = readerRecorder(capacity: 20);
    addTearDown(rec.dispose);
    final previous = Object();
    await startReader(rec);
    rec.recordTurn(TurnTimingEvent.inputReceived, 0, 0, 0, previous);
    await rec.stop();
    await startReader(rec, runId: 'second');
    final current = Object();
    rec.recordTurn(TurnTimingEvent.inputReceived, 0, 0, 0, current);
    for (final input in [previous, current]) {
      rec.submitted(
        frameNumber: 1,
        schedulerUs: 8333,
        rawSchedulerUs: 8333,
        generation: 0,
        offset: 10,
        input: input,
      );
    }
    final record = (await rec.stop())!;
    final submissions = record.readerEvents
        .where((e) => e['event'] == 'firstMotionSubmission')
        .toList();
    expect(submissions.map((e) => e['inputId']), [1, 1]);
    expect(submissions.map((e) => e['captureEpoch']), [1, 2]);
  });

  test(
    'correctness evidence preserves epochs, input and hashed destination',
    () async {
      final rec = readerRecorder(capacity: 20);
      addTearDown(rec.dispose);
      await startReader(rec);
      final input = Object();
      rec.recordEvidence(TurnTimingEvent.inputCommitted, 1, 1, 1, 0, input);
      const destination = TurnPosition(
        cfi: 'private assertion',
        layoutKey: 'private layout',
        layoutGeneration: 9,
        sectionIndex: 2,
        pageIndex: 3,
        pageCount: 10,
        pageIdentity: 'private page',
        atStart: false,
        atEnd: false,
      );
      rec.recordEvidence(
        TurnTimingEvent.accepted,
        2,
        1,
        1,
        0,
        input,
        destination: destination,
      );
      final first = (await rec.stop())!;
      final accepted = first.readerEvents.last;
      expect(first.engine.metadata['readerCorrectnessVersion'], 1);
      expect(accepted['captureEpoch'], first.engine.metadata['captureEpoch']);
      expect(first.readerEvents.map((e) => e['inputId']).toSet(), {1});
      expect(accepted['destination'], {
        'sectionIndex': 2,
        'pageIndex': 3,
        'layoutGeneration': 9,
        'pageIdentity': isA<String>().having(
          (s) => s.length,
          'digest length',
          64,
        ),
      });
      final json = jsonEncode(first.toJson());
      expect(json, isNot(contains('private')));
      expect(ReaderExportRepository.decode(json), first);
      await startReader(rec, runId: 'second');
      rec.recordEvidence(
        TurnTimingEvent.staleCallbackRejected,
        3,
        1,
        2,
        0,
        input,
      );
      final second = (await rec.stop())!;
      expect(
        second.readerEvents.single['captureEpoch'],
        accepted['captureEpoch'],
      );
      expect(
        second.engine.metadata['captureEpoch'],
        isNot(second.readerEvents.single['captureEpoch']),
      );
      expect(second.readerEvents.single['generation'], 1);
      expect(second.readerEvents.single['activeGeneration'], 2);
    },
  );
  test('ring evicts oldest and rejects zero capacity', () {
    expect(() => BoundedRing<int>(0), throwsArgumentError);
    final ring = BoundedRing<int>(2);
    for (var i = 0; i < 5; i++) {
      ring.add(i);
    }
    expect(ring.snapshot(), [3, 4]);
    expect(ring.overflow, 3);
    ring.clear();
    expect(ring.snapshot(), isEmpty);
    expect(ring.overflow, 0);
  });
  test(
    'all rings have independent exact bounds and overflow counters',
    () async {
      final source = DiagnosticTestFrameSource();
      final rec = readerRecorder(capacity: 2, source: source);
      addTearDown(rec.dispose);
      await startReader(rec);
      for (var i = 1; i <= 5; i++) {
        rec.record(TurnTimingEvent.accepted, i.toDouble(), i, 0);
        rec.layout(
          section: 0,
          layoutUs: i,
          codeUnits: i,
          lines: 1,
          pageCount: 8,
        );
        rec.memory(
          liveSurfaces: 1,
          pictureBytes: i,
          imageBytes: 0,
          rssBytes: 100 + i,
        );
        rec.submitted(
          frameNumber: i,
          schedulerUs: i * 8333,
          rawSchedulerUs: i * 8333,
          generation: i,
          offset: i.toDouble(),
        );
        source.emit([diagnosticTiming(i * 8333, frameNumber: i)]);
      }
      final record = (await rec.stop())!;
      expect(record.readerEvents.length, 2);
      expect(record.layoutCosts.length, 2);
      expect(record.resources.length, 2);
      expect(record.engine.frames.length, 2);
      expect(record.engine.motion.length, 2);
      expect(record.overflow, {
        'events': 13,
        'layoutCosts': 3,
        'resources': 3,
        'frames': 3,
        'motion': 3,
        'native': 0,
      });
      expect(record.presentation['available'], false);
      expect(record.presentation['omission'], isNotNull);
    },
  );
  test('drain accepts late frames and ignores reader events and finished callbacks', () async {
    final source = DiagnosticTestFrameSource();
    final rec = readerRecorder(source: source);
    addTearDown(rec.dispose);
    await startReader(rec);
    final completed = rec.stop();
    expect(rec.engine.phase, CapturePhase.draining);
    source.emit([diagnosticTiming(1)]);
    rec.record(TurnTimingEvent.accepted, 1, 1, 0);
    final record = (await completed)!;
    expect(record.readerEvents, isEmpty);
    expect(record.engine.frames.length, 1);
    expect(record.engine.reportsDuringDrain, 1);
    expect(record.engine.incompleteTrailingBatch, true);
    source.emit([diagnosticTiming(2)]);
    expect((await rec.completed)!.engine.frames.length, 1);
  });
  test(
    'previous source callback cannot publish into a restarted capture',
    () async {
      final source = DiagnosticTestFrameSource();
      final rec = readerRecorder(source: source);
      addTearDown(rec.dispose);
      await startReader(rec);
      final previous = source.callback!;
      await rec.stop();
      await startReader(rec, runId: 'second');
      previous([diagnosticTiming(7, frameNumber: 7)]);
      source.emit([diagnosticTiming(8, frameNumber: 8)]);
      final record = (await rec.stop())!;
      expect(record.engine.frames.single.frameNumber, 8);
    },
  );
  test('opaque input survives drag/release generations; first submission is unique', () async {
    final clock = DiagnosticTestClock();
    final rec = readerRecorder(clock: clock, capacity: 20);
    addTearDown(rec.dispose);
    await startReader(rec);
    final input = Object();
    rec.recordTurn(TurnTimingEvent.inputReceived, 0, 0, 0, input);
    rec.recordTurn(TurnTimingEvent.pointerAdmitted, 0, 0, 0, input);
    clock.advance(const Duration(microseconds: 10000));
    for (final generation in [0, 1]) {
      rec.submitted(
        frameNumber: generation + 1,
        schedulerUs: 10000,
        rawSchedulerUs: 10000,
        generation: generation,
        offset: 50,
        input: input,
      );
    }
    final record = (await rec.stop())!;
    expect(
      record.readerEvents
          .where((e) => e['event'] == 'firstMotionSubmission')
          .length,
      1,
    );
    expect(record.readerEvents.map((e) => e['inputId']).toSet(), {1});
    expect(
      (record.aggregates['warmInputToFirstSubmission'] as Map)['p95Us'],
      10000,
    );
  });
  test('dispose resolves completion and rejects all late callbacks', () async {
    final rec = readerRecorder();
    await startReader(rec);
    final completed = rec.completed;
    rec.dispose();
    expect(await completed, isNull);
    rec.record(TurnTimingEvent.accepted, 0, 0, 0);
    expect(rec.events.snapshot(), isEmpty);
    await expectLater(startReader(rec), throwsStateError);
  });
  test(
    'stop while native install pending drains once installation finishes',
    () async {
      final native = _DelayedNative();
      final rec = ReaderProbeRecorder(
        engine: readerRecorder().engine,
        presentation: native,
      );
      addTearDown(rec.dispose);
      final start = startReader(rec);
      final stopped = rec.stop(reason: 'early_stop');
      await expectLater(startReader(rec), throwsStateError);
      native.installed.complete(UnavailablePresentationProbe.report);
      await start;
      expect((await stopped)!.engine.stopReason, 'early_stop');
      expect(native.stops, 1);
    },
  );
  test('R11 early stop is explicitly incomplete', () async {
    final rec = readerRecorder();
    addTearDown(rec.dispose);
    await startReader(rec, scenario: 'R11');
    expect((await rec.stop())!.omissions['manualMinimumMet'], false);
  });
}

final class _DelayedNative implements PresentationProbe {
  final installed = Completer<PresentationReport>();
  int stops = 0;
  @override
  Future<PresentationReport> install() => installed.future;
  @override
  Future<void> start({
    required String runId,
    required PresentationMode mode,
  }) async {}
  @override
  Future<PresentationReport> stop() async {
    stops++;
    return UnavailablePresentationProbe.report;
  }

  @override
  Future<void> dispose() async {}
}
