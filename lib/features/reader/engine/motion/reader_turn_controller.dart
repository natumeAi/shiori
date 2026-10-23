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

  TurnPosition get accepted => _accepted;
  TurnPhase get phase => _phase;
  double get offset => _offset;
  int get queueDepth => _queue.length;
  int get staticFallbacks => _staticFallbacks;
  int get generation => _generation;
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

  bool _alive(int token) => !_closed && !_suspended && token == _generation;
  void _event(TurnTimingEvent event) =>
      timing?.record(event, clock.now, _generation, _queue.length);
  void _setPhase(TurnPhase value) {
    _phase = value;
    onChanged?.call();
  }

  void _write(double value) {
    _offset = value;
    onOffset?.call(value);
  }

  Future<TurnResult> turnPage(TurnDirection direction) {
    final intent = TurnIntent(direction);
    if (_blocked) {
      intent.resolve(const TurnResult(TurnResultKind.blocked, 'not-ready'));
    } else if (_current != null || _pointer != null || !_queue.isEmpty) {
      if (_queue.add(intent)) {
        _event(TurnTimingEvent.queued);
      } else {
        _event(TurnTimingEvent.overflow);
      }
    } else {
      _current = intent;
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
    _motion?.complete(false);
    _motion = null;
    _pointer?.engine.cancel();
    _pointer = null;
    _waitingPointer?.engine.cancel();
    _waitingPointer = null;
    final result = TurnResult(TurnResultKind.cancelled, reason);
    _terminateWaiting(result);
    _current?.resolve(result);
    _current = null;
    _event(TurnTimingEvent.cancelled);
    _post(() {
      _clearPair();
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
}
