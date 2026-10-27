// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_snapshot.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LibrarySnapshot _$LibrarySnapshotFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_LibrarySnapshot', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const [
          'schemaVersion',
          'version',
          'books',
          'folders',
          'shelf',
          'recent',
        ],
      );
      final val = _LibrarySnapshot(
        schemaVersion: $checkedConvert(
          'schemaVersion',
          (v) => snapshotSchemaVersion(v),
        ),
        version: $checkedConvert('version', (v) => nonnegativeInteger(v)),
        books: $checkedConvert(
          'books',
          (v) => (v as List<dynamic>)
              .map((e) => SnapshotBook.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        folders: $checkedConvert(
          'folders',
          (v) => (v as List<dynamic>)
              .map((e) => SnapshotFolder.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        shelf: $checkedConvert(
          'shelf',
          (v) => (v as List<dynamic>)
              .map((e) => ShelfRef.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        recent: $checkedConvert(
          'recent',
          (v) => (v as List<dynamic>)
              .map((e) => RecentEntry.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$LibrarySnapshotToJson(_LibrarySnapshot instance) =>
    <String, dynamic>{
      'schemaVersion': instance.schemaVersion,
      'version': instance.version,
      'books': instance.books.map((e) => e.toJson()).toList(),
      'folders': instance.folders.map((e) => e.toJson()).toList(),
      'shelf': instance.shelf.map((e) => e.toJson()).toList(),
      'recent': instance.recent.map((e) => e.toJson()).toList(),
    };
