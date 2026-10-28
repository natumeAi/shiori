import 'dart:async';
import 'dart:math' as math;

import 'package:shiori/features/reader/data/source/reader_work_guard.dart';
import 'package:shiori/features/reader/engine/motion/page_turn_engine.dart';
import 'package:shiori/features/reader/engine/motion/page_turn_gesture.dart';
import 'package:shiori/features/reader/engine/motion/turn_acceptance.dart';
import 'package:shiori/features/reader/engine/motion/turn_clock.dart';
import 'package:shiori/features/reader/engine/motion/turn_intent_queue.dart';
import 'package:shiori/features/reader/engine/motion/turn_motion.dart';
import 'package:shiori/features/reader/engine/motion/turn_session.dart';

part 'package:shiori/features/reader/engine/motion/turn_controller_work.dart';
part 'package:shiori/features/reader/engine/motion/turn_controller_pointer.dart';
part 'package:shiori/features/reader/engine/motion/turn_controller_drag.dart';

enum TurnPhase {
  idle,
  tracking,
  dragging,
  preparing,
  settling,
  committing,
  recovering,
  suspended,
  failed,
  closed,
}

/// Session-local admission and acceptance. Only numeric state changes in ticks.
final class ReaderTurnController {
  ReaderTurnController({
    required this.session,
    required TurnPosition initial,
    required this.clock,
    required this.width,
    this.readingDirection = ReadingDirection.ltr,
    this.onOffset,
    this.onChanged,
    this.onAccepted,
    this.onCenterTap,
    this.onTap,
    this.onCommitted,
    this.timing,
    this.preparationTimeout = const Duration(milliseconds: 2500),
  }) : _accepted = initial,
       _controlZone = Zone.current;

  final TurnSession session;
  final TurnClock clock;
  final ReadingDirection readingDirection;
  final Duration preparationTimeout;
  final Zone _controlZone;
  final TurnTimingSink? timing;
  void Function(double)? onOffset;
  void Function()? onChanged;
  final void Function(TurnPosition)? onAccepted;
  final void Function()? onCenterTap;
  final bool Function(double, double)? onTap;
  final Future<void> Function()? onCommitted;
  double width;
  double _offset = 0;
  TurnPosition _accepted;
  TurnPhase _phase = TurnPhase.idle;
  final TurnIntentQueue _queue = TurnIntentQueue();
  TurnIntent? _current;
  _TurnPointer? _pointer;
  _TurnPointer? _waitingPointer;
  TurnMotion? _motion;
  final Map<TurnDirection, PreparedTurn> _neighbors = {};
  bool _bound = false;
  bool _disabled = false;
  bool reducedMotion = false;
  bool _closed = false;
  bool _suspended = false;
  int _generation = 0;
  int _pairGeneration = 0;
  int _staticFallbacks = 0;
  Future<void>? _navigation;
  Future<void>? _recovery;
  final Set<Future<void>> _physicalTurns = {};
  Future<void>? _closing;
  bool _demanding = false, _holding = false;

  TurnPosition get accepted => _accepted;
  TurnPhase get phase => _phase;
  double get offset => _offset;
  int get queueDepth => _queue.length;
  int get staticFallbacks => _staticFallbacks;
  int get generation => _generation;
  Object? get inputIdentity => _current;
  void tick() => _tick();
  bool pointerDown(
    int id,
    GestureInput input, {
    bool primary = true,
    bool mouse = false,
    int button = 0,
  }) => _pointerDown(id, input, primary: primary, mouse: mouse, button: button);
  bool pointerMove(int id, GestureInput input) => _pointerMove(id, input);
  Future<TurnResult>? pointerUp(int id, GestureInput input) =>
      _pointerUp(id, input);
  void pointerCancel(int id, [String reason = 'pointercancel']) =>
      _post(() => _pointerCancel(id, reason));
  bool get needsTick =>
      _motion != null ||
      (_pointer?.latest?.phase == GesturePhase.dragging &&
          _bound &&
          (_pointer!.dirty || _pointer!.catchUp != null));
  bool get _blocked =>
      _closed ||
      _suspended ||
      _disabled ||
      _recovery != null ||
      _phase == TurnPhase.failed ||
      (session.state != TurnSessionState.ready &&
          !(session.state == TurnSessionState.handoff && _current != null));

  void _terminateWaiting(TurnResult result) {
    _waitingPointer?.engine.cancel();
    _waitingPointer = null;
    _queue.terminate(result);
  }

  void _post(void Function() task) => _controlZone.run(() => clock.post(task));
  Future<void> _controlTask() {
    final done = Completer<void>();
    _post(done.complete);
    return done.future;
  }

  bool _alive(int token, {Object? input}) {
    final alive = !_closed && !_suspended && token == _generation;
    if (!alive) {
      _event(
        TurnTimingEvent.staleCallbackRejected,
        input: input,
        generation: token,
      );
    }
    return alive;
  }

  void _event(
    TurnTimingEvent event, {
    Object? input,
    int? generation,
    TurnPosition? destination,
  }) {
    final sink = timing;
    if (sink is TurnEvidenceSink) {
      (sink as TurnEvidenceSink).recordEvidence(
        event,
        clock.now,
        generation ?? _generation,
        _generation,
        _queue.length,
        input ?? _current,
        destination: destination,
      );
    } else if (sink is TurnTraceSink) {
      (sink as TurnTraceSink).recordTurn(
        event,
        clock.now,
        generation ?? _generation,
        _queue.length,
        input ?? _current,
      );
    } else {
      sink?.record(event, clock.now, generation ?? _generation, _queue.length);
    }
  }

  void _setPhase(TurnPhase value) {
    _phase = value;
    _refreshDemand();
    onChanged?.call();
  }

  void _recognize(TurnIntent intent) {
    if (!intent.recognized) {
      intent.recognized = true;
      _event(TurnTimingEvent.inputRecognized, input: intent);
    }
    if (identical(intent, _current) && !intent.recognizedAdmitted) {
      intent.recognizedAdmitted = true;
      _event(TurnTimingEvent.recognizedAdmission, input: intent);
    }
  }

  // Actual controller demand, independent of frame callback delivery.
  void _refreshDemand() {
    final demand = needsTick;
    final hold =
        !demand && _bound && _pointer?.latest?.phase == GesturePhase.dragging;
    if (_holding && !hold) _event(TurnTimingEvent.holdEnd);
    if (_demanding != demand) {
      _event(
        demand
            ? TurnTimingEvent.frameDemandStart
            : TurnTimingEvent.frameDemandEnd,
      );
    }
    if (!_holding && hold) _event(TurnTimingEvent.holdStart);
    _demanding = demand;
    _holding = hold;
  }

  void _write(double value) {
    if (_offset == value) return;
    _offset = value;
    _event(TurnTimingEvent.visualMutation);
    onOffset?.call(value);
  }

  Future<TurnResult> turnPage(TurnDirection direction) {
    final intent = TurnIntent(direction);
    _event(TurnTimingEvent.inputReceived, input: intent);
    _recognize(intent);
    if (_blocked) {
      _event(TurnTimingEvent.rejected, input: intent);
      intent.resolve(const TurnResult(TurnResultKind.blocked, 'not-ready'));
    } else if (_current != null || _pointer != null || !_queue.isEmpty) {
      if (_queue.add(intent)) {
        _event(TurnTimingEvent.queued, input: intent);
      } else {
        _event(TurnTimingEvent.overflow, input: intent);
      }
    } else {
      _current = intent;
      _recognize(intent);
      _post(() => _run(intent));
    }
    return intent.future;
  }

  void configure({bool? disabled, bool? reducedMotion}) {
    if (reducedMotion != null) this.reducedMotion = reducedMotion;
    if (disabled != null) {
      _disabled = disabled;
      if (disabled) cancel('disabled');
    }
  }

  void cancel([String reason = 'cancelled']) {
    ++_generation;
    final preparation = switch (session) {
      final TurnPreparationInvalidation owner => owner,
      _ => null,
    };
    preparation?.invalidatePreparation();
    _event(TurnTimingEvent.generationInvalidated);
    _motion?.complete(false);
    _motion = null;
    _pointer?.engine.cancel();
    if (_pointer?.dirty == true) _event(TurnTimingEvent.dragClean);
    _pointer = null;
    _refreshDemand();
    _waitingPointer?.engine.cancel();
    _waitingPointer = null;
    final result = TurnResult(TurnResultKind.cancelled, reason);
    _terminateWaiting(result);
    _current?.resolve(result);
    _event(TurnTimingEvent.cancelled);
    _current = null;
    _post(() {
      final wasBound = _bound;
      _clearPair();
      if (!wasBound && preparation != null) {
        session.unbind();
      }
      _event(TurnTimingEvent.queueClosed);
      final navigation = _navigation;
      if (navigation != null) {
        _recovery ??= _restoreAfter(navigation);
      } else {
        _idle();
      }
    });
  }

  void settingsChanged() => cancel('settings');
  void layoutChanged({double? width}) {
    cancel('layout');
    if (width != null) this.width = width;
  }

  void suspend() {
    _suspended = true;
    cancel('background');
    _setPhase(TurnPhase.suspended);
  }

  Future<void> resume() async {
    if (_closed) return;
    await _recovery;
    _suspended = false;
    final token = ++_generation;
    final restored = await session.restore(_accepted);
    if (_alive(token)) {
      _setPhase(restored ? TurnPhase.idle : TurnPhase.failed);
    }
  }

  void close() {
    if (_closed) return;
    cancel('close');
    _closed = true;
    _setPhase(TurnPhase.closed);
  }

  /// Reader teardown uses this barrier before disposing scenes or detaching
  /// the worker. Logical TurnResult cancellation alone does not drain work.
  Future<void> closeAndDrain() => _closing ??= _closeAndDrain();

  Future<void> _closeAndDrain() async {
    close();
    await _controlTask();
    await session.stopAndDrain();
    while (_physicalTurns.isNotEmpty) {
      await Future.wait(_physicalTurns.toList());
    }
    await _navigation;
    await _recovery;
    await _controlTask();
  }
}
