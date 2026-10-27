import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:shiori/core/network/request_cancelled.dart';

/// Keeps the adapter source outside Dio's eagerly subscribed response stream.
/// Only SessionTransport consumes it, within the request's lifetime.
final class StreamingFileBody {
  static const extraKey = 'shiori.streamingFileBody';
  Stream<Uint8List>? _source;
  StreamSubscription<Uint8List>? _subscription;
  bool _closed = false;

  Future<void> attach(Stream<Uint8List> source) async {
    if (_closed) {
      await source.listen(null).cancel();
    } else {
      _source = source;
    }
  }

  Stream<Uint8List> read(CancelToken token) {
    late StreamController<Uint8List> controller;
    controller = StreamController<Uint8List>(
      onListen: () {
        _subscription = _source!.listen(
          controller.add,
          onError: controller.addError,
          onDone: () => unawaited(controller.close()),
        );
      },
      onPause: () => _subscription?.pause(),
      onResume: () => _subscription?.resume(),
      onCancel: () => _subscription?.cancel(),
    );
    // Exactly one cancellation callback, with no per-chunk future waiters.
    unawaited(
      token.whenCancel.then((_) {
        if (!controller.isClosed) {
          controller.addError(const RequestCancelled());
          unawaited(controller.close());
        }
        unawaited(_subscription?.cancel());
      }),
    );
    return controller.stream.timeout(const Duration(seconds: 20));
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    if (_subscription case final subscription?) {
      await subscription.cancel();
    } else if (_source case final stream?) {
      await stream.listen(null).cancel();
    }
  }
}
