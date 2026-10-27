import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shiori/features/library/data/models/recent_entry.dart';
import 'package:shiori/features/library/data/models/shelf_ref.dart';
import 'package:shiori/features/library/data/models/snapshot_book.dart';
import 'package:shiori/features/library/data/models/snapshot_folder.dart';
import 'package:shiori/features/library/data/models/wire_numbers.dart';

part 'library_snapshot.freezed.dart';
part 'library_snapshot.g.dart';

@freezed
abstract class LibrarySnapshot with _$LibrarySnapshot {
  const factory LibrarySnapshot({
    @JsonKey(required: true, fromJson: snapshotSchemaVersion)
    required int schemaVersion,
    @JsonKey(required: true, fromJson: nonnegativeInteger) required int version,
    @JsonKey(required: true) required List<SnapshotBook> books,
    @JsonKey(required: true) required List<SnapshotFolder> folders,
    @JsonKey(required: true) required List<ShelfRef> shelf,
    @JsonKey(required: true) required List<RecentEntry> recent,
  }) = _LibrarySnapshot;

  factory LibrarySnapshot.fromJson(Map<String, Object?> json) =>
      _$LibrarySnapshotFromJson(json);
}
