import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shiori/features/library/data/library_decode_exception.dart';
import 'package:shiori/features/library/data/models/wire_numbers.dart';

part 'shelf_ref.freezed.dart';
part 'shelf_ref.g.dart';

@Freezed(unionKey: 'type')
sealed class ShelfRef with _$ShelfRef {
  const ShelfRef._();

  const factory ShelfRef.book({
    @JsonKey(required: true, fromJson: positiveId) required int id,
    @JsonKey(required: true, fromJson: safeInteger) required int sortOrder,
  }) = ShelfBookRef;

  const factory ShelfRef.folder({
    @JsonKey(required: true, fromJson: positiveId) required int id,
    @JsonKey(required: true, fromJson: safeInteger) required int sortOrder,
  }) = ShelfFolderRef;

  factory ShelfRef.fromJson(Map<String, Object?> json) =>
      _$ShelfRefFromJson(_checkedShelf(json));
}

Map<String, Object?> _checkedShelf(Map<String, Object?> json) {
  if (json['type'] != 'book' && json['type'] != 'folder') {
    throw const LibraryDecodeException(LibraryInvariant.shelfType);
  }
  return json;
}
