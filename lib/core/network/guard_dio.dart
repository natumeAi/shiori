import 'package:dio/dio.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:logging/logging.dart';
import 'package:shiori/core/errors/app_exception.dart';

final _log = Logger('Network');

/// Runs a repository request and converts transport and parse failures into
/// [AppException] subtypes. The failure is logged here, once.
Future<T> guardDio<T>(Future<T> Function() request) async {
  try {
    return await request();
  } on DioException catch (e, stack) {
    if (e.type == DioExceptionType.unknown && e.error is FormatException) {
      // Dio reports a body it cannot decode (malformed JSON, invalid UTF-8)
      // as `unknown`. That is a parse failure, not a transport one.
      _log.severe('Undecodable response body', e, stack);
      throw ParseException(e);
    }
    _log.warning(
      '${e.requestOptions.method} ${e.requestOptions.path} failed',
      e,
      stack,
    );
    throw switch (e.type) {
      DioExceptionType.badResponse => switch (e.response?.statusCode) {
        401 || 403 => UnauthorizedException(e),
        final code => ServerException(code, e),
      },
      _ => NetworkException(e),
    };
  } on CheckedFromJsonException catch (e, stack) {
    _log.severe('Unexpected JSON shape', e, stack);
    throw ParseException(e);
  } on TypeError catch (e, stack) {
    // Casts at the JSON boundary (`json as Map<String, Object?>`).
    _log.severe('Unexpected JSON shape', e, stack);
    throw ParseException(e);
  }
}
