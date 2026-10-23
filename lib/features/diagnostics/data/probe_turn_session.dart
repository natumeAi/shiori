import 'dart:async';

import 'package:shiori/features/reader/engine/motion/page_turn_engine.dart';
import 'package:shiori/features/reader/engine/motion/turn_session.dart';
import 'package:shiori/features/reader/engine/surface/prepared_reader_session.dart';

/// Probe-only delayed preparation; all navigation and proofs use the engine.
final class ProbeTurnSession implements TurnSession {
  ProbeTurnSession(this.inner);
  final PreparedReaderSession inner;
  Completer<void>? _barrier;
  Completer<void>? _entered;
  void hold() {
    if (_barrier != null) throw StateError('Preparation already held');
    _barrier = Completer();
    _entered = Completer();
  }

  Future<void> get preparationEntered => _entered?.future ?? Future.value();
  void release() {
    final barrier = _barrier;
    _barrier = null;
    if (barrier != null && !barrier.isCompleted) barrier.complete();
  }

  @override
  TurnSessionState get state => inner.state;
  @override
  Future<void> stopAndDrain() => inner.stopAndDrain();
  @override
  void optionalWorkAllowed(bool allowed) => inner.optionalWorkAllowed(allowed);
  @override
  PreparedTurn? ready(TurnPosition origin, TurnDirection direction) =>
      inner.ready(origin, direction);
  @override
  Future<PreparedTurn?> prepare(
    TurnPosition origin,
    TurnDirection direction,
  ) async {
    final barrier = _barrier;
    if (barrier != null) {
      if (_entered case final entered? when !entered.isCompleted) {
        entered.complete();
      }
      await barrier.future;
    }
    return inner.prepare(origin, direction);
  }

  @override
  void bind(TurnPosition origin, List<PreparedTurn> neighbors) =>
      inner.bind(origin, neighbors);
  @override
  void unbind() => inner.unbind();
  @override
  Future<TurnNavigation> navigate(
    TurnPosition origin,
    TurnDirection direction,
    PreparedTurn? preview,
  ) => inner.navigate(origin, direction, preview);
  @override
  Future<bool> prove(TurnPosition position, {PreparedTurn? preview}) =>
      inner.prove(position, preview: preview);
  @override
  void accept(TurnPosition position) => inner.accept(position);
  @override
  Future<bool> restore(TurnPosition origin) => inner.restore(origin);
}
