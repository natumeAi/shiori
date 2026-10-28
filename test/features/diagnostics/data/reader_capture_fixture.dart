import 'dart:collection';

import 'package:shiori/core/diagnostics/diagnostic_recorder.dart';
import 'package:shiori/core/diagnostics/probe_declarations.dart';
import 'package:shiori/features/diagnostics/data/presentation_probe.dart';
import 'package:shiori/features/diagnostics/data/reader_capture_budget.dart';
import 'package:shiori/features/diagnostics/data/reader_probe_recorder.dart';
import 'package:shiori/features/reader/engine/motion/turn_session.dart';

import '../../../helpers/diagnostics_fixtures.dart';
import '../../../helpers/reader_probe_fixtures.dart' show readerDigest;

/// Extends recognized-demand fake timelines with six dirty-frame events,
/// cold barriers, held/reverse input and committed destinations.
final class CaptureFixture {
  final clock = DiagnosticTestClock();
  final source = DiagnosticTestFrameSource();
  final native = NativeCapacityModel();
  late final recorder = ReaderProbeRecorder(
    engine: DiagnosticRecorder(
      clock: clock,
      source: source,
      capacity: ReaderCaptureBudget.engineCapacity,
      maximumDuration: ReaderCaptureBudget.maximumDuration,
      drainDuration: Duration.zero,
    ),
    presentation: native,
  );
  int frame = 0;

  Future<void> start(int repeat, {String scenario = 'R10'}) async {
    frame = 0;
    await recorder.start(
      runId: 'capture-$scenario-$repeat',
      bookSha256: readerDigest,
      fixtureId: 'synthetic-capture',
      scenarioId: scenario,
      repeatIndex: repeat,
      repeatCount: 3,
      input: 'synthetic_injected',
      declarations: const ProbeDeclarations(),
      metadata: const {
        'resourceCaps': {
          'liveSurfaceCap': 3,
          'liveSurfaceReserve': 1,
          'pictureCacheBytes': 1000,
          'imageCacheBytes': 1000,
        },
      },
      mode: PresentationMode.a2,
    );
    memory();
  }

  void memory() => recorder.memory(
    liveSurfaces: 2,
    pictureBytes: 100,
    imageBytes: 100,
    rssBytes: 100000000,
  );

  void turn(
    int index, {
    int frames = 50,
    String variant = 'warm',
    bool alternating = true,
  }) {
    final input = Object();
    void event(TurnTimingEvent kind) => recorder.recordEvidence(
      kind,
      (clock.monotonicUs - 7000000) / 1000,
      index,
      index,
      0,
      input,
    );
    event(TurnTimingEvent.inputReceived);
    event(TurnTimingEvent.pointerAdmitted);
    event(TurnTimingEvent.inputRecognized);
    if (variant == 'cold') {
      event(TurnTimingEvent.preparationMiss);
      event(TurnTimingEvent.preparationBarrierStart);
      recorder.preparation(start: true, section: 0, cacheHit: false);
      recorder.layout(
        section: 0,
        layoutUs: 1000,
        codeUnits: 100000,
        lines: 1000,
        pageCount: 3001,
      );
      clock.advance(const Duration(milliseconds: 20));
      recorder.preparation(start: false, section: 0, cacheHit: false);
      event(TurnTimingEvent.preparationBarrierEnd);
    }
    event(TurnTimingEvent.recognizedAdmission);
    event(TurnTimingEvent.admitted);
    for (var i = 0; i < frames; i++) {
      event(TurnTimingEvent.frameDemandStart);
      event(TurnTimingEvent.dragDirty);
      if (variant == 'held') event(TurnTimingEvent.holdStart);
      event(TurnTimingEvent.visualMutation);
      clock.advance(const Duration(microseconds: 8333));
      event(TurnTimingEvent.dragClean);
      recorder.submitted(
        frameNumber: ++frame,
        schedulerUs: frame * 8333,
        rawSchedulerUs: frame * 8333,
        generation: index,
        offset:
            (variant == 'reverse' || alternating && index.isOdd ? -1 : 1) *
            (i + 1.0),
        input: input,
      );
      event(TurnTimingEvent.frameDemandEnd);
      if (variant == 'held') event(TurnTimingEvent.holdEnd);
      source.emit([diagnosticTiming(frame * 8333, frameNumber: frame)]);
      native.frames++;
    }
    event(TurnTimingEvent.settleEnd);
    event(TurnTimingEvent.inputCommitted);
    event(TurnTimingEvent.proofPassed);
    final page = alternating ? (index.isEven ? 1 : 0) : index + 1;
    recorder.recordEvidence(
      TurnTimingEvent.accepted,
      0,
      index,
      index,
      0,
      input,
      destination: TurnPosition(
        cfi: 'not exported',
        layoutKey: 'not exported',
        layoutGeneration: 1,
        sectionIndex: 0,
        pageIndex: page,
        pageCount: 4097,
        pageIdentity: 'synthetic-$page',
        atStart: page == 0,
        atEnd: false,
      ),
    );
    memory();
  }
}

/// Deterministic capacity model, NOT Swift compilation or contention proof.
/// Two native samples per submitted frame; maps materialize after stop.
final class NativeCapacityModel implements PresentationProbe {
  int frames = 0, stops = 0;
  @override
  Future<PresentationReport> install() async =>
      UnavailablePresentationProbe.report;
  @override
  Future<void> start({
    required String runId,
    required PresentationMode mode,
  }) async {
    frames = 0;
  }

  @override
  Future<PresentationReport> stop() async {
    stops++;
    final count = frames * 2;
    return PresentationReport(
      available: true,
      evidence: PresentationMode.a2.evidence,
      omission: null,
      lossAccountingVersion: 1,
      inventory: const {
        'ringCapacity': ReaderCaptureBudget.nativeCapacity,
        'captureBudgetVersion': 1,
        'layerClass': 'FlutterMetalLayer',
      },
      samples: _NativeSamples(
        count.clamp(0, ReaderCaptureBudget.nativeCapacity),
      ),
      overflow: (count - ReaderCaptureBudget.nativeCapacity).clamp(0, count),
    );
  }

  @override
  Future<void> dispose() async {}
}

final class _NativeSamples extends ListBase<Map<String, Object?>> {
  _NativeSamples(this.length);
  @override
  final int length;
  @override
  set length(int value) => throw UnsupportedError('immutable');
  @override
  void operator []=(int index, Map<String, Object?> value) =>
      throw UnsupportedError('immutable');
  @override
  Map<String, Object?> operator [](int index) {
    RangeError.checkValidIndex(index, this);
    final timestamp = 10 + (index ~/ 2) / 120;
    return index.isEven
        ? {'kind': 'layer_commit', 'timestamp': timestamp}
        : {
            'kind': 'display_link',
            'timestamp': timestamp,
            'targetTimestamp': timestamp + 1 / 120,
          };
  }
}
