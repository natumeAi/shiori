import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/core/config/session_publication_guard.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/core/network/request_cancelled.dart';
import 'package:shiori/core/network/session_transport.dart';
import 'package:shiori/features/library/data/publications/download_exception.dart';
import 'package:shiori/features/library/data/publications/download_result.dart';
import 'package:shiori/features/library/data/publications/local_publication.dart';
import 'package:shiori/features/library/data/publications/publication_staging.dart';
import 'package:shiori/features/reader/data/epub/epub_archive.dart';
import 'package:shiori/features/servers/data/server_activation_dependencies.dart';

part 'publication_download_service.g.dart';

final class PublicationDownloadService {
  PublicationDownloadService(
    this.transport,
    this.staging,
    this.guard, {
    this.limits = const EpubLimits(),
  }) {
    _unregister = guard.onRetire(transport.session, dispose);
  }

  final SessionTransport transport;
  final PublicationStaging staging;
  final SessionPublicationGuard guard;
  final EpubLimits limits;
  final Map<BookKey, _DownloadOperation> _pending = {};
  int _generation = 0;
  bool _disposed = false;
  void Function()? _unregister;

  /// Ordinary calls share the same attempt/result. A per-call cancellation
  /// cancels that shared attempt; refresh always supersedes it.
  Future<DownloadResult> download(
    BookKey key, {
    LocalPublication? local,
    bool refresh = false,
    CancelToken? cancelToken,
    void Function(int received, int? total)? onReceiveProgress,
  }) {
    if (key.serverKey != transport.session.serverKey ||
        (local != null && local.key != key)) {
      throw ArgumentError('Publication belongs to another book/session');
    }
    if (_disposed ||
        !guard.isCurrent(transport.session) ||
        (cancelToken?.isCancelled ?? false)) {
      return Future.error(const RequestCancelled());
    }
    final previous = _pending[key];
    if (previous != null && !refresh) {
      cancelToken?.whenCancel.then((_) => previous.cancel.cancel());
      return previous.future;
    }
    previous?.cancel.cancel();
    final operation = _DownloadOperation(++_generation, onReceiveProgress);
    _pending[key] = operation;
    cancelToken?.whenCancel.then((_) => operation.cancel.cancel());
    operation.future = staging
        .serialize(() => _perform(key, operation, refresh ? null : local))
        .whenComplete(() {
          if (_pending[key]?.generation == operation.generation) {
            _pending.remove(key);
          }
        });
    return operation.future;
  }

  void _check(BookKey key, _DownloadOperation operation) {
    if (_disposed ||
        !guard.isCurrent(transport.session) ||
        operation.cancel.isCancelled ||
        _pending[key]?.generation != operation.generation) {
      throw const RequestCancelled();
    }
  }

  Future<DownloadResult> _perform(
    BookKey key,
    _DownloadOperation operation,
    LocalPublication? local,
  ) async {
    void check() => _check(key, operation);
    StagingFile? owned;
    try {
      check();
      var usable =
          local != null && await local.isUsable(limits.maxArchiveBytes, check);
      for (var attempt = 0; ; attempt++) {
        check();
        final conditional = usable && attempt == 0;
        final etag = conditional ? local!.etag : null;
        final modified = conditional && etag == null
            ? local!.lastModified
            : null;
        try {
          final response = await transport.getFile<_WrittenFile>(
            key.bookId,
            maxBytes: limits.maxArchiveBytes,
            ifNoneMatch: etag,
            ifModifiedSince: modified,
            cancelToken: operation.cancel,
            onReceiveProgress: (received, total) {
              check();
              if (received > limits.maxArchiveBytes ||
                  (total != null && total > limits.maxArchiveBytes)) {
                throw const DownloadException(DownloadFailure.tooLarge);
              }
              operation.onReceiveProgress?.call(received, total);
            },
            consume: (chunks) async {
              check();
              owned = await staging.create();
              check();
              return _write(owned!, chunks, check);
            },
          );
          check();
          if (response.statusCode == 304) {
            usable =
                local != null &&
                await local.isUsable(limits.maxArchiveBytes, check);
            check();
            if (usable) return DownloadNotModified(local);
            // A 304 is admitted only on the first, conditional attempt.
            continue;
          }
          final written = response.body!;
          final result = StagedDownload(
            key: key,
            file: owned!,
            byteLength: written.length,
            digest: written.digest,
            etag: _validator(response.headers, 'etag'),
            lastModified: _validator(response.headers, 'last-modified'),
          );
          check();
          return result;
        } on ServerException catch (error) {
          check();
          if (attempt != 0 ||
              !const {304, 206, 412, 416}.contains(error.statusCode)) {
            rethrow;
          }
          usable = false; // Exactly one full unconditional recovery.
        }
      }
    } catch (error) {
      await owned?.discard();
      check();
      if (error is FileSystemException) {
        throw const DownloadException(DownloadFailure.storage);
      }
      rethrow;
    }
  }

  String? _validator(Map<String, List<String>> headers, String name) {
    final values = headers[name];
    if (values == null) return null;
    if (values.length != 1) {
      throw const DownloadException(DownloadFailure.invalidValidators);
    }
    return values.single; // Preserve weak markers, quotes and date text.
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final operation in _pending.values) {
      operation.cancel.cancel();
    }
    _unregister?.call();
  }
}

final class _DownloadOperation {
  _DownloadOperation(this.generation, this.onReceiveProgress);
  final int generation;
  final void Function(int, int?)? onReceiveProgress;
  final CancelToken cancel = CancelToken();
  late Future<DownloadResult> future;
}

Future<_WrittenFile> _write(
  StagingFile file,
  Stream<List<int>> chunks,
  void Function() check,
) async {
  final writer = await file.open();
  final output = _DigestSink();
  final hash = sha256.startChunkedConversion(output);
  var length = 0;
  try {
    await for (final chunk in chunks) {
      check();
      await writer.write(chunk);
      check();
      hash.add(chunk);
      length += chunk.length;
    }
    check();
    await writer.flush();
    check();
    hash.close();
    return _WrittenFile(length, output.value!.toString());
  } finally {
    await writer.close();
  }
}

final class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) {
    value = data;
  }

  @override
  void close() {}
}

final class _WrittenFile {
  const _WrittenFile(this.length, this.digest);
  final int length;
  final String digest;
}

@Riverpod(keepAlive: true)
PublicationDownloadService publicationDownloadService(
  Ref ref,
  ServerSession session,
) {
  final service = PublicationDownloadService(
    ref.watch(sessionTransportProvider(session)),
    ref.watch(publicationStagingProvider),
    ref.watch(sessionPublicationGuardProvider),
  );
  ref.onDispose(service.dispose);
  return service;
}
