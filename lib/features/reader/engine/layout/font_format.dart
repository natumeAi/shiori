/// Content-free failures before crossing the native registration boundary.
enum FontFormatFailure { unsupportedFormat, malformed, limitExceeded, missing }

final class FontFormatException implements Exception {
  const FontFormatException(this.failure);
  final FontFormatFailure failure;
}

final class RequiredFontException implements Exception {
  const RequiredFontException(this.cause);
  final Object cause;
}
