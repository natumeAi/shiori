part of 'package:shiori/features/reader/engine/motion/reader_turn_controller.dart';

extension _TurnControllerDrag on ReaderTurnController {
  double _sign(TurnDirection direction) =>
      (direction == TurnDirection.next) !=
          (readingDirection == ReadingDirection.rtl)
      ? -1.0
      : 1.0;
  bool _covers(GestureMove move) =>
      _bound && (move.boundary || _neighbors.containsKey(move.direction));

  void _clearPair() {
    ++_pairGeneration;
    _write(0);
    if (_bound) session.unbind();
    _bound = false;
    for (final preview in _neighbors.values) {
      preview.release();
    }
    _neighbors.clear();
  }

  Future<T?> _bounded<T>(Future<T?> work) {
    final done = Completer<T?>();
    final cancelTimeout = _controlZone.run(
      () => clock.after(preparationTimeout, () {
        if (!done.isCompleted) done.complete(null);
      }),
    );
    work.then(
      (value) {
        cancelTimeout();
        if (!done.isCompleted) {
          done.complete(value);
        } else if (value is PreparedTurn) {
          _post(value.release);
        }
      },
      onError: (Object _, StackTrace _) {
        cancelTimeout();
        if (!done.isCompleted) done.complete(null);
      },
    );
    return done.future;
  }

  Future<PreparedTurn?> _prepareDirection(TurnDirection next, int token) async {
    final existing = _neighbors[next];
    if (existing != null && _bound) return existing;
    // A cold reversal first parks the foreground in a control task.
    if (_bound) _clearPair();
    final epoch = _pairGeneration;
    final origin = _accepted;
    final prepared = await _bounded(session.prepare(origin, next));
    if (prepared == null) return null;
    if (!_alive(token) || epoch != _pairGeneration) {
      prepared.release();
      return null;
    }
    await session.stopAndDrain();
    await _controlTask();
    if (!_alive(token) || epoch != _pairGeneration) {
      prepared.release();
      return null;
    }
    _neighbors[next] = prepared;
    session.bind(origin, _neighbors.values.toList());
    _bound = true;
    _event(TurnTimingEvent.prepared);
    return prepared;
  }

  Future<void> _admitWarm(_TurnPointer pointer) async {
    final token = _generation;
    final epoch = _pairGeneration;
    final warm = <PreparedTurn>[];
    for (final direction in TurnDirection.values) {
      final preview = session.ready(_accepted, direction);
      if (preview != null) warm.add(preview);
    }
    if (warm.isEmpty) return;
    pointer.preparing = true;
    try {
      await session.stopAndDrain();
      await _controlTask();
      if (!_alive(token) || _pointer != pointer || epoch != _pairGeneration) {
        for (final preview in warm) {
          preview.release();
        }
        return;
      }
      for (final preview in warm) {
        _neighbors[preview.direction] = preview;
      }
      session.bind(_accepted, warm);
      _bound = true;
      pointer.dirty = true;
      onChanged?.call();
    } finally {
      pointer.preparing = false;
      final latest = pointer.latest;
      if (_pointer == pointer &&
          latest?.phase == GesturePhase.dragging &&
          !_covers(latest!)) {
        _post(() => _syncDrag(pointer));
      }
    }
  }

  Future<void> _syncDrag(_TurnPointer pointer) async {
    if (!identical(pointer, _pointer) || pointer.preparing) return;
    final latest = pointer.latest;
    if (latest?.phase != GesturePhase.dragging) return;
    pointer.preparing = true;
    try {
      _setPhase(TurnPhase.dragging);
      if (_covers(latest!)) {
        pointer.dirty = true;
        return;
      }
      if (latest.boundary) {
        await session.stopAndDrain();
        await _controlTask();
        if (_pointer != pointer) return;
        session.bind(_accepted, const []);
        _bound = true;
      } else {
        final token = _generation;
        final preview = await _prepareDirection(latest.direction!, token);
        if (_pointer != pointer || !_alive(token) || preview == null) return;
        pointer.catchUp = DragCatchUp(_offset);
      }
      pointer.dirty = true;
      onChanged?.call();
    } finally {
      pointer.preparing = false;
      final newest = pointer.latest;
      if (_pointer == pointer &&
          newest?.phase == GesturePhase.dragging &&
          newest?.direction != latest?.direction) {
        _post(() => _syncDrag(pointer));
      }
    }
  }
}
