import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:shiori/features/reader/data/epub/epub_archive.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/worker/publication_cancellation.dart';
import 'package:shiori/features/reader/data/worker/publication_snapshot.dart';
import 'package:shiori/features/reader/data/worker/publication_tag.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_exception.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_protocol.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_runtime.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_test_hooks.dart';

part 'publication_worker_queue.dart';

/// One long-lived file-backed publication owner. Root-side code only queues,
/// validates envelopes and materializes already decompressed transferable bytes.
final class PublicationWorker {
  PublicationWorker._(this._maxResourceBytes);

  static const pendingLimit = 8;

  static Future<PublicationWorker> spawn({
    EpubLimits limits = const EpubLimits(),
    int maxResourceBytes = 64 * 1024 * 1024,
    PublicationWorkerTestHooks? testHooks,
  }) async {
    if (maxResourceBytes < 0 || maxResourceBytes > limits.maxEntryBytes) {
      throw ArgumentError.value(maxResourceBytes, 'maxResourceBytes');
    }
    final client = PublicationWorker._(maxResourceBytes);
    client._messages.listen(client._receive);
    try {
      client._isolate = await Isolate.spawn(
        runPublicationWorker,
        PublicationWorkerBootstrap(
          client._messages.sendPort,
          Isolate.current.controlPort,
          limits,
          maxResourceBytes,
          testHooks,
        ),
        onError: client._messages.sendPort,
        onExit: client._messages.sendPort,
        errorsAreFatal: true,
        debugName: 'publication-worker',
      );
      await client._ready.future;
      return client;
    } on Object {
      client._isolate?.kill(priority: Isolate.immediate);
      client._messages.close();
      throw const PublicationWorkerException(
        PublicationWorkerFailure.workerError,
      );
    }
  }

  final int _maxResourceBytes;
  final _messages = ReceivePort();
  final _ready = Completer<void>();
  final _pending = Queue<_Pending>();
  Isolate? _isolate;
  SendPort? _requests;
  _Pending? _running;
  PublicationTag? _tag;
  int _generation = 0;
  int _nextId = 0;
  bool _closed = false;
  bool _closing = false;
  bool _closeAcknowledged = false;
  Completer<void>? _closeDone;

  bool get isClosed => _closed || _closing;

  /// Test-only fault injection: exercises the actual isolate exit listener.
  void killForTesting() => _isolate?.kill(priority: Isolate.immediate);

  /// Reopening invalidates every older operation immediately, even if the
  /// caller deliberately reuses the same tag (A -> B -> A).
  Future<PublicationSnapshot> open(
    String path,
    PublicationTag tag, {
    PublicationCancellation? cancellation,
  }) {
    if (isClosed) return _failure(PublicationWorkerFailure.closed);
    if (cancellation?.isCanceled ?? false) {
      return _failure(PublicationWorkerFailure.canceled);
    }
    _invalidate(PublicationWorkerFailure.stale);
    _tag = tag;
    _generation++;
    return _enqueue(
      OpenPublication(++_nextId, tag, _generation, path),
      (reply) => switch (reply) {
        PublicationOpened(:final snapshot) => snapshot,
        _ => throw _protocol,
      },
      cancellation,
    );
  }

  Future<SourceDocument> loadSection(
    int index, {
    PublicationCancellation? cancellation,
  }) => _enqueue(
    LoadPublicationSection(
      ++_nextId,
      _tag ?? const PublicationTag(''),
      _generation,
      index,
    ),
    (reply) => switch (reply) {
      PublicationSectionLoaded(:final document) => document,
      _ => throw _protocol,
    },
    cancellation,
  );

  /// A detached, read-only view. Missing resources return null, like the
  /// archive API; malformed resources throw ParseException instead.
  Future<Uint8List?> readResource(
    String path, {
    PublicationCancellation? cancellation,
  }) => _enqueue(
    ReadPublicationResource(
      ++_nextId,
      _tag ?? const PublicationTag(''),
      _generation,
      path,
    ),
    (reply) {
      if (reply is! PublicationResourceRead) throw _protocol;
      if (reply.length < 0 || reply.length > _maxResourceBytes) throw _protocol;
      final bytes = reply.bytes?.materialize().asUint8List();
      if ((bytes?.length ?? 0) != reply.length) throw _protocol;
      return bytes?.asUnmodifiableView();
    },
    cancellation,
  );

  /// Waits for the running synchronous operation, closes its archive, and
  /// waits for isolate exit. Pending/running caller futures finish as closed.
  Future<void> close() {
    if (_closeDone != null) return _closeDone!.future;
    if (_closed) return Future.value();
    _closeDone = Completer<void>();
    _closing = true;
    _invalidate(PublicationWorkerFailure.closed);
    _pump();
    return _closeDone!.future;
  }

  static const _protocol = PublicationWorkerException(
    PublicationWorkerFailure.protocol,
  );
  static Future<T> _failure<T>(PublicationWorkerFailure failure) =>
      Future.error(PublicationWorkerException(failure));
}
