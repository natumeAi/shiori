import 'package:shiori/core/config/server_key.dart';

/// A server-scoped book record; publication bytes have a separate identity.
final class BookKey {
  BookKey(this.serverKey, this.bookId) {
    if (bookId < 1 || bookId > maxBookId) {
      throw RangeError.range(bookId, 1, maxBookId, 'bookId');
    }
  }

  static const maxBookId = 9007199254740991;

  final ServerKey serverKey;
  final int bookId;

  @override
  bool operator ==(Object other) =>
      other is BookKey &&
      serverKey == other.serverKey &&
      bookId == other.bookId;

  @override
  int get hashCode => Object.hash(serverKey, bookId);
}
