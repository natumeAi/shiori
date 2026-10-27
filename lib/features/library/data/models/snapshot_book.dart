import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shiori/features/library/data/models/server_timestamp.dart';
import 'package:shiori/features/library/data/models/wire_numbers.dart';

part 'snapshot_book.freezed.dart';
part 'snapshot_book.g.dart';

@freezed
abstract class SnapshotBook with _$SnapshotBook {
  @ServerTimestampConverter()
  const factory SnapshotBook({
    @JsonKey(required: true, fromJson: positiveId) required int id,
    @JsonKey(required: true, fromJson: nullableId) required int? folderId,
    @JsonKey(required: true) required String title,
    @JsonKey(required: true) required String? author,
    @JsonKey(required: true) required String? identifier,
    @JsonKey(required: true) required String fileName,
    @JsonKey(required: true, fromJson: nonnegativeInteger)
    required int fileSize,
    @JsonKey(required: true) required String? coverPath,
    @JsonKey(required: true) required String? coverUrl,
    @JsonKey(required: true) required String? coverThumbnailUrl,
    @JsonKey(required: true) required String? coverThumbnail2xUrl,
    @JsonKey(required: true) required String? coverThumbnailVersion,
    @JsonKey(required: true, fromJson: safeInteger) required int sortOrder,
    @JsonKey(required: true) required ServerTimestamp createdAt,
    @JsonKey(required: true) required ServerTimestamp updatedAt,
    @JsonKey(required: true, fromJson: nullableProgress)
    required double? readingProgress,
    @JsonKey(required: true) required ServerTimestamp? readingUpdatedAt,
  }) = _SnapshotBook;

  factory SnapshotBook.fromJson(Map<String, Object?> json) =>
      _$SnapshotBookFromJson(json);
}
