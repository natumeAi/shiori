import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/core/config/session_publication_guard.dart';
import 'package:shiori/core/network/request_cancelled.dart';
import 'package:shiori/features/reader/data/worker/publication_worker.dart';
import 'package:shiori/features/servers/data/server_activation_dependencies.dart';

part 'session_publication_worker.g.dart';

/// One lazy worker per active session. Retirement also covers spawn in flight.
final class SessionPublicationWorker {
  SessionPublicationWorker(
    this.session,
    this.guard, {
    Future<PublicationWorker> Function()? spawn,
  }) : _spawn = spawn ?? PublicationWorker.spawn {
    _unregister = guard.onRetire(session, dispose);
  }
  final ServerSession session;
  final SessionPublicationGuard guard;
  final Future<PublicationWorker> Function() _spawn;
  Future<PublicationWorker>? _worker;
  PublicationWorker? _value;
  Future<void>? _closing;
  bool _disposed = false;
  void Function()? _unregister;

  Future<PublicationWorker> get() async {
    if (_disposed || !guard.isCurrent(session)) throw const RequestCancelled();
    if (_value?.isClosed ?? false) {
      _value = null;
      _worker = null;
    }
    final pending = _worker ??= _spawn();
    try {
      final worker = await pending;
      if (_disposed || !guard.isCurrent(session)) {
        await worker.close();
        throw const RequestCancelled();
      }
      return _value = worker;
    } on Object {
      if (identical(_worker, pending)) _worker = null;
      rethrow;
    }
  }

  Future<void> get closed => _closing ?? Future.value();

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _unregister?.call();
    _closing = _close();
    unawaited(_closing);
  }

  Future<void> _close() async {
    try {
      await (await _worker)?.close();
    } on Object {
      // Closing is best effort after a worker exit/spawn failure. Its callers
      // already receive a typed worker failure; retirement must never throw.
      return;
    }
  }
}

@Riverpod(keepAlive: true)
SessionPublicationWorker sessionPublicationWorker(
  Ref ref,
  ServerSession session,
) {
  final owner = SessionPublicationWorker(
    session,
    ref.watch(sessionPublicationGuardProvider),
  );
  ref.onDispose(owner.dispose);
  return owner;
}
