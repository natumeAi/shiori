import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/core/config/content_identity.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/core/network/request_cancelled.dart';
import 'package:shiori/features/library/data/publications/preparation_state.dart';
import 'package:shiori/features/library/data/publications/prepare_book_exception.dart';
import 'package:shiori/features/library/data/publications/prepare_book_service.dart';
import 'package:shiori/features/library/data/publications/prepared_book.dart';
import 'package:shiori/features/library/data/publications/publication_cache.dart';
import 'package:shiori/features/library/data/publications/publication_cache_exception.dart';
import 'package:shiori/features/library/data/publications/publication_lease.dart';
import 'package:shiori/features/reader/data/worker/prepared_publication.dart';

part 'preparation_controller.g.dart';

/// UI-facing ownership; explicit prepare/retry, no side effects during build.
@riverpod
class PreparationController extends _$PreparationController {
  late PrepareBookService _service;
  late _PreparationView _view;
  Future<void>? _pending;
  int _generation = 0;

  @override
  PreparationState build(ServerSession session, BookKey key) {
    _generation++;
    _pending = null;
    final service = _service = ref.watch(prepareBookServiceProvider(session));
    final view = _view = _PreparationView();
    final subscription = service.progress.listen((progress) {
      if (view.active &&
          ref.mounted &&
          progress.key == key &&
          state is PreparationPreparing) {
        service.guard.publish(
          session,
          () => state = PreparationState.preparing(
            receivedBytes: progress.received,
            totalBytes: progress.total,
          ),
        );
      }
    });
    final unregister = service.guard.onRetire(session, () {
      view.close();
      if (ref.mounted) state = const PreparationState.idle();
    });
    ref.onDispose(() {
      view.close();
      service.cancel(key);
      unregister();
      unawaited(subscription.cancel());
    });
    return const PreparationState.idle();
  }

  Future<void> prepare({bool refresh = false}) {
    if (_pending != null && !refresh) return _pending!;
    final generation = ++_generation;
    final view = _view;
    final service = _service;
    view.book?.release();
    view.book = null;
    state = const PreparationState.preparing();
    // State listeners may synchronously cancel or dispose the view.
    if (!view.active || !ref.mounted || generation != _generation) {
      return Future.value();
    }
    final pending = _run(service, view, generation, refresh);
    _pending = pending;
    return pending;
  }

  Future<void> _run(
    PrepareBookService service,
    _PreparationView view,
    int generation,
    bool refresh,
  ) async {
    bool current() =>
        view.active &&
        ref.mounted &&
        generation == _generation &&
        service.guard.isCurrent(session);
    try {
      final book = await service.prepare(key, refresh: refresh);
      if (!current()) {
        book.release();
        return;
      }
      _accept(book, view);
    } on RequestCancelled {
      if (current()) state = const PreparationState.idle();
    } on PrepareBookException catch (error) {
      if (current()) {
        service.guard.publish(
          session,
          () => state = PreparationState.failed(error),
        );
      }
    } finally {
      if (ref.mounted && generation == _generation) _pending = null;
    }
  }

  /// Navigation releases only this view's owner, never the shared preparation.
  void detachRoute() {
    if (!ref.mounted || !_view.active) return;
    _view.attached = false;
    if (state case PreparationReady(:final book)) {
      book.release();
      _view.book = null;
      state = PreparationState.detached(book.publication);
    }
  }

  /// Reuse detached interpretation only with the same verified, current head.
  Future<void> attachRoute() {
    if (!ref.mounted || !_view.active) return Future.value();
    _view.attached = true;
    if (state case PreparationDetached(:final publication)) {
      final generation = ++_generation;
      final view = _view;
      state = const PreparationState.preparing();
      if (!ref.mounted || !view.active || generation != _generation) {
        return Future.value();
      }
      return _pending = _restore(publication, view, generation);
    }
    return _pending ?? Future.value();
  }

  Future<void> _restore(
    PreparedPublication publication,
    _PreparationView view,
    int generation,
  ) async {
    bool current() =>
        ref.mounted &&
        view.active &&
        generation == _generation &&
        _service.guard.isCurrent(session);
    PublicationLease? acquired;
    try {
      final cache = await ref.read(publicationCacheProvider.future);
      if (!current()) return;
      final lease = acquired = await cache.acquireHead(session, key);
      if (!current()) return;
      final head = lease?.generation;
      final identity = head == null
          ? null
          : ContentIdentity(
              head.key,
              head.sha256,
              parserVersion: head.parserVersion,
              canonicalVersion: head.canonicalVersion,
            );
      if (identity != publication.identity || !publication.identity.isCurrent) {
        state = const PreparationState.idle();
        return;
      }
      // acquireHead checks existence/length; detached summaries also require a
      // fresh streamed digest for every size, while this lease prevents eviction.
      final file = File(lease!.local.path);
      final digest = await sha256
          .bind(
            file.openRead().map((chunk) {
              if (!current()) throw const RequestCancelled();
              return chunk;
            }),
          )
          .single;
      if (!current()) return;
      final length = await file.length();
      if (!current()) return;
      if (digest.toString() != identity!.sha256 || length != head!.byteLength) {
        state = const PreparationState.idle();
        return;
      }
      _accept(PreparedBook(publication, lease, () {}), view);
      acquired = null;
    } on RequestCancelled {
      if (current()) state = const PreparationState.idle();
    } on FileSystemException {
      if (current()) state = const PreparationState.idle();
    } on PublicationCacheException {
      _restoreFailed(current);
    } on ProviderException {
      _restoreFailed(current);
    } finally {
      acquired?.release();
      if (ref.mounted && generation == _generation) _pending = null;
    }
  }

  void _restoreFailed(bool Function() current) {
    if (current()) {
      state = const PreparationState.failed(
        PrepareBookException(PrepareBookFailure.storage),
      );
    }
  }

  void _accept(PreparedBook book, _PreparationView view) {
    final accepted = _service.guard.publish(session, () {
      if (view.attached) {
        view.book = book;
        state = PreparationState.ready(book);
      } else {
        book.release();
        state = PreparationState.detached(book.publication);
      }
    });
    if (!accepted) book.release();
  }

  void cancel() {
    _generation++;
    _pending = null;
    _service.cancel(key);
    _view.book?.release();
    _view.book = null;
    state = const PreparationState.idle();
  }
}

final class _PreparationView {
  bool active = true;
  bool attached = true;
  PreparedBook? book;
  void close() {
    active = false;
    book?.release();
    book = null;
  }
}
