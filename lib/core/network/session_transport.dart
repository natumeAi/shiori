import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/core/network/bounded_response_adapter.dart';
import 'package:shiori/core/network/guard_dio.dart';
import 'package:shiori/core/network/redacted_request_log.dart';
import 'package:shiori/core/network/redacting_interceptor.dart';
import 'package:shiori/core/network/redirect_policy.dart';
import 'package:shiori/core/network/request_cancelled.dart';
import 'package:shiori/core/network/server_error_code.dart';
import 'package:shiori/core/network/server_route.dart';
import 'package:shiori/core/network/transport_response.dart';

part 'session_transport.g.dart';

/// Owns one Dio and all in-flight requests for exactly one activation.
final class SessionTransport {
  // Snapshot contains the complete library; detail can include a description.
  // Keep small health/file JSON and HTTP errors on the same envelope budget.
  static const _smallJsonLimit = 64 * 1024;
  static const _detailJsonLimit = 256 * 1024;
  static const _snapshotJsonLimit = 8 * 1024 * 1024;
  static const _bodyLimitKey = 'shiori.responseByteLimit';
  static const _jsonBodyKey = 'shiori.jsonResponse';

  SessionTransport(this.session, {HttpClientAdapter? adapter})
    : _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
          followRedirects: false,
          responseType: ResponseType.stream,
          validateStatus: (_) => true,
        ),
      ) {
    _dio.httpClientAdapter = BoundedResponseAdapter(
      adapter ?? _dio.httpClientAdapter,
      limitFor: _responseLimit,
    );
    _dio.interceptors.add(RedactingInterceptor());
  }

  final ServerSession session;
  final Dio _dio;
  final Set<CancelToken> _pending = {};
  bool _disposed = false;

  /// Returns decoded JSON, its original text and validators. DTOs are feature-owned.
  Future<TransportResponse<Object?>> getJson(
    List<String> segments, {
    String? ifNoneMatch,
    String? ifModifiedSince,
    Set<int> allowedTerminalStatuses = const {200},
  }) async {
    final route = ServerRoute.api(segments);
    final allowed = Set<int>.of(allowedTerminalStatuses);
    if (allowed.isEmpty ||
        !const {200, 304}.containsAll(allowed) ||
        (allowed.contains(304) &&
            route != ServerRoute.snapshot &&
            route != ServerRoute.file)) {
      throw ArgumentError('Invalid terminal statuses for route');
    }
    final uri = session.endpoint.api(segments);
    final maxBytes = switch (route) {
      ServerRoute.snapshot => _snapshotJsonLimit,
      ServerRoute.book => _detailJsonLimit,
      _ => _smallJsonLimit,
    };
    return _run(route, (tokens, log) async {
      final response = await _openValidatedResponse(
        uri,
        route,
        tokens,
        log,
        maxBytes: maxBytes,
        json: true,
        headers: {
          'If-None-Match': ?ifNoneMatch,
          'If-Modified-Since': ?ifModifiedSince,
        },
      );
      final status = response.statusCode!;
      if (!allowed.contains(status)) await _throwStatus(response);
      if (status == 304) return _result(response, null);
      _validateJsonContentType(response.headers);
      final bytes = await _read(response, maxBytes: maxBytes);
      final decoded = _decodeJson(bytes);
      final body = decoded.body;
      if (body is Map<String, Object?> && body.containsKey('error')) {
        throw ServerException(status, null, serverErrorCode(body));
      }
      return _result(response, body, rawJsonText: decoded.rawJsonText);
    });
  }

  /// Bounded cover accumulation; never use this API for publication downloads.
  Future<TransportResponse<Uint8List>> getBytes(
    String serverCoverPath, {
    required int maxBytes,
  }) async {
    if (maxBytes < 1) throw ArgumentError('Invalid response byte limit');
    return _run(ServerRoute.cover, (tokens, log) async {
      final uri = session.endpoint.cover(serverCoverPath);
      final response = await _openValidatedResponse(
        uri,
        ServerRoute.cover,
        tokens,
        log,
        maxBytes: maxBytes,
      );
      if (response.statusCode != 200) await _throwStatus(response);
      return _result(response, await _read(response, maxBytes: maxBytes));
    });
  }

  // Phase D seam: reuse this status/redirect/cancellation boundary with a
  // bounded file sink and digest. No public unscoped stream/download API yet.
  Future<Response<ResponseBody>> _openValidatedResponse(
    Uri initial,
    ServerRoute route,
    Set<CancelToken> tokens,
    RedactedRequestLog log, {
    required int maxBytes,
    bool json = false,
    Map<String, Object?> headers = const {},
  }) async {
    final redirects = RedirectPolicy(session.endpoint, initial);
    var uri = initial;
    var hopLog = log;
    while (true) {
      _ensureActive();
      final token = CancelToken();
      tokens.add(token);
      _pending.add(token);
      final response = await _dio.getUri<ResponseBody>(
        uri,
        cancelToken: token,
        options: Options(
          headers: headers,
          extra: {
            RedactedRequestLog.extraKey: hopLog,
            _bodyLimitKey: maxBytes,
            _jsonBodyKey: json,
          },
        ),
      );
      _ensureActive();
      if (!RedirectPolicy.isRedirect(response.statusCode)) return response;
      // Stop receiving before validating/following another hop.
      token.cancel();
      tokens.remove(token);
      _pending.remove(token);
      final locations = response.headers['location'];
      uri = redirects.next(
        uri,
        locations != null && locations.length == 1 ? locations.single : null,
      );
      hopLog = RedactedRequestLog(route);
    }
  }

  Future<Uint8List> _read(
    Response<ResponseBody> response, {
    required int maxBytes,
  }) async {
    final builder = BytesBuilder(copy: false);
    var received = 0;
    await for (final chunk in response.data!.stream) {
      _ensureActive();
      received += chunk.length;
      // Enforced before accumulation, regardless of Content-Length/chunking.
      if (received > maxBytes) {
        // Cancel the upstream response before await-for cancels its consumer;
        // Dio's intermediate stream may otherwise keep draining the source.
        response.requestOptions.cancelToken?.cancel();
        throw const ParseException();
      }
      builder.add(chunk);
    }
    _ensureActive();
    return builder.takeBytes();
  }

  int? _responseLimit(RequestOptions options, ResponseBody response) {
    final status = response.statusCode;
    if (RedirectPolicy.isRedirect(status) ||
        status == 304 ||
        status == 401 ||
        status == 403) {
      return null;
    }
    if (options.extra[_jsonBodyKey] == true || status != 200) {
      try {
        _validateJsonContentType(Headers.fromMap(response.headers));
      } on ParseException {
        return null;
      }
    }
    return status == 200
        ? options.extra[_bodyLimitKey] as int
        : _smallJsonLimit;
  }

  void _validateJsonContentType(Headers headers) {
    final contentTypes = headers['content-type'];
    if (contentTypes != null && contentTypes.length != 1) {
      throw const ParseException();
    }
    final mediaType = contentTypes?.single
        .split(';')
        .first
        .trim()
        .toLowerCase();
    if (mediaType != null &&
        mediaType != 'application/json' &&
        !RegExp(r'^application/[a-z0-9!#$&^_.+-]+\+json$')
            .hasMatch(mediaType)) {
      throw const ParseException();
    }
  }

  ({Object? body, String rawJsonText}) _decodeJson(Uint8List bytes) {
    try {
      final text = utf8.decode(bytes);
      return (body: jsonDecode(text), rawJsonText: text);
    } on FormatException {
      throw const ParseException();
    }
  }

  Future<Never> _throwStatus(Response<ResponseBody> response) async {
    final status = response.statusCode;
    if (status == 401 || status == 403) throw const UnauthorizedException();
    // A bodyless 304 is decided by status before any decoding/receiving.
    if (status == 304) throw const ServerException(304);
    Object? code;
    try {
      _validateJsonContentType(response.headers);
      // Inspect only bounded error envelopes. HTML/error text is never retained.
      final bytes = await _read(response, maxBytes: _smallJsonLimit);
      code = serverErrorCode(_decodeJson(bytes).body);
    } on ParseException {
      // An HTTP failure keeps its status even when its error body is not JSON.
      code = null;
    }
    throw ServerException(status, null, code);
  }

  TransportResponse<T> _result<T>(
    Response<ResponseBody> response,
    T body, {
    String? rawJsonText,
  }) => TransportResponse(
    statusCode: response.statusCode!,
    headers: response.headers.map,
    body: body,
    rawJsonText: rawJsonText,
  );

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final token in _pending.toList()) {
      token.cancel();
    }
    _pending.clear();
    _dio.close(force: true);
  }

  void _ensureActive() {
    if (_disposed) throw const RequestCancelled();
  }

  Future<T> _run<T>(
    ServerRoute route,
    Future<T> Function(Set<CancelToken>, RedactedRequestLog) action,
  ) async {
    _ensureActive();
    final tokens = <CancelToken>{};
    final log = RedactedRequestLog(route);
    try {
      final result = await guardDio(() => action(tokens, log), log: log);
      // A completed/decoded response from a retired activation cannot escape.
      _ensureActive();
      return result;
    } catch (_) {
      _ensureActive();
      rethrow;
    } finally {
      for (final token in tokens) {
        _pending.remove(token);
        // Also closes a body abandoned by redirect/status/size validation.
        token.cancel();
      }
    }
  }
}

/// The coordinator must dispose/invalidate a retired session family instance.
@Riverpod(keepAlive: true)
SessionTransport sessionTransport(Ref ref, ServerSession session) {
  final transport = SessionTransport(session);
  ref.onDispose(transport.dispose);
  return transport;
}
