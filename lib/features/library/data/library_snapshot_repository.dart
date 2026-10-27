import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shiori/core/config/session_publication_guard.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/core/network/guard_dio.dart';
import 'package:shiori/core/network/request_cancelled.dart';
import 'package:shiori/core/network/retry_policy.dart';
import 'package:shiori/core/network/session_transport.dart';
import 'package:shiori/core/network/transport_response.dart';
import 'package:shiori/features/library/data/cached_library_snapshot.dart';
import 'package:shiori/features/library/data/library_session_scope.dart';
import 'package:shiori/features/library/data/library_snapshot_cache.dart';
import 'package:shiori/features/library/data/library_snapshot_protocol_exception.dart';
import 'package:shiori/features/library/data/library_snapshot_state.dart';
import 'package:shiori/features/servers/data/server_activation_dependencies.dart';

part 'library_snapshot_repository.g.dart';

final class LibrarySnapshotRepository {
  LibrarySnapshotRepository(
    this._transport,
    this._cache,
    SessionPublicationGuard guard, {
    DateTime Function()? now,
    this.waitBeforeRetry,
  }) : _scope = LibrarySessionScope(_transport.session, guard),
       _now = now ?? DateTime.now;

  final SessionTransport _transport;
  final LibrarySnapshotCache _cache;
  final LibrarySessionScope _scope;
  final DateTime Function() _now;
  final Future<void> Function(Duration)? waitBeforeRetry;
  final _changes = StreamController<LibrarySnapshotState>.broadcast(sync: true);
  LibrarySnapshotState _state = const LibrarySnapshotState();
  Future<void>? _pending;
  bool _disposed = false;

  LibrarySnapshotState get state => _state;
  Stream<LibrarySnapshotState> get changes => _changes.stream;

  /// Initial load and explicit refresh coalesce; both re-read durable metadata.
  Future<void> load() => refresh();
  Future<void> refresh() =>
      _pending ??= _refresh().whenComplete(() => _pending = null);

  Future<CachedLibrarySnapshot?> _read() async {
    _scope.check();
    return CachedLibrarySnapshot.restore(
      await _scope.wait(_cache.read(_transport.session.serverKey)),
    );
  }

  Future<void> _refresh() async {
    try {
      final cached = await _read();
      _publish(
        LibrarySnapshotState(
          snapshot: cached ?? _state.snapshot,
          refreshing: true,
        ),
      );
      _scope.check(); // A synchronous stale-data listener may switch servers.
      final etag = cached?.stored.etag;
      var response = await _fetch(etag);
      if (response.statusCode == 304) {
        final reloaded = await _read();
        if (etag != null &&
            reloaded != null &&
            reloaded.stored.etag == etag &&
            reloaded.stored.payload == cached!.stored.payload) {
          _publish(LibrarySnapshotState(snapshot: reloaded, stale: false));
          return;
        }
        response = await _fetch(null); // Exactly one unconditional recovery.
        if (response.statusCode == 304) {
          throw const LibrarySnapshotProtocolException();
        }
      }
      final fresh = CachedLibrarySnapshot.fromResponse(response, _now());
      _scope.check();
      await _scope.wait(
        _cache.replace(
          _transport.session.serverKey,
          fresh.stored,
          checkActive: _scope.check,
        ),
      );
      _publish(LibrarySnapshotState(snapshot: fresh, stale: false));
    } on RequestCancelled {
      // Retirement owns the next view; no retry or error notification.
    } catch (error) {
      _publish(LibrarySnapshotState(snapshot: _state.snapshot, error: error));
    }
  }

  Future<TransportResponse<Object?>> _fetch(String? etag) async {
    for (var retry = 0; ; retry++) {
      _scope.check();
      try {
        return await _scope.wait(
          guardDio(
            () => _transport.getJson(
              ['api', 'library', 'snapshot'],
              ifNoneMatch: etag,
              allowedTerminalStatuses: const {200, 304},
            ),
          ),
        );
      } catch (error) {
        _scope.check();
        final delay = retryNetworkErrors(retry, error);
        if (delay == null) rethrow;
        await _pause(delay);
      }
    }
  }

  Future<void> _pause(Duration delay) async {
    if (waitBeforeRetry != null) {
      return _scope.wait(waitBeforeRetry!(delay));
    }
    final done = Completer<void>();
    final timer = Timer(delay, done.complete);
    try {
      await _scope.wait(done.future);
    } finally {
      timer.cancel();
    }
  }

  void _publish(LibrarySnapshotState next) => _scope.publish(() {
    _state = next;
    _changes.add(next);
  });

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _scope.dispose();
    // Disposal may be triggered synchronously by a publication listener.
    scheduleMicrotask(() => unawaited(_changes.close()));
  }
}

@Riverpod(keepAlive: true)
LibrarySnapshotRepository librarySnapshotRepository(
  Ref ref,
  ServerSession session,
) {
  final repository = LibrarySnapshotRepository(
    ref.watch(sessionTransportProvider(session)),
    ref.watch(librarySnapshotCacheProvider),
    ref.watch(sessionPublicationGuardProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
}
