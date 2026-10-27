import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/core/network/streaming_file_body.dart';

/// Bounds the source before Dio eagerly subscribes and buffers response chunks.
final class BoundedResponseAdapter implements HttpClientAdapter {
  BoundedResponseAdapter(this._inner, {required this.limitFor});

  final HttpClientAdapter _inner;

  /// Null means status/headers have already established that no body is useful.
  final int? Function(RequestOptions, ResponseBody) limitFor;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final response = await _inner.fetch(options, requestStream, cancelFuture);
    final source = response.stream;
    final fileBody = options.extra[StreamingFileBody.extraKey];
    if (fileBody is StreamingFileBody && response.statusCode == 200) {
      // Dio sees an empty body; disk writes control the original source.
      await fileBody.attach(source);
      response.stream = const Stream.empty();
      return response;
    }
    final limit = limitFor(options, response);
    if (limit == null) {
      await source.listen(null).cancel();
      response.stream = const Stream.empty();
    } else {
      response.stream = _bounded(source, limit);
    }
    return response;
  }

  Stream<Uint8List> _bounded(Stream<Uint8List> source, int limit) async* {
    var received = 0;
    await for (final chunk in source) {
      received += chunk.length;
      if (received > limit) throw const ParseException();
      yield chunk;
    }
  }

  @override
  void close({bool force = false}) => _inner.close(force: force);
}
