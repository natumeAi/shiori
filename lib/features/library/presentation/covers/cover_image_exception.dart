import 'package:shiori/features/library/presentation/covers/cover_failure.dart';

/// An Image.errorBuilder consumes this typed reason and renders its placeholder.
final class CoverImageException implements Exception {
  const CoverImageException(this.reason);
  final CoverFailure reason;
}
