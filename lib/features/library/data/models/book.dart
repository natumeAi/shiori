import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shiori/features/library/data/models/server_timestamp.dart';
import 'package:shiori/features/library/data/models/wire_numbers.dart';

part 'book.freezed.dart';
part 'book.g.dart';

@freezed
abstract class Book with _$Book {
  @ServerTimestampConverter()
  const factory Book({
    @JsonKey(required: true, fromJson: positiveId) required int id,
    @JsonKey(required: true, fromJson: nullableId) required int? folderId,
    @JsonKey(required: true) required String title,
    @JsonKey(required: true) required String? author,
    @JsonKey(required: true) required String? description,
    @JsonKey(required: true) required String? publisher,
    @JsonKey(required: true) required String? language,
    @JsonKey(required: true) required String? identifier,
    @JsonKey(required: true) required String fileName,
    @JsonKey(required: true, fromJson: nonnegativeInteger)
    required int fileSize,
    @JsonKey(required: true) required String? coverPath,
    @JsonKey(required: true) required String? coverUrl,
    @JsonKey(required: true) required String? coverThumbnailSmallPath,
    @JsonKey(required: true) required String? coverThumbnailLargePath,
    @JsonKey(required: true) required String? coverThumbnailUrl,
    @JsonKey(required: true) required String? coverThumbnail2xUrl,
    @JsonKey(required: true) required String? coverThumbnailVersion,
    @JsonKey(required: true, fromJson: safeInteger) required int sortOrder,
    @JsonKey(required: true) required ServerTimestamp createdAt,
    @JsonKey(required: true) required ServerTimestamp updatedAt,
  }) = _Book;

  factory Book.fromJson(Map<String, Object?> json) => _$BookFromJson(json);
}
