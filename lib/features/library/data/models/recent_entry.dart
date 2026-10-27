import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shiori/features/library/data/models/reading_position.dart';
import 'package:shiori/features/library/data/models/wire_numbers.dart';

part 'recent_entry.freezed.dart';
part 'recent_entry.g.dart';

@freezed
abstract class RecentEntry with _$RecentEntry {
  const factory RecentEntry({
    @JsonKey(required: true, fromJson: positiveId) required int bookId,
    @JsonKey(required: true) required ReadingPosition progress,
  }) = _RecentEntry;

  factory RecentEntry.fromJson(Map<String, Object?> json) =>
      _$RecentEntryFromJson(json);
}
