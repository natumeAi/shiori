import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/core/config/session_publication_guard.dart';
import 'package:shiori/core/network/request_cancelled.dart';
import 'package:shiori/core/storage/cache_budget.dart';
import 'package:shiori/core/storage/cache_reservation.dart';
import 'package:shiori/core/storage/sqlite_store.dart';
import 'package:shiori/core/storage/storage_exception.dart';
import 'package:shiori/core/storage/stored_publication.dart';
import 'package:shiori/features/library/data/publications/download_exception.dart';
import 'package:shiori/features/library/data/publications/download_result.dart';
import 'package:shiori/features/library/data/publications/local_publication.dart';
import 'package:shiori/features/library/data/publications/publication_attempt.dart';
import 'package:shiori/features/library/data/publications/publication_cache_exception.dart';
import 'package:shiori/features/library/data/publications/publication_cache_hooks.dart';
import 'package:shiori/features/library/data/publications/publication_head_change.dart';
import 'package:shiori/features/library/data/publications/publication_lease.dart';
import 'package:shiori/features/library/data/publications/publication_staging.dart';
import 'package:shiori/features/servers/data/server_activation_dependencies.dart';

part 'publication_cache.g.dart';
part 'publication_cache_files.dart';
part 'publication_cache_publish.dart';
part 'publication_cache_reconciliation.dart';

/// One owner across server sessions in a provider container. All filesystem/DB
/// transitions and acquisitions share this queue; leases themselves are memory.
final class PublicationCache {
  PublicationCache._(
    this.store,
    this.staging,
    this.guard,
    this._files,
    this._scope,
    this.now,
    this.hooks,
  );

  static Future<PublicationCache> open({
    required SqliteStore store,
    required PublicationStaging staging,
    required SessionPublicationGuard guard,
    CacheBudget? budget,
    DateTime Function()? now,
    PublicationCacheHooks? hooks,
  }) => _open(
    store: store,
    staging: staging,
    guard: guard,
    scope: _PublicationCacheScope(budget ?? CacheBudget()),
    now: now,
    hooks: hooks,
  );

  static Future<PublicationCache> _open({
    required SqliteStore store,
    required PublicationStaging staging,
    required SessionPublicationGuard guard,
    required _PublicationCacheScope scope,
    DateTime Function()? now,
    PublicationCacheHooks? hooks,
  }) async {
    final cache = PublicationCache._(
      store,
      staging,
      guard,
      await _PublicationFiles.open(staging),
      scope,
      now ?? DateTime.now,
      hooks,
    );
    try {
      await cache.reconcile();
      return cache;
    } catch (_) {
      cache.dispose();
      rethrow;
    }
  }

  final SqliteStore store;
  final PublicationStaging staging;
  final SessionPublicationGuard guard;
  final _PublicationCacheScope _scope;
  CacheBudget get budget => _scope.budget;
  final DateTime Function() now;
  final PublicationCacheHooks? hooks;
  final _PublicationFiles _files;
  Map<String, int> get _protected => _scope.protected;
  final _operations = <BookKey, int>{};
  int _nextOperation = 0;
  final _attempts = <PublicationAttempt>{};
  final _changes = StreamController<PublicationHeadChange>.broadcast(
    sync: true,
  );
  bool _disposed = false;
  Stream<PublicationHeadChange> get headChanges => _changes.stream;

  void _checkOpen() {
    if (_disposed) throw const RequestCancelled();
  }

  Future<T> _serialize<T>(Future<T> Function() action) async {
    final previous = _scope.tail;
    final done = Completer<void>();
    _scope.tail = done.future;
    await previous;
    try {
      _checkOpen();
      return await action();
    } on FileSystemException {
      throw const PublicationCacheException(PublicationCacheFailure.storage);
    } on StorageException {
      throw const PublicationCacheException(PublicationCacheFailure.storage);
    } on DownloadException {
      throw const PublicationCacheException(PublicationCacheFailure.storage);
    } finally {
      done.complete();
    }
  }

  void _checkSession(ServerSession session, BookKey key) {
    if (key.serverKey != session.serverKey) {
      throw ArgumentError('Publication belongs to another session');
    }
    if (_disposed || !guard.isCurrent(session)) throw const RequestCancelled();
  }

  /// A fresh call supersedes the earlier preparation token for this book.
  /// Ordinary request coalescing belongs to the preparation orchestrator.
  Future<PublicationAttempt> beginPreparation(
    ServerSession session,
    BookKey key,
  ) {
    _checkSession(session, key);
    final generation = ++_nextOperation;
    _operations[key] = generation;
    return _serialize(() async {
      void checkAdmission() {
        _checkSession(session, key);
        if (_operations[key] != generation) throw const RequestCancelled();
      }

      final pin = await _leaseHead(key, touch: false, check: checkAdmission);
      late PublicationAttempt attempt;
      void check() {
        _checkSession(session, key);
        if (attempt.isClosed || _operations[key] != generation) {
          throw const RequestCancelled();
        }
      }

      attempt = PublicationAttempt(
        check,
        () {
          _attempts.remove(attempt);
          if (_operations[key] == generation) _operations.remove(key);
        },
        session: session,
        key: key,
        generation: generation,
        previousHead: pin,
      );
      try {
        check();
        _attempts.add(attempt);
        return attempt;
      } catch (_) {
        attempt.close();
        rethrow;
      }
    });
  }

  /// Explicit attempt pin for callers that manage their own preparation token.
  Future<PublicationLease?> pinHead(BookKey key) =>
      _serialize(() => _leaseHead(key, touch: false));

  Future<PublicationLease?> acquireHead(ServerSession session, BookKey key) =>
      _serialize(() async {
        _checkSession(session, key);
        final lease = await _leaseHead(
          key,
          touch: true,
          check: () => _checkSession(session, key),
        );
        try {
          _checkSession(session, key);
          return lease;
        } catch (_) {
          lease?.release();
          rethrow;
        }
      });

  Future<PublicationLease?> _leaseHead(
    BookKey key, {
    required bool touch,
    void Function()? check,
  }) async {
    void checkCurrent() {
      _checkOpen();
      check?.call();
    }

    checkCurrent();
    final head = await store.readPublicationHead(key);
    checkCurrent();
    if (head == null) return null;
    final matches = await _files.matches(head);
    checkCurrent();
    if (!matches) {
      await store.deleteGeneration(key, head.sha256);
      checkCurrent();
      return null;
    }
    if (touch) await store.touchGeneration(key, head.sha256, now().toUtc());
    checkCurrent();
    final path = head.relativePath;
    _protected.update(path, (count) => count + 1, ifAbsent: () => 1);
    return PublicationLease(head, _files.local(head), () {
      final count = _protected[path]!;
      if (count == 1) {
        _protected.remove(path);
      } else {
        _protected[path] = count - 1;
      }
    });
  }

  Future<StoredPublication> publish(
    PublicationAttempt attempt,
    StagedDownload staged, {
    required int parserVersion,
    required int canonicalVersion,
  }) async {
    try {
      return await _serialize(
        () => _publish(
          attempt,
          staged,
          parserVersion: parserVersion,
          canonicalVersion: canonicalVersion,
        ),
      );
    } finally {
      // Disposal can reject a queued call before _publish ever starts.
      if (staging.owns(staged.file)) {
        try {
          await staged.file.discard();
        } on DownloadException {
          throw const PublicationCacheException(
            PublicationCacheFailure.storage,
          );
        }
      }
    }
  }

  /// Publication and lease acquisition share admission with eviction. No other
  /// cache user can evict the new head between commit and its first lease.
  Future<PublicationLease> publishLeased(
    PublicationAttempt attempt,
    StagedDownload staged, {
    required int parserVersion,
    required int canonicalVersion,
  }) async {
    try {
      return await _serialize(() async {
        await _publish(
          attempt,
          staged,
          parserVersion: parserVersion,
          canonicalVersion: canonicalVersion,
        );
        attempt.checkCurrent();
        final lease = await _leaseHead(
          attempt.key,
          touch: false,
          check: attempt.checkCurrent,
        );
        if (lease == null) {
          throw const PublicationCacheException(
            PublicationCacheFailure.invalidGeneration,
          );
        }
        return lease;
      });
    } finally {
      if (staging.owns(staged.file)) await staged.file.discard();
    }
  }

  /// Future covers hold this charge until their bytes are deleted. They are
  /// outside publications' measured subtree; do not release after writing them.
  Future<CacheReservation> reserveBytes(int bytes) =>
      _serialize(() => _reserve(bytes, _checkOpen));

  Future<void> reconcile() => _serialize(_reconcile);

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final attempt in _attempts.toList()) {
      attempt.close();
    }
    // A listener can dispose its owner during synchronous event delivery.
    scheduleMicrotask(() => unawaited(_changes.close()));
  }
}

@Riverpod(keepAlive: true)
Future<PublicationCache> publicationCache(Ref ref) async {
  final scope = ref.watch(_publicationCacheScopeProvider);
  final staging = ref.watch(publicationStagingProvider);
  final guard = ref.watch(sessionPublicationGuardProvider);
  final store = await ref.watch(sqliteStoreProvider.future);
  if (!ref.mounted) throw const RequestCancelled();
  final cache = await PublicationCache._open(
    scope: scope,
    store: store,
    staging: staging,
    guard: guard,
  );
  if (!ref.mounted) {
    cache.dispose();
    throw const RequestCancelled();
  }
  ref.onDispose(cache.dispose);
  return cache;
}

// Pins, reservations and the queue outlive service/provider invalidation. A
// replacement must not forget a generation still open in a reader/worker.
final class _PublicationCacheScope {
  _PublicationCacheScope(this.budget);
  final CacheBudget budget;
  final protected = <String, int>{};
  Future<void> tail = Future.value();
}

@Riverpod(keepAlive: true)
_PublicationCacheScope _publicationCacheScope(Ref ref) =>
    _PublicationCacheScope(CacheBudget());
