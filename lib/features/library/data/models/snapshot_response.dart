import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shiori/features/library/data/models/library_snapshot.dart';

part 'snapshot_response.freezed.dart';
part 'snapshot_response.g.dart';

@freezed
abstract class SnapshotResponse with _$SnapshotResponse {
  const factory SnapshotResponse({
    @JsonKey(required: true) required LibrarySnapshot snapshot,
  }) = _SnapshotResponse;

  factory SnapshotResponse.fromJson(Map<String, Object?> json) =>
      _$SnapshotResponseFromJson(json);
}
