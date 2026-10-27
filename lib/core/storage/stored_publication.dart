import 'package:shiori/core/config/book_key.dart';

/// Detached cache metadata. Byte generations use generated components only.
final class StoredPublication {
  StoredPublication({
    required this.key,
    required this.sha256,
    required this.byteLength,
    required this.parserVersion,
    required this.canonicalVersion,
    required this.accessedAt,
    this.etag,
    this.lastModified,
    this.isValidated = true,
    this.hasExpectedPath = true,
  }) {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256) ||
        byteLength < 0 ||
        parserVersion < 1 ||
        canonicalVersion < 1) {
      throw ArgumentError('Invalid publication metadata');
    }
  }

  final BookKey key;
  final String sha256;
  final int byteLength;
  final int parserVersion;
  final int canonicalVersion;
  final DateTime accessedAt;
  final String? etag;
  final String? lastModified;

  /// Legacy invalid/empty/path-mismatched rows can be listed and reconciled
  /// without ever resolving their supplied paths.
  final bool isValidated;
  final bool hasExpectedPath;

  String get relativePath => pathFor(key, sha256);

  static String pathFor(BookKey key, String sha256) =>
      'shiori/v1/publications/${key.serverKey.value}/${key.bookId}/$sha256.epub';
}
