part of 'package:shiori/features/reader/engine/motion/reader_turn_controller.dart';

final class _TurnPointer {
  _TurnPointer(this.id, this.engine, this.sample, this.intent);
  final int id;
  final PageTurnEngine engine;
  final TurnIntent intent;
  GestureInput sample;
  GestureMove? latest;
  DragCatchUp? catchUp;
  bool dirty = false;
  bool preparing = false;
}

extension _TurnControllerPointer on ReaderTurnController {
  GestureSnapshot _ruler({bool waiting = false}) => GestureSnapshot(
    width: width,
    direction: readingDirection,
    canPrevious: waiting || !_accepted.atStart,
    canNext: waiting || !_accepted.atEnd,
  );

  bool _pointerDown(
    int id,
    GestureInput sample, {
    bool primary = true,
    bool mouse = false,
    int button = 0,
  }) => ReaderWorkGuard.callback(() {
    final intent = TurnIntent(null);
    _event(TurnTimingEvent.inputReceived, input: intent);
    if (_blocked ||
        !primary ||
        button != 0 ||
        _pointer != null ||
        _waitingPointer != null) {
      _event(TurnTimingEvent.rejected, input: intent);
      return false;
    }
    if (!mouse && (sample.x < 20 || sample.x > width - 20)) {
      _event(TurnTimingEvent.rejected, input: intent);
      return false;
    }
    final waiting = _current != null || !_queue.isEmpty;
    if (waiting && !_queue.add(intent)) {
      _post(() => _event(TurnTimingEvent.overflow, input: intent));
      return false;
    }
    final engine = PageTurnEngine(_ruler(waiting: waiting))..begin(sample);
    final pointer = _TurnPointer(id, engine, sample, intent);
    if (waiting) {
      _event(TurnTimingEvent.queued, input: intent);
      _waitingPointer = pointer;
    } else {
      _event(TurnTimingEvent.pointerAdmitted, input: intent);
      _pointer = pointer;
      _current = intent;
      _post(() {
        if (_pointer != pointer) return;
        session.optionalWorkAllowed(false);
        _setPhase(TurnPhase.tracking);
        _admitWarm(pointer);
      });
    }
    return true;
  });

  bool _pointerMove(int id, GestureInput sample) =>
      ReaderWorkGuard.callback(() {
        final pointer = _pointer?.id == id
            ? _pointer
            : _waitingPointer?.id == id
            ? _waitingPointer
            : null;
        if (pointer == null) return false;
        pointer.sample = sample;
        final previous = pointer.latest;
        final latest = pointer.engine.move(sample);
        pointer.latest = latest;
        if (latest.phase == GesturePhase.cancelled) {
          _post(() => _pointerCancel(id, 'vertical'));
          return false;
        }
        if (latest.phase != GesturePhase.dragging) return false;
        _recognize(pointer.intent);
        pointer.dirty = true;
        _event(TurnTimingEvent.dragDirty, input: pointer.intent);
        _refreshDemand();
        if (identical(_pointer, pointer)) {
          _post(() {
            if (identical(_pointer, pointer)) {
              if (previous?.direction != latest.direction || !_covers(latest)) {
                _syncDrag(pointer);
              }
              onChanged?.call();
            }
          });
        }
        return true;
      });

  Future<TurnResult>? _pointerUp(int id, GestureInput sample) =>
      ReaderWorkGuard.callback(() {
        final waiting = _waitingPointer?.id == id;
        final pointer = waiting
            ? _waitingPointer
            : _pointer?.id == id
            ? _pointer
            : null;
        if (pointer == null) return null;
        if (waiting) {
          _waitingPointer = null;
        } else {
          _pointer = null;
        }
        if (pointer.dirty) {
          _event(TurnTimingEvent.dragClean, input: pointer.intent);
        }
        final released = pointer.engine.release(sample);
        final rendered = _offset;
        final zone = released.kind == ReleaseKind.tap
            ? getTapZone(sample.x, 0, width)
            : null;
        final next = released.kind == ReleaseKind.commit
            ? released.direction
            : zone == TapZone.previous
            ? TurnDirection.previous
            : zone == TapZone.next
            ? TurnDirection.next
            : null;
        pointer.intent.direction = next;
        if (released.kind == ReleaseKind.tap && next != null) {
          _recognize(pointer.intent);
        }
        _refreshDemand();
        _post(() async {
          if (pointer.intent.completed) return;
          if (released.kind == ReleaseKind.tap &&
              !waiting &&
              _queue.isEmpty &&
              (onTap?.call(sample.x, sample.y) ?? false)) {
            pointer.intent.resolve(
              const TurnResult(TurnResultKind.noTurn, 'image'),
            );
            _clearPair();
            _current = null;
            _idle();
            return;
          }
          if (next != null) {
            if (!waiting) {
              await _run(
                pointer.intent,
                start: rendered,
                velocity: released.velocity,
                release: released.kind == ReleaseKind.commit,
              );
            }
          } else {
            if (waiting) {
              _queue.remove(pointer.intent);
            } else if (released.kind == ReleaseKind.rebound) {
              await _animate(
                rendered,
                0,
                getSettleMotion(
                  remaining: rendered.abs(),
                  width: width,
                  velocity: math.max(0, -rendered.sign * released.velocity),
                ),
              );
            }
            pointer.intent.resolve(
              TurnResult(
                released.kind == ReleaseKind.rebound
                    ? TurnResultKind.rebound
                    : TurnResultKind.noTurn,
              ),
            );
            if (!waiting && identical(_current, pointer.intent)) {
              _clearPair();
              _current = null;
              if (zone == TapZone.center) {
                onCenterTap?.call();
              }
              _idle();
            }
          }
        });
        return pointer.intent.future;
      });

  void _pointerCancel(int id, String reason) {
    if (_waitingPointer?.id == id) {
      final pointer = _waitingPointer!;
      _waitingPointer = null;
      _queue.remove(pointer.intent);
      pointer.engine.cancel();
      _event(TurnTimingEvent.dragClean, input: pointer.intent);
      _event(TurnTimingEvent.cancelled, input: pointer.intent);
      pointer.intent.resolve(TurnResult(TurnResultKind.cancelled, reason));
    } else if (_pointer?.id == id) {
      cancel(reason);
    }
  }
}
