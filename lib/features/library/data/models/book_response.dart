import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shiori/features/library/data/models/book.dart';

part 'book_response.freezed.dart';
part 'book_response.g.dart';

@freezed
abstract class BookResponse with _$BookResponse {
  const factory BookResponse({@JsonKey(required: true) required Book book}) =
      _BookResponse;

  factory BookResponse.fromJson(Map<String, Object?> json) =>
      _$BookResponseFromJson(json);
}
