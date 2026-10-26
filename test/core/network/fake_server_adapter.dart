import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Fake at the real Dio adapter boundary, not a mocked transport/repository.
final class FakeServerAdapter implements HttpClientAdapter {
  FakeServerAdapter(this.respond);

  final FutureOr<ResponseBody> Function(RequestOptions options, int index)
  respond;
  final List<RequestOptions> requests = [];
  bool closed = false;
  bool forceClosed = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return await respond(options, requests.length - 1);
  }

  @override
  void close({bool force = false}) {
    closed = true;
    forceClosed = force;
  }
}

ResponseBody jsonBody([
  String body = '{"ok":true}',
  int status = 200,
  Map<String, List<String>> headers = const {},
]) => ResponseBody.fromString(
  body,
  status,
  headers: {
    'content-type': ['application/json'],
    ...headers,
  },
);
