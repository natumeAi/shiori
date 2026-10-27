import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/features/library/data/models/book.dart';

part 'book_detail_result.freezed.dart';

@freezed
sealed class BookDetailResult with _$BookDetailResult {
  const factory BookDetailResult.available(BookKey key, Book book) =
      BookAvailable;
  const factory BookDetailResult.unavailable(BookKey key) = BookUnavailable;
}
