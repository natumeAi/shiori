import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/core/config/content_change.dart';
import 'package:shiori/core/config/content_identity.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/core/config/session_publication_guard.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/core/network/request_cancelled.dart';
import 'package:shiori/core/storage/storage_exception.dart';
import 'package:shiori/core/storage/stored_publication.dart';
import 'package:shiori/features/library/data/book_repository.dart';
import 'package:shiori/features/library/data/models/book_detail_result.dart';
import 'package:shiori/features/library/data/publications/download_exception.dart';
import 'package:shiori/features/library/data/publications/download_result.dart';
import 'package:shiori/features/library/data/publications/prepare_book_exception.dart';
import 'package:shiori/features/library/data/publications/prepare_book_queue.dart';
import 'package:shiori/features/library/data/publications/prepared_book.dart';
import 'package:shiori/features/library/data/publications/publication_attempt.dart';
import 'package:shiori/features/library/data/publications/publication_cache.dart';
import 'package:shiori/features/library/data/publications/publication_cache_exception.dart';
import 'package:shiori/features/library/data/publications/publication_download_service.dart';
import 'package:shiori/features/library/data/publications/publication_lease.dart';
import 'package:shiori/features/library/data/publications/session_publication_worker.dart';
import 'package:shiori/features/reader/data/worker/publication_cancellation.dart';
import 'package:shiori/features/reader/data/worker/publication_import_exception.dart';
import 'package:shiori/features/reader/data/worker/publication_tag.dart';
import 'package:shiori/features/reader/data/worker/publication_worker.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_exception.dart';
import 'package:shiori/features/servers/data/server_activation_dependencies.dart';

part 'prepare_book_service.g.dart';
part 'prepare_book_flow.dart';
part 'prepare_book_errors.dart';

/// Session-owned connected preparation. No checkpoint/activity writes.
final class PrepareBookService {
  PrepareBookService({
    required this.session,
    required this.guard,
    required this.books,
    required this.downloads,
    required this.worker,
    required this.cache,
    required this.queue,
  }) {
    _unregister = guard.onRetire(session, dispose);
  }
  final ServerSession session;
  final SessionPublicationGuard guard;
  final BookRepository books;
  final PublicationDownloadService downloads;
  final SessionPublicationWorker worker;
  final Future<PublicationCache> Function() cache;
  final PrepareBookQueue queue;
  final _pending = <BookKey, _PreparationOperation>{};
  final _ready = <PreparedBook>{};
  final _changes = StreamController<ContentChange>.broadcast(sync: true);
  final _progress =
      StreamController<({BookKey key, int received, int? total})>.broadcast(
        sync: true,
      );
  int _generation = 0;
  bool _disposed = false;
  void Function()? _unregister;

  Stream<ContentChange> get contentChanges => _changes.stream;
  Stream<({BookKey key, int received, int? total})> get progress =>
      _progress.stream;

  /// Duplicate callers receive the same Future and PreparedBook ownership.
  Future<PreparedBook> prepare(BookKey key, {bool refresh = false}) {
    if (key.serverKey != session.serverKey) {
      throw ArgumentError('Book belongs to another session');
    }
    if (_disposed || !guard.isCurrent(session)) {
      return Future.error(const RequestCancelled());
    }
    final previous = _pending[key];
    if (previous != null && !refresh && !previous.http.isCancelled) {
      return previous.future;
    }
    previous?.cancel();
    final operation = _PreparationOperation(++_generation);
    _pending[key] = operation;
    final work = queue
        .run(() => _perform(key, operation, refresh))
        .catchError((Object error) {
          _check(key, operation, checkAttempt: false);
          if (error is RequestCancelled) throw error;
          throw _preparationError(error);
        })
        .whenComplete(() {
          if (identical(_pending[key], operation)) _pending.remove(key);
        });
    operation.future = Future.any([
      work,
      operation.cancelled.future.then<PreparedBook>(
        (_) => throw const RequestCancelled(),
      ),
    ]);
    return operation.future;
  }

  void cancel(BookKey key) => _pending[key]?.cancel();

  void _check(
    BookKey key,
    _PreparationOperation operation, {
    bool checkAttempt = true,
  }) {
    if (_disposed ||
        !guard.isCurrent(session) ||
        operation.http.isCancelled ||
        !identical(_pending[key], operation)) {
      throw const RequestCancelled();
    }
    if (checkAttempt) operation.attempt?.checkCurrent();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final operation in _pending.values) {
      operation.cancel();
    }
    for (final book in _ready.toList()) {
      book.release();
    }
    _unregister?.call();
    scheduleMicrotask(() {
      unawaited(_changes.close());
      unawaited(_progress.close());
    });
  }
}

final class _PreparationOperation {
  _PreparationOperation(this.generation);
  final int generation;
  final http = CancelToken();
  final cancellation = PublicationCancellation();
  final cancelled = Completer<void>();
  PublicationAttempt? attempt;
  PreparedBook? result;
  late Future<PreparedBook> future;
  void cancel() {
    http.cancel();
    cancellation.cancel();
    // Keep the fallback pin until the physical worker/file cleanup finishes.
    result?.release();
    if (!cancelled.isCompleted) cancelled.complete();
  }
}

@Riverpod(keepAlive: true)
PrepareBookService prepareBookService(Ref ref, ServerSession session) {
  final service = PrepareBookService(
    session: session,
    guard: ref.watch(sessionPublicationGuardProvider),
    books: ref.watch(bookRepositoryProvider(session)),
    downloads: ref.watch(publicationDownloadServiceProvider(session)),
    worker: ref.watch(sessionPublicationWorkerProvider(session)),
    cache: () => ref.read(publicationCacheProvider.future),
    queue: ref.watch(prepareBookQueueProvider),
  );
  ref.onDispose(service.dispose);
  return service;
}

@riverpod
Stream<ContentChange> publicationContentChanges(
  Ref ref,
  ServerSession session,
) => ref.watch(prepareBookServiceProvider(session)).contentChanges;
