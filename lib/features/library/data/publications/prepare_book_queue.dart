import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'prepare_book_queue.g.dart';

/// Holds the staging/worker slot through import, detach and publication cleanup,
/// including across retirement and activation of a replacement service.
final class PrepareBookQueue {
  Future<void> _tail = Future.value();

  Future<T> run<T>(Future<T> Function() action) async {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    await previous;
    try {
      return await action();
    } finally {
      done.complete();
    }
  }
}

@Riverpod(keepAlive: true)
PrepareBookQueue prepareBookQueue(Ref ref) => PrepareBookQueue();
