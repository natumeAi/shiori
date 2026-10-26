part of 'publication_worker.dart';

extension _WorkerQueue on PublicationWorker {
  Future<T> _enqueue<T>(
    PublicationRequest request,
    T Function(PublicationResponse) decode,
    PublicationCancellation? cancellation,
  ) {
    if (isClosed) {
      return PublicationWorker._failure(PublicationWorkerFailure.closed);
    }
    if (_tag == null) {
      return PublicationWorker._failure(PublicationWorkerFailure.notOpen);
    }
    if (cancellation?.isCanceled ?? false) {
      return PublicationWorker._failure(PublicationWorkerFailure.canceled);
    }
    if (_running != null && _pending.length >= PublicationWorker.pendingLimit) {
      return PublicationWorker._failure(PublicationWorkerFailure.queueFull);
    }
    final completer = Completer<T>();
    final pending = _Pending(request, (reply) {
      try {
        completer.complete(decode(reply));
      } on Object catch (error, stack) {
        completer.completeError(error, stack);
      }
    }, completer.completeError);
    _pending.add(pending);
    pending.unsubscribe = cancellation?.listen(() {
      _pending.remove(pending);
      pending.fail(PublicationWorkerFailure.canceled);
    });
    _pump();
    return completer.future;
  }

  void _invalidate(PublicationWorkerFailure failure) {
    _running?.fail(failure);
    for (final pending in _pending) {
      pending.fail(failure);
    }
    _pending.clear();
  }

  void _pump() {
    if (_closed || _running != null || _requests == null) return;
    if (_closing) {
      if (_closeAcknowledged) return;
      final request = ClosePublication(
        ++_nextId,
        _tag ?? const PublicationTag(''),
        _generation,
      );
      _running = _Pending(request, (_) {}, (_) {});
    } else {
      if (_pending.isEmpty) return;
      _running = _pending.removeFirst();
    }
    _requests!.send(_running!.request);
  }

  void _receive(Object? message) {
    if (_closed) return;
    if (message is SendPort && !_ready.isCompleted) {
      _requests = message;
      _ready.complete();
      return;
    }
    if (message == null) {
      if (_closing && _closeAcknowledged) {
        _closed = true;
        _messages.close();
        _isolate = null;
        _closeDone!.complete();
      } else {
        _terminate(PublicationWorkerFailure.unexpectedExit);
      }
      return;
    }
    if (message is List) {
      // Dart's uncaught-error listener supplies [errorText, stackText]. Do not
      // propagate potentially private strings across the public boundary.
      _terminate(PublicationWorkerFailure.workerError);
      return;
    }
    if (message is! PublicationResponse) {
      _terminate(PublicationWorkerFailure.protocol);
      return;
    }
    final running = _running;
    // Unknown/duplicate old IDs cannot consume the current request's slot.
    // Their original futures were already completed by cancellation/reopen.
    if (running == null || message.id != running.request.id) return;
    final request = running.request;
    _running = null;
    if (running.done) {
      // A canceled/stale operation still occupied the physical execution slot.
      // Its failure, too, must be discarded before sending close or reopen.
      _pump();
      return;
    }
    if (message.tag != request.tag ||
        message.generation != request.generation ||
        message.tag != _tag && request is! ClosePublication ||
        message.generation != _generation) {
      running.fail(PublicationWorkerFailure.stale);
    } else if (message is PublicationFailed) {
      running.error(message.error);
      if (_closing) {
        _terminate(PublicationWorkerFailure.workerError);
        return;
      }
    } else if (request is ClosePublication) {
      if (message is! PublicationClosed) {
        _terminate(PublicationWorkerFailure.protocol);
        return;
      }
      _closeAcknowledged = true;
    } else {
      running.succeed(message);
    }
    _pump();
  }

  void _terminate(PublicationWorkerFailure failure) {
    _closed = true;
    _invalidate(failure);
    _running = null;
    _isolate?.kill(priority: Isolate.immediate);
    _messages.close();
    final error = PublicationWorkerException(failure);
    if (!_ready.isCompleted) _ready.completeError(error);
    if (_closeDone != null && !_closeDone!.isCompleted) {
      _closeDone!.completeError(error);
    }
  }
}

final class _Pending {
  _Pending(this.request, this._accept, this._reject);
  final PublicationRequest request;
  final void Function(PublicationResponse) _accept;
  final void Function(Object) _reject;
  void Function()? unsubscribe;
  bool done = false;

  void succeed(PublicationResponse reply) {
    if (done) return;
    _finish();
    _accept(reply);
  }

  void fail(PublicationWorkerFailure failure) =>
      error(PublicationWorkerException(failure));

  void error(Object error) {
    if (done) return;
    _finish();
    _reject(error);
  }

  void _finish() {
    done = true;
    unsubscribe?.call();
    unsubscribe = null;
  }
}
