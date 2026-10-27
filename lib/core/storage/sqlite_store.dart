import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shiori/core/config/server_endpoint.dart';
import 'package:shiori/core/config/server_key.dart';
import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/core/storage/app_directories.dart';
import 'package:shiori/core/storage/directory_access.dart';
import 'package:shiori/core/storage/server_record.dart';
import 'package:shiori/core/storage/sqlite_store_test_hooks.dart';
import 'package:shiori/core/storage/storage_exception.dart';
import 'package:shiori/core/storage/stored_snapshot.dart';
import 'package:shiori/core/storage/stored_publication.dart';
import 'package:sqlite3/sqlite3.dart';

part 'sqlite_store.g.dart';
part 'sqlite_store_protocol.dart';
part 'sqlite_store_schema.dart';
part 'sqlite_store_worker.dart';
part 'sqlite_store_commands.dart';
part 'sqlite_store_publications.dart';

/// Scope-owned, long-lived SQLite worker. Only detached values cross its ports.
final class SqliteStore {
  SqliteStore._();

  static const relativePath = 'shiori/v1/state.db';
  static const schemaVersion = 2;

  static Future<SqliteStore> open(
    AppDirectories directories, {
    SqliteStoreTestHooks? testHooks,
  }) async {
    final store = SqliteStore._();
    await store._start(directories, testHooks);
    return store;
  }

  final _messages = ReceivePort();
  final _ready = Completer<void>();
  final _exited = Completer<void>();
  final _pending = <int, Completer<Object?>>{};
  SendPort? _requests;
  int _nextId = 0;
  bool _closing = false;
  bool _closed = false;
  Future<void>? _closeFuture;

  bool get isClosed => _closed || _closing;

  Future<void> _start(
    AppDirectories directories,
    SqliteStoreTestHooks? hooks,
  ) async {
    _messages.listen(_receive);
    try {
      final support = await DirectoryAccess.resolve(
        directories.applicationSupport,
      );
      if (_closing) throw const StorageException(StorageFailure.closed);
      final path = support.uri.resolve(relativePath).toFilePath();
      await Future.wait<Object?>([
        Isolate.spawn(
          _runStore,
          _Bootstrap(
            path,
            _messages.sendPort,
            Isolate.current.controlPort,
            hooks,
          ),
          onError: _messages.sendPort,
          onExit: _messages.sendPort,
          errorsAreFatal: true,
          debugName: 'sqlite-store',
        ),
        _ready.future,
      ], eagerError: true);
      if (_closed) throw const StorageException(StorageFailure.workerExit);
      if (_closing) {
        await close();
        throw const StorageException(StorageFailure.closed);
      }
    } catch (error) {
      _closed = true;
      _messages.close();
      if (!_exited.isCompleted) _exited.complete();
      if (error is StorageException) rethrow;
      throw const StorageException(StorageFailure.open);
    }
  }

  Future<void> upsertServer(ServerRecord record) =>
      _send(_UpsertServer(record));
  Future<ServerRecord?> readServer(ServerKey key) => _send(_ReadServer(key));
  Future<ServerRecord?> readActiveServer() => _send(const _ReadActive());
  Future<void> setActiveServer(ServerKey? key) => _send(_SetActive(key));
  Future<void> commitActivation(ServerRecord record, StoredSnapshot snapshot) =>
      _send(_Activate(record, snapshot));
  Future<StoredSnapshot?> readSnapshot(ServerKey key) =>
      _send(_ReadSnapshot(key));
  Future<void> replaceSnapshot(ServerKey key, StoredSnapshot snapshot) =>
      _send(_ReplaceSnapshot(key, snapshot));
  Future<void> touchLastUsed(ServerKey key, DateTime at) =>
      _send(_Touch(key, at));

  Future<void> publishGeneration(StoredPublication value) =>
      _send(_PublishGeneration(value));
  Future<StoredPublication?> readPublicationHead(BookKey key) =>
      _send(_ReadPublication(key, null));
  Future<StoredPublication?> readGeneration(BookKey key, String sha256) =>
      _send(_ReadPublication(key, sha256));

  /// Across every server; excludes container-owned leases/pins supplied by owner.
  Future<List<StoredPublication>> listPublicationCandidates({
    Set<String> protectedPaths = const {},
  }) => _send(_ListPublications(Set.unmodifiable(protectedPaths)));
  Future<void> deleteGeneration(BookKey key, String sha256) =>
      _send(_DeleteGeneration(key, sha256));
  Future<void> clearPublicationHead(BookKey key, String sha256) =>
      _send(_ClearPublicationHead(key, sha256));
  Future<void> touchGeneration(BookKey key, String sha256, DateTime at) =>
      _send(_TouchGeneration(key, sha256, at));

  /// Test probes still execute through the real request queue in the worker.
  Future<bool> runsOffRootForTesting() => _send(const _WorkerIdentity());
  Future<void> exitForTesting() => _send(const _ExitForTesting());

  Future<T> _send<T>(_Operation<T> operation, {bool closing = false}) {
    if (_closed || (_closing && !closing) || _requests == null) {
      return Future.error(const StorageException(StorageFailure.closed));
    }
    final id = ++_nextId;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    _requests!.send(_Request(id, operation));
    return completer.future.then((value) => value as T);
  }

  void _receive(Object? message) {
    switch (message) {
      case _Ready(:final requests):
        _requests = requests;
        _ready.complete();
      case _OpenFailed(:final error):
        _ready.completeError(error);
      case _Reply(:final id, :final value, :final error):
        final waiter = _pending.remove(id);
        if (waiter == null) return;
        if (error != null) {
          waiter.completeError(error);
        } else {
          waiter.complete(value);
        }
      default:
        // Both fatal error notifications and onExit have content-free mapping.
        _closed = true;
        const error = StorageException(StorageFailure.workerExit);
        if (!_ready.isCompleted) _ready.completeError(error);
        for (final waiter in _pending.values) {
          waiter.completeError(error);
        }
        _pending.clear();
        // onError can precede onExit. Wait for actual exit before closing ports.
        if (message == null) {
          _messages.close();
          if (!_exited.isCompleted) _exited.complete();
        }
    }
  }

  /// Reject new calls, drain accepted commands, close SQLite, await isolate exit.
  /// Repeated close calls share completion. Scope disposal uses this same path.
  Future<void> close() {
    if (_closeFuture != null) return _closeFuture!;
    _closing = true;
    if (_requests == null || _closed) return _exited.future;
    return _closeFuture = _drainAndClose();
  }

  Future<void> _drainAndClose() async {
    try {
      await _send(const _Close(), closing: true);
    } finally {
      await _exited.future;
    }
  }
}

/// One owner per provider scope, retained between listeners. Invalidation or
/// scope disposal drains it even if disposal races asynchronous initialization.
@Riverpod(keepAlive: true)
Future<SqliteStore> sqliteStore(Ref ref) async {
  final store = SqliteStore._();
  ref.onDispose(
    () => unawaited(
      store.close().onError<StorageException>((_, _) {
        Logger('SqliteStore').warning('storage_close_failed');
      }),
    ),
  );
  await ref
      .watch(_storeOwnersProvider)
      .start(store, ref.watch(appDirectoriesProvider));
  return store;
}

// Retained across sqliteStoreProvider invalidations, so a replacement waits for
// the retired worker's connection to close before opening the next connection.
final class _StoreOwners {
  Future<void> _previousExit = Future.value();

  Future<void> start(SqliteStore store, AppDirectories directories) async {
    final previous = _previousExit;
    _previousExit = store._exited.future;
    await previous;
    await store._start(directories, null);
  }
}

@Riverpod(keepAlive: true)
_StoreOwners _storeOwners(Ref ref) => _StoreOwners();
