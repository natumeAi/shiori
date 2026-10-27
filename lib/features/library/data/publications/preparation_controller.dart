import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/core/network/request_cancelled.dart';
import 'package:shiori/features/library/data/publications/preparation_state.dart';
import 'package:shiori/features/library/data/publications/prepare_book_exception.dart';
import 'package:shiori/features/library/data/publications/prepare_book_service.dart';
import 'package:shiori/features/library/data/publications/prepared_book.dart';

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
      view.book = book;
      service.guard.publish(
        session,
        () => state = PreparationState.ready(book),
      );
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
  PreparedBook? book;
  void close() {
    active = false;
    book?.release();
    book = null;
  }
}
