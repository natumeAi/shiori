import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/core/network/redacted_request_log.dart';
import 'package:shiori/core/network/request_cancelled.dart';
import 'package:shiori/core/network/server_error_code.dart';
import 'package:shiori/core/network/server_route.dart';

/// Converts failures, leaving cancellation as non-error control flow.
/// Logs only safe metadata, never exceptions, stack traces or response text.
Future<T> guardDio<T>(
  Future<T> Function() request, {
  RedactedRequestLog? log,
}) async {
  final fallback = log ?? RedactedRequestLog(ServerRoute.unknown);
  try {
    return await request();
  } on DioException catch (e) {
    if (e.type == DioExceptionType.cancel) throw const RequestCancelled();
    (RedactedRequestLog.from(e.requestOptions) ?? fallback).write(
      e.response?.statusCode,
      failed: true,
    );
    if (e.error is HandshakeException) throw TlsException(e);
    if (e.type == DioExceptionType.unknown && e.error is FormatException) {
      throw ParseException(e);
    }
    throw switch (e.type) {
      DioExceptionType.cancel => const RequestCancelled(),
      DioExceptionType.badCertificate => TlsException(e),
      DioExceptionType.badResponse => switch (e.response?.statusCode) {
        401 || 403 => UnauthorizedException(e),
        final status => ServerException(
          status,
          e,
          serverErrorCode(e.response?.data),
        ),
      },
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError ||
      DioExceptionType.transformTimeout ||
      DioExceptionType.unknown => NetworkException(e),
    };
  } on HandshakeException catch (e) {
    fallback.write(null, failed: true);
    throw TlsException(e);
  } on SocketException catch (e) {
    fallback.write(null, failed: true);
    throw NetworkException(e);
  } on HttpException catch (e) {
    fallback.write(null, failed: true);
    throw NetworkException(e);
  } on TimeoutException catch (e) {
    fallback.write(null, failed: true);
    throw NetworkException(e);
  } on FormatException {
    fallback.write(null, failed: true);
    // FormatException.source may contain the entire private response body.
    throw const ParseException();
  } on CheckedFromJsonException catch (e) {
    fallback.write(null, failed: true);
    throw ParseException(e);
  } on TypeError catch (e) {
    fallback.write(null, failed: true);
    throw ParseException(e);
  }
}
