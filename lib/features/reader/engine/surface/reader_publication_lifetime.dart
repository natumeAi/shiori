import 'dart:async';

import 'package:shiori/core/config/content_identity.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/features/library/data/publications/prepare_book_queue.dart';
import 'package:shiori/features/library/data/publications/prepared_book.dart';
import 'package:shiori/features/library/data/publications/publication_lease.dart';
import 'package:shiori/features/reader/data/worker/preloaded_publication_section.dart';
import 'package:shiori/features/reader/data/worker/publication_cancellation.dart';
import 'package:shiori/features/reader/data/worker/publication_tag.dart';
import 'package:shiori/features/reader/data/worker/publication_worker.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_exception.dart';
import 'package:shiori/features/reader/engine/pagination/layout_identity.dart';

/// Acquired before the route releases PreparedBook. The acquisition callback is
/// cache.acquireHead(capturedActivation, identity.bookKey), never the route pin.
/// The shared preparation queue stays occupied through final worker detach.
final class ReaderPublicationLifetime {
  ReaderPublicationLifetime._(
    this.identity,
    this.activation,
    this.layout,
    this._file,
    this._isCurrent,
  );
  final ContentIdentity identity;
  final ServerSession activation;
  final LayoutIdentity layout;
  final PublicationLease _file;
  final bool Function() _isCurrent;
  final _cancellation = PublicationCancellation();
  final _finished = Completer<void>();
  late final Future<void> _queueWork;
  late PublicationWorker _worker;
  bool _enabled = true;
  int _generation = 0;
  Future<void>? _closing;
  bool get isActive => _enabled && _isCurrent();

  static Future<ReaderPublicationLifetime> open({
    required PreparedBook preparedBook,
    required ServerSession activation,
    required LayoutIdentity layout,
    required bool Function() isCurrent,
    required Future<PublicationLease?> Function() acquireLease,
    required PrepareBookQueue queue,
    required Future<PublicationWorker> Function() worker,
    PublicationCancellation? cancellation,
  }) async {
    final identity = preparedBook.identity;
    void check() {
      if (!isCurrent() || (cancellation?.isCanceled ?? false)) {
        throw const PublicationWorkerException(
          PublicationWorkerFailure.canceled,
        );
      }
    }

    check();
    if (preparedBook.isReleased) {
      throw const PublicationWorkerException(PublicationWorkerFailure.stale);
    }
    final file = await acquireLease();
    ReaderPublicationLifetime? owner;
    try {
      check();
      if (file == null ||
          identical(file, preparedBook.lease) ||
          !identity.isCurrent ||
          identity.bookKey.serverKey != activation.serverKey ||
          layout.contentId != identity.sha256 ||
          file.generation.key != identity.bookKey ||
          file.generation.sha256 != identity.sha256 ||
          file.generation.parserVersion != identity.parserVersion ||
          file.generation.canonicalVersion != identity.canonicalVersion ||
          !file.generation.isValidated ||
          !file.generation.hasExpectedPath ||
          file.local.key != identity.bookKey ||
          file.local.digest != identity.sha256 ||
          file.local.byteLength != file.generation.byteLength) {
        throw const PublicationWorkerException(
          PublicationWorkerFailure.incompatibleIdentity,
        );
      }
      owner = ReaderPublicationLifetime._(
        identity,
        activation,
        layout,
        file,
        isCurrent,
      );
      final opened = Completer<void>();
      final captured = owner;
      owner._queueWork = queue.run(() async {
        PublicationWorkerReservation? reservation;
        try {
          check();
          captured._worker = await worker();
          check();
          reservation = captured._worker.reserveReader();
          captured._reservation = reservation;
          await captured._worker.open(
            captured._file.local.path,
            PublicationTag(
              '${activation.generation}/${identity.bookKey}/${identity.sha256}/'
              '${identity.parserVersion}/${identity.canonicalVersion}/${layout.key}',
            ),
            reservation: reservation,
            cancellation: cancellation,
          );
          check();
          opened.complete();
          await captured._finished.future;
        } on Object catch (error, stack) {
          if (!opened.isCompleted) opened.completeError(error, stack);
        } finally {
          try {
            await reservation?.release();
          } finally {
            file.release();
          }
        }
      });
      // Observe cleanup failures even if opening is abandoned.
      unawaited(owner._queueWork.catchError((Object _) {}));
      await opened.future;
      check();
      return owner;
    } on Object {
      if (owner == null) {
        if (!identical(file, preparedBook.lease)) file?.release();
      } else {
        owner._enabled = false;
        owner._finished.complete();
        await owner._queueWork;
      }
      rethrow;
    }
  }

  PublicationWorkerReservation? _reservation;

  void _check(int generation, LayoutIdentity expectedLayout) {
    if (!_enabled ||
        generation != _generation ||
        !_isCurrent() ||
        expectedLayout.contentId != identity.sha256 ||
        expectedLayout.generation != layout.generation ||
        expectedLayout.settings != layout.settings ||
        expectedLayout.viewportWidth != layout.viewportWidth ||
        expectedLayout.viewportHeight != layout.viewportHeight ||
        expectedLayout.devicePixelRatio != layout.devicePixelRatio ||
        expectedLayout.styleVersion != layout.styleVersion) {
      throw const PublicationWorkerException(PublicationWorkerFailure.stale);
    }
  }

  /// Caller transfers each successful preload into its section owner. Abandoned
  /// replies are disposed here; source owners must drain before close detaches.
  Future<PreloadedPublicationSection> preload(
    int index, {
    required LayoutIdentity expectedLayout,
  }) async {
    final generation = _generation;
    _check(generation, expectedLayout);
    if (expectedLayout.sectionIndex != index) {
      throw const PublicationWorkerException(PublicationWorkerFailure.stale);
    }
    final result = await _worker.preloadSection(
      index,
      settings: layout.settings,
      reservation: _reservation,
      cancellation: _cancellation,
    );
    try {
      _check(generation, expectedLayout);
      return result;
    } on Object {
      result.dispose();
      rethrow;
    }
  }

  /// Required ordering is centralized here. Cleanup failure retains the file
  /// and reservation: callers can diagnose it without releasing live resources.
  Future<void> close({
    required void Function() disableAndInvalidate,
    required Future<void> Function() cancelAndDrain,
    required Future<void> Function() disposeScenesAndSources,
  }) => _closing ??= _close(
    disableAndInvalidate,
    cancelAndDrain,
    disposeScenesAndSources,
  );

  Future<void> _close(
    void Function() disableAndInvalidate,
    Future<void> Function() cancelAndDrain,
    Future<void> Function() disposeScenesAndSources,
  ) async {
    _enabled = false;
    _generation++;
    disableAndInvalidate();
    _cancellation.cancel();
    await cancelAndDrain();
    await disposeScenesAndSources();
    _finished.complete();
    await _queueWork;
  }
}
