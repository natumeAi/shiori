import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:shiori/core/diagnostics/bounded_ring.dart';
import 'package:shiori/core/diagnostics/diagnostic_recorder.dart';
import 'package:shiori/core/diagnostics/probe_declarations.dart';
import 'package:shiori/features/diagnostics/data/book_digest.dart';
import 'package:shiori/features/diagnostics/data/presentation_probe.dart';
import 'package:shiori/features/diagnostics/data/reader_capture_budget.dart';
import 'package:shiori/features/diagnostics/data/reader_event_buffer.dart';
import 'package:shiori/features/diagnostics/data/reader_feasibility_record.dart';
import 'package:shiori/features/diagnostics/data/reader_probe_summary.dart';
import 'package:shiori/features/reader/engine/motion/turn_session.dart';

/// Composes the unchanged S1 frame collector with reader-owned sink seams.
final class ReaderProbeRecorder
    implements TurnTimingSink, TurnFrameSink, TurnTraceSink, TurnEvidenceSink {
  ReaderProbeRecorder({
    required this.engine,
    this.presentation = const UnavailablePresentationProbe(),
    int capacity = ReaderCaptureBudget.eventCapacity,
  }) : events = ReaderEventBuffer(capacity),
       costs = BoundedRing(
         capacity.clamp(1, ReaderCaptureBudget.auxiliaryCapacity),
       ),
       resources = BoundedRing(
         capacity.clamp(1, ReaderCaptureBudget.auxiliaryCapacity),
       );
  final DiagnosticRecorder engine;
  final PresentationProbe presentation;
  final ReaderEventBuffer events;
  final BoundedRing<Map<String, Object?>> costs;
  final BoundedRing<Map<String, Object?>> resources;
  int _epoch = 0;
  int _firstGeneration = -1;
  final Expando<({int epoch, int id})> _inputs = Expando();
  int _inputSequence = 0;
  (int, int)? _firstInput;
  bool _starting = false;
  String? _pendingStop;
  int _sequence = 0;
  bool _disposed = false;
  @override
  int get frameEpoch => _epoch;
  Completer<ReaderFeasibilityRecord?>? _completion;
  Future<ReaderFeasibilityRecord?> get completed =>
      _completion?.future ?? Future.value(null);

  Future<void> start({
    required String runId,
    required String bookSha256,
    required String? fixtureId,
    required String scenarioId,
    required int repeatIndex,
    required int repeatCount,
    required String input,
    required ProbeDeclarations declarations,
    required Map<String, Object?> metadata,
    PresentationMode mode = PresentationMode.a1,
  }) async {
    if (_disposed ||
        _starting ||
        (_completion != null && !_completion!.isCompleted) ||
        engine.phase == CapturePhase.recording ||
        engine.phase == CapturePhase.draining) {
      throw StateError('Capture busy');
    }
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(bookSha256) ||
        !RegExp(r'^R(0[1-9]|1[01])$').hasMatch(scenarioId) ||
        !{'manual_touch', 'synthetic_injected'}.contains(input) ||
        (scenarioId == 'R11' &&
            (fixtureId != null ||
                input != 'manual_touch' ||
                repeatCount != 1)) ||
        repeatIndex < 1 ||
        repeatIndex > repeatCount) {
      throw ArgumentError('Invalid reader capture identity');
    }
    final epoch = ++_epoch;
    _starting = true;
    _pendingStop = null;
    events.clear();
    costs.clear();
    resources.clear();
    _firstGeneration = -1;
    _sequence = 0;
    _inputSequence = 0;
    _firstInput = null;
    _completion = Completer();
    try {
      await presentation.install();
      if (_disposed || epoch != _epoch) return;
      await presentation.start(runId: runId, mode: mode);
      if (_disposed || epoch != _epoch) return;
      engine.start(
        runId: runId,
        declarations: declarations,
        metadata: {
          ...metadata,
          'readerCorrectnessVersion': 1,
          'readerDemandVersion': 1,
          'captureEpoch': epoch,
          'readerCaptureBudget': ReaderCaptureBudget.describe(
            events: events.capacity,
            auxiliary: costs.capacity,
            engine: engine.capacity,
            maximumMs: engine.maximumDuration.inMilliseconds,
          ),
        },
      );
    } on Object {
      if (_completion case final c? when !c.isCompleted) c.complete(null);
      rethrow;
    } finally {
      _starting = false;
    }
    // Completion follows the S1 duration limit as well as explicit stop.
    unawaited(
      engine.completed
          .then((timing) async {
            if (_disposed || epoch != _epoch || timing == null) return;
            final native = await presentation.stop();
            if (_disposed || epoch != _epoch) return;
            final readerEvents = events.snapshot(seal: true);
            final layoutCosts = costs.snapshot();
            final snapshots = resources.snapshot();
            _completion?.complete(
              ReaderFeasibilityRecord(
                bookSha256: bookSha256,
                fixtureId: fixtureId,
                scenarioId: scenarioId,
                repeatIndex: repeatIndex,
                repeatCount: repeatCount,
                input: input,
                engine: timing.copyWith(scenarioId: scenarioId),
                readerEvents: readerEvents,
                layoutCosts: layoutCosts,
                resources: snapshots,
                presentation: {...native.toJson(), 'mode': mode.name},
                aggregates: ReaderProbeSummary.aggregate(
                  readerEvents,
                  layoutCosts,
                  snapshots,
                ),
                overflow: {
                  'events': events.overflow,
                  'layoutCosts': costs.overflow,
                  'resources': resources.overflow,
                  'frames': timing.frameOverflow,
                  'motion': timing.motionOverflow,
                  'native': native.overflow,
                },
                omissions: {
                  'native': native.omission,
                  'trailingTimingBatch': true,
                  'manualMinimumMet':
                      scenarioId != 'R11' ||
                      readerEvents
                              .where((e) => e['event'] == 'accepted')
                              .length >=
                          50,
                  'physicalPresentation': 'unverified',
                  'touchToPhoton': 'unverified',
                },
              ),
            );
          })
          .catchError((Object error, StackTrace stack) {
            // Channel payload failures must resolve the reader completion with a
            // typed error, rather than strand the capture in its draining UI.
            if (!_disposed && epoch == _epoch) {
              if (_completion case final completion?
                  when !completion.isCompleted) {
                completion.completeError(error, stack);
              }
            }
          }),
    );
    if (_pendingStop case final reason?) unawaited(engine.stop(reason: reason));
  }

  Future<ReaderFeasibilityRecord?> stop({String reason = 'user_stop'}) {
    if (_starting) {
      _pendingStop = reason;
      return completed;
    }
    unawaited(engine.stop(reason: reason));
    return completed;
  }

  @override
  void record(
    TurnTimingEvent event,
    double time,
    int generation,
    int queueDepth,
  ) {
    recordTurn(event, time, generation, queueDepth, null);
  }

  int? _inputId(Object? input) {
    if (input == null) return null;
    return (_inputs[input] ??= (epoch: _epoch, id: ++_inputSequence)).id;
  }

  @override
  void recordTurn(
    TurnTimingEvent event,
    double time,
    int generation,
    int queueDepth,
    Object? input,
  ) {
    recordEvidence(event, time, generation, generation, queueDepth, input);
  }

  @override
  void recordEvidence(
    TurnTimingEvent event,
    double time,
    int generation,
    int activeGeneration,
    int queueDepth,
    Object? input, {
    TurnPosition? destination,
  }) {
    if (engine.phase != CapturePhase.recording || _disposed) return;
    final id = _inputId(input);
    events.add(
      kind: event.index,
      sequence: ++_sequence,
      monotonicUs: engine.clock.monotonicUs,
      value: time,
      generation: generation,
      activeGeneration: activeGeneration,
      epoch: input == null ? _epoch : _inputs[input]?.epoch,
      queueOrFrame: queueDepth,
      inputId: id,
      section: destination?.sectionIndex ?? 0,
      page: destination?.pageIndex ?? 0,
      layoutGeneration: destination?.layoutGeneration ?? 0,
      pageIdentity: destination == null
          ? null
          : sha256Hex(
              Uint8List.fromList(utf8.encode(destination.pageIdentity)),
            ),
    );
  }

  @override
  void submitted({
    required int frameNumber,
    required int schedulerUs,
    required int rawSchedulerUs,
    required int generation,
    required double offset,
    Object? input,
  }) {
    if (engine.phase != CapturePhase.recording || _disposed) return;
    engine.motion(
      frameNumber: frameNumber,
      schedulerUs: schedulerUs,
      rawSchedulerUs: rawSchedulerUs,
      progress: offset,
    );
    final inputId = _inputId(input);
    events.add(
      kind: ReaderEventBuffer.submission,
      sequence: ++_sequence,
      epoch: input == null ? _epoch : _inputs[input]?.epoch,
      monotonicUs: engine.clock.monotonicUs,
      generation: generation,
      queueOrFrame: frameNumber,
      inputId: inputId,
      value: offset,
    );
    final identity = inputId == null
        ? null
        : (_inputs[input!]?.epoch ?? _epoch, inputId);
    if (inputId != null
        ? _firstInput == identity
        : _firstGeneration == generation) {
      return;
    }
    _firstInput = identity;
    _firstGeneration = generation;
    events.add(
      kind: ReaderEventBuffer.firstSubmission,
      sequence: ++_sequence,
      epoch: input == null ? _epoch : _inputs[input]?.epoch,
      monotonicUs: engine.clock.monotonicUs,
      generation: generation,
      queueOrFrame: frameNumber,
      inputId: inputId,
    );
  }

  void layout({
    required int section,
    required int layoutUs,
    required int codeUnits,
    required int lines,
    required int pageCount,
  }) {
    if (engine.phase != CapturePhase.recording || _disposed) return;
    costs.add({
      'monotonicUs': engine.clock.monotonicUs,
      'section': section,
      'layoutUs': layoutUs,
      'codeUnits': codeUnits,
      'lines': lines,
      'sectionPageCount': pageCount,
    });
  }

  void preparation({
    required bool start,
    required int section,
    required bool cacheHit,
  }) {
    if (engine.phase != CapturePhase.recording || _disposed) return;
    events.add(
      kind: start
          ? ReaderEventBuffer.preparationStart
          : ReaderEventBuffer.preparationEnd,
      sequence: ++_sequence,
      monotonicUs: engine.clock.monotonicUs,
      section: section,
      cacheHit: cacheHit,
    );
  }

  void memory({
    required int liveSurfaces,
    required int pictureBytes,
    required int imageBytes,
    required int rssBytes,
  }) {
    if (engine.phase != CapturePhase.recording || _disposed) return;
    resources.add({
      'monotonicUs': engine.clock.monotonicUs,
      'liveSurfaces': liveSurfaces,
      'pictureBytes': pictureBytes,
      'imageBytes': imageBytes,
      'rssBytes': rssBytes,
    });
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_epoch;
    engine.dispose();
    if (_completion case final c? when !c.isCompleted) c.complete(null);
    events.dispose();
    costs.clear();
    resources.clear();
    unawaited(presentation.dispose());
  }
}
