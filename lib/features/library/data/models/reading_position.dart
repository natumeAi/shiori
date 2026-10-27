import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shiori/features/library/data/models/server_timestamp.dart';
import 'package:shiori/features/library/data/models/wire_numbers.dart';

part 'reading_position.freezed.dart';
part 'reading_position.g.dart';

@freezed
abstract class ReadingPosition with _$ReadingPosition {
  @ServerTimestampConverter()
  const factory ReadingPosition({
    @JsonKey(required: true, fromJson: positiveId) required int bookId,
    @JsonKey(required: true) required String? cfi,
    @JsonKey(required: true, fromJson: progressValue) required double progress,
    @JsonKey(required: true) required String? chapterHref,
    @JsonKey(required: true) required String? chapterLabel,
    @JsonKey(required: true, fromJson: nullableCount)
    required int? chapterCount,
    @JsonKey(required: true, fromJson: nullableIndex)
    required int? chapterIndex,
    @JsonKey(required: true) required ServerTimestamp updatedAt,
  }) = _ReadingPosition;

  factory ReadingPosition.fromJson(Map<String, Object?> json) =>
      _$ReadingPositionFromJson(json);
}
