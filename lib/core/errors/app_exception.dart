/// Every failure a repository can surface. Callers above the data layer only
/// ever see these types (see `guardDio`).
sealed class AppException implements Exception {
  const AppException([this.cause]);

  final Object? cause;
}

/// No connection, timeout, or other transport failure. Retried automatically.
final class NetworkException extends AppException {
  const NetworkException([super.cause]);
}

/// 401 / 403 from the API.
final class UnauthorizedException extends AppException {
  const UnauthorizedException([super.cause]);
}

/// Any other non-2xx response.
final class ServerException extends AppException {
  const ServerException(this.statusCode, [super.cause]);

  final int? statusCode;
}

/// The response body could not be decoded or did not match the expected
/// JSON shape. Not retried.
final class ParseException extends AppException {
  const ParseException([super.cause]);
}
