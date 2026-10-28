part of 'package:shiori/features/reader/engine/motion/reader_turn_controller.dart';

extension _TurnControllerWork on ReaderTurnController {
  void _idle() {
    if (_closed ||
        _suspended ||
        _recovery != null ||
        _current != null ||
        _pointer != null ||
        _phase == TurnPhase.failed) {
      return;
    }
    final next = _queue.promote();
    if (next != null) {
      _current = next;
      if (next.recognized) _recognize(next);
      final pointer = _waitingPointer;
      if (pointer != null && identical(pointer.intent, next)) {
        _waitingPointer = null;
        _pointer = pointer;
        pointer.engine.rebase(_ruler());
        pointer.latest = pointer.engine.move(pointer.sample);
        _setPhase(TurnPhase.tracking);
        _post(() => _syncDrag(pointer));
      } else {
        _post(() => _run(next));
      }
    } else {
      _setPhase(TurnPhase.idle);
      session.optionalWorkAllowed(true);
    }
  }

  Future<void> _restoreAfter(Future<void> pending) async {
    try {
      await pending;
      if (!_closed && !_suspended) {
        _setPhase(TurnPhase.recovering);
        final ok = await session.restore(_accepted);
        if (!ok) _setPhase(TurnPhase.failed);
      }
    } finally {
      _recovery = null;
      _idle();
    }
  }

  Future<void> _run(
    TurnIntent intent, {
    double start = 0,
    double velocity = 0,
    bool release = false,
  }) async {
    final done = Completer<void>();
    _physicalTurns.add(done.future);
    try {
      await _runOwned(
        intent,
        start: start,
        velocity: velocity,
        release: release,
      );
    } finally {
      _physicalTurns.remove(done.future);
      done.complete();
    }
  }

  Future<void> _runOwned(
    TurnIntent intent, {
    double start = 0,
    double velocity = 0,
    bool release = false,
  }) async {
    final next = intent.direction;
    if (next == null || intent.completed || !identical(_current, intent)) {
      return;
    }
    final token = ++_generation;
    final origin = _accepted;
    final boundary = next == TurnDirection.next ? origin.atEnd : origin.atStart;
    session.optionalWorkAllowed(false);
    _recognize(intent);
    _event(TurnTimingEvent.admitted);
    TurnResult result = const TurnResult(
      TurnResultKind.failed,
      'navigation-error',
    );
    try {
      _setPhase(TurnPhase.preparing);
      PreparedTurn? preview;
      if (!boundary && !reducedMotion) {
        preview = await _prepareDirection(next, token);
      }
      if (!_alive(token, input: intent)) return;
      if (boundary) {
        if (start == 0) _event(TurnTimingEvent.noMotionRequired);
        await _animate(start, 0, (
          duration: PageTurnRules.settleDurationMinMs,
          launch: PageTurnRules.turnLaunch,
        ));
        result = const TurnResult(TurnResultKind.boundary, 'boundary');
      } else {
        if (preview != null) {
          final conflict = TurnAcceptance.previewConflict(origin, preview);
          if (conflict != null) {
            _event(TurnTimingEvent.proofFailed, input: intent);
            result = TurnResult(TurnResultKind.failed, 'proof-$conflict');
            return;
          }
          final target = _sign(next) * width;
          final motion = release
              ? getSettleMotion(
                  remaining: (target - start).abs(),
                  width: width,
                  velocity: math.max(0, velocity * (target - start).sign),
                )
              : (
                  duration: PageTurnRules.tapDurationMs,
                  launch: PageTurnRules.turnLaunch,
                );
          if (!await _animate(start, target, motion) ||
              !_alive(token, input: intent)) {
            return;
          }
        } else {
          _event(
            reducedMotion
                ? TurnTimingEvent.reducedMotion
                : TurnTimingEvent.staticFallback,
          );
          if (!reducedMotion) _staticFallbacks++;
        }
        if (!_alive(token, input: intent)) return;
        _setPhase(TurnPhase.committing);
        _event(TurnTimingEvent.inputCommitted, input: intent);
        final operation = session.navigate(origin, next, preview);
        final pending = operation.then<void>(
          (_) {},
          onError: (Object _, StackTrace _) {},
        );
        _navigation = pending;
        final response = await operation;
        if (!_alive(token, input: intent)) return;
        _navigation = null;
        final destination = response.position;
        String? conflict;
        if (response.kind == TurnNavigationKind.verified &&
            destination != null) {
          conflict = await TurnAcceptance.verify(
            session,
            origin,
            destination,
            preview,
          );
          if (!_alive(token, input: intent)) return;
          _event(
            conflict == null
                ? TurnTimingEvent.proofPassed
                : TurnTimingEvent.proofFailed,
          );
          if (conflict == null) {
            intent.accepted = true;
            _accepted = destination;
            session.accept(destination);
            _event(
              TurnTimingEvent.accepted,
              input: intent,
              destination: destination,
            );
            onAccepted?.call(destination);
            result = const TurnResult(TurnResultKind.committed);
            await onCommitted?.call();
          }
        } else if (response.kind == TurnNavigationKind.boundary &&
            preview == null) {
          result = const TurnResult(TurnResultKind.boundary, 'boundary');
        } else {
          _event(TurnTimingEvent.proofFailed, input: intent);
          conflict = response.reason ?? response.kind.name;
        }
        if (conflict != null) {
          result = TurnResult(TurnResultKind.failed, 'proof-$conflict');
          _terminateWaiting(result);
          _setPhase(TurnPhase.recovering);
          if (!await session.restore(origin)) _setPhase(TurnPhase.failed);
        }
      }
    } on Object catch (error, stack) {
      final sink = timing;
      if (sink is TurnFailureSink) {
        (sink as TurnFailureSink).failure(error, stack);
      }
      result = const TurnResult(TurnResultKind.failed, 'navigation-error');
      _navigation = null;
      if (_alive(token, input: intent)) {
        _terminateWaiting(result);
        if (!intent.accepted && !await session.restore(origin)) {
          _setPhase(TurnPhase.failed);
        }
      }
    } finally {
      intent.resolve(result);
      if (_alive(token, input: intent)) {
        await _controlTask();
        if (_alive(token, input: intent)) {
          _clearPair();
          if (identical(_current, intent)) _current = null;
          if (result.kind == TurnResultKind.failed) _terminateWaiting(result);
          _idle();
        }
      }
    }
  }

  Future<bool> _animate(double from, double to, SettleMotion motion) {
    if (reducedMotion || from == to) {
      _write(to);
      return Future.value(true);
    }
    final animation = TurnMotion(from: from, to: to, motion: motion);
    _motion = animation;
    _write(from);
    _setPhase(TurnPhase.settling);
    return animation.future;
  }

  void _tick() => ReaderWorkGuard.callback(() {
    final motion = _motion;
    if (motion != null) {
      _write(motion.sample(clock.now));
      if (motion.finished) {
        _motion = null;
        _event(TurnTimingEvent.settleEnd);
        _post(() => motion.complete(true));
      }
    } else {
      final pointer = _pointer;
      final latest = pointer?.latest;
      if (pointer == null || latest == null || !_covers(latest)) return;
      var distance = latest.visualDistance;
      final catchUp = pointer.catchUp;
      if (catchUp != null) {
        distance = catchUp.sample(clock.now, distance);
        if (catchUp.finished) pointer.catchUp = null;
      }
      pointer.dirty = false;
      _event(TurnTimingEvent.dragClean, input: pointer.intent);
      _write(distance);
    }
    _refreshDemand();
  });
}
