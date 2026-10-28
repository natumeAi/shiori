part of 'publication_worker.dart';

/// Exclusive adapter ownership, separate from the immutable-file pin.
/// Conflicting open/import/detach/close calls wait for physical detach.
final class PublicationWorkerReservation {
  PublicationWorkerReservation._(this._worker);
  final PublicationWorker _worker;
  final _released = Completer<void>();
  final Set<Completer<void>> _waiters = {};
  Future<void>? _releaseWork;
  bool _releasing = false;
  bool get isReleased => _released.isCompleted;

  Future<void> release() => _releaseWork ??= _release();

  Future<void> _release() async {
    _releasing = true;
    try {
      await _worker.detach(reservation: this);
    } on Object {
      // A failed detach cannot authorize release of the file pin while a
      // physical adapter might still exist. Force and await worker shutdown.
      await _worker._closeUnreserved();
      rethrow;
    } finally {
      if (identical(_worker._reader, this)) _worker._reader = null;
      _released.complete();
      for (final waiter in _waiters) {
        if (!waiter.isCompleted) waiter.complete();
      }
      _waiters.clear();
    }
  }
}

extension _ReaderReservationQueue on PublicationWorker {
  bool _blocked(
    PublicationWorkerReservation? reservation, {
    bool detaching = false,
  }) {
    if (reservation != null &&
        (!identical(reservation, _reader) ||
            reservation.isReleased ||
            (reservation._releasing && !detaching))) {
      throw const PublicationWorkerException(PublicationWorkerFailure.stale);
    }
    return _reader != null && !identical(_reader, reservation);
  }

  Future<T> _defer<T>(
    Future<T> Function() action,
    PublicationCancellation? cancellation,
  ) async {
    if (_deferred + _pending.length >= PublicationWorker.pendingLimit) {
      throw const PublicationWorkerException(
        PublicationWorkerFailure.queueFull,
      );
    }
    _deferred++;
    final reader = _reader!;
    final available = Completer<void>();
    reader._waiters.add(available);
    final unsubscribe = cancellation?.listen(() {
      if (!available.isCompleted) {
        available.completeError(
          const PublicationWorkerException(PublicationWorkerFailure.canceled),
        );
      }
    });
    try {
      await available.future;
      if (cancellation?.isCanceled ?? false) {
        throw const PublicationWorkerException(
          PublicationWorkerFailure.canceled,
        );
      }
      return await action();
    } finally {
      unsubscribe?.call();
      reader._waiters.remove(available);
      _deferred--;
    }
  }
}
