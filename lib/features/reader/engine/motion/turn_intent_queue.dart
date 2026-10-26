import 'dart:async';
import 'dart:collection';

import 'package:shiori/features/reader/engine/motion/page_turn_engine.dart';

enum TurnResultKind {
  committed,
  boundary,
  cancelled,
  failed,
  blocked,
  queueFull,
  noTurn,
  rebound,
}

final class TurnResult {
  const TurnResult(this.kind, [this.reason]);
  final TurnResultKind kind;
  final String? reason;
}

/// One logical input. Acceptance is irreversible, including during callbacks.
final class TurnIntent {
  TurnIntent(this.direction);
  TurnDirection? direction;
  final Completer<TurnResult> _done = Completer();
  bool accepted = false;
  bool get completed => _done.isCompleted;
  Future<TurnResult> get future => _done.future;

  void resolve(TurnResult result) {
    if (_done.isCompleted) return;
    _done.complete(
      accepted ? const TurnResult(TurnResultKind.committed) : result,
    );
  }
}

/// Current is owned by the controller; only waiting inputs occupy this FIFO.
final class TurnIntentQueue {
  static const capacity = 8;
  final Queue<TurnIntent> _waiting = Queue();
  int get length => _waiting.length;
  bool get isEmpty => _waiting.isEmpty;
  bool get isFull => length >= capacity;

  bool add(TurnIntent intent) {
    if (isFull) {
      intent.resolve(const TurnResult(TurnResultKind.queueFull, 'queue-full'));
      return false;
    }
    _waiting.addLast(intent);
    return true;
  }

  TurnIntent? promote() => isEmpty ? null : _waiting.removeFirst();
  void remove(TurnIntent intent) => _waiting.remove(intent);

  void terminate(TurnResult result) {
    while (_waiting.isNotEmpty) {
      _waiting.removeFirst().resolve(result);
    }
  }
}
