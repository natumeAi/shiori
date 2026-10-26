/// Recoverable failures. Session cancellation is separate control flow.
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
  const ServerException(this.statusCode, [super.cause, this.code]);

  final int? statusCode;

  /// Opaque server code, including unknown future values. Never display/log it.
  final Object? code;
}

/// The response body could not be decoded or did not match the expected
/// JSON shape. Not retried.
final class ParseException extends AppException {
  const ParseException([super.cause]);
}

/// Certificate verification or TLS negotiation failed. No automatic retry.
final class TlsException extends AppException {
  const TlsException([super.cause]);
}

enum RedirectIssue { invalidTarget, outsideDeployment, loop, limit }

/// Recover by asking the user to enter the final deployment root.
final class RedirectException extends AppException {
  const RedirectException(this.issue);

  final RedirectIssue issue;
  String get recoveryMessage => 'Enter the final deployment root.';
}
