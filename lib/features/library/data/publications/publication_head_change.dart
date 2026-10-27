import 'package:shiori/core/config/book_key.dart';

/// Integration maps this byte change to the later versioned content identity.
final class PublicationHeadChange {
  const PublicationHeadChange(this.key, this.previousDigest, this.newDigest);
  final BookKey key;
  final String? previousDigest;
  final String newDigest;
}
