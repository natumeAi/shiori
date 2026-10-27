import 'dart:async';

import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/core/config/session_publication_guard.dart';
import 'package:shiori/core/network/request_cancelled.dart';

/// Feature work completes silently on retirement, even if a dependency stalls.
final class LibrarySessionScope {
  LibrarySessionScope(this.session, this.guard) {
    _unregister = guard.onRetire(session, dispose);
  }

  final ServerSession session;
  final SessionPublicationGuard guard;
  final Set<Completer<void>> _waiters = {};
  bool _disposed = false;
  void Function()? _unregister;

  void check() {
    if (_disposed || !guard.isCurrent(session)) {
      throw const RequestCancelled();
    }
  }

  Future<T> wait<T>(Future<T> operation) async {
    final retired = Completer<void>();
    if (_disposed) {
      retired.complete();
    } else {
      _waiters.add(retired);
    }
    try {
      final value = await Future.any([
        operation,
        retired.future.then<T>((_) => throw const RequestCancelled()),
      ]);
      check();
      return value;
    } catch (_) {
      check();
      rethrow;
    } finally {
      _waiters.remove(retired);
    }
  }

  bool publish(void Function() action) {
    if (_disposed) return false;
    return guard.publish(session, action);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final waiter in _waiters) {
      waiter.complete();
    }
    _waiters.clear();
    _unregister?.call();
  }
}
