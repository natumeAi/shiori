import 'package:shiori/core/config/book_key.dart';

/// Bump when the EPUB/source projection changes incompatibly.
const publicationParserVersion = 1;

/// Canonical normalization v1; kept feature-independent for cache consumers.
const publicationCanonicalVersion = 1;

/// Identity of verified bytes and the interpretation used for derived data.
/// The downloader supplies the actual streamed SHA-256, not an HTTP validator.
final class ContentIdentity {
  ContentIdentity(
    this.bookKey,
    String sha256, {
    this.parserVersion = publicationParserVersion,
    this.canonicalVersion = publicationCanonicalVersion,
  }) : sha256 = sha256.toLowerCase() {
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(sha256)) {
      throw ArgumentError('Expected a SHA-256 digest');
    }
    if (parserVersion < 1 || canonicalVersion < 1) {
      throw ArgumentError('Content versions must be positive');
    }
  }

  final BookKey bookKey;
  final String sha256;
  final int parserVersion;
  final int canonicalVersion;

  bool get isCurrent =>
      parserVersion == publicationParserVersion &&
      canonicalVersion == publicationCanonicalVersion;

  @override
  bool operator ==(Object other) =>
      other is ContentIdentity &&
      bookKey == other.bookKey &&
      sha256 == other.sha256 &&
      parserVersion == other.parserVersion &&
      canonicalVersion == other.canonicalVersion;

  @override
  int get hashCode =>
      Object.hash(bookKey, sha256, parserVersion, canonicalVersion);
}
