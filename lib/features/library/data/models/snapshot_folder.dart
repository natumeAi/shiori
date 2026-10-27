import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shiori/features/library/data/models/server_timestamp.dart';
import 'package:shiori/features/library/data/models/wire_numbers.dart';

part 'snapshot_folder.freezed.dart';
part 'snapshot_folder.g.dart';

@freezed
abstract class SnapshotFolder with _$SnapshotFolder {
  @ServerTimestampConverter()
  const factory SnapshotFolder({
    @JsonKey(required: true, fromJson: positiveId) required int id,
    @JsonKey(required: true) required String name,
    @JsonKey(required: true, fromJson: safeInteger) required int sortOrder,
    @JsonKey(required: true, fromJson: nonnegativeInteger)
    required int bookCount,
    @JsonKey(required: true, fromJson: idList) required List<int> bookIds,
    @JsonKey(required: true, fromJson: idList)
    required List<int> previewBookIds,
    @JsonKey(required: true) required ServerTimestamp createdAt,
    @JsonKey(required: true) required ServerTimestamp updatedAt,
  }) = _SnapshotFolder;

  factory SnapshotFolder.fromJson(Map<String, Object?> json) =>
      _$SnapshotFolderFromJson(json);
}
