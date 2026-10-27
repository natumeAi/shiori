// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'snapshot_folder.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SnapshotFolder _$SnapshotFolderFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_SnapshotFolder', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const [
          'id',
          'name',
          'sortOrder',
          'bookCount',
          'bookIds',
          'previewBookIds',
          'createdAt',
          'updatedAt',
        ],
      );
      final val = _SnapshotFolder(
        id: $checkedConvert('id', (v) => positiveId(v)),
        name: $checkedConvert('name', (v) => v as String),
        sortOrder: $checkedConvert('sortOrder', (v) => safeInteger(v)),
        bookCount: $checkedConvert('bookCount', (v) => nonnegativeInteger(v)),
        bookIds: $checkedConvert('bookIds', (v) => idList(v)),
        previewBookIds: $checkedConvert('previewBookIds', (v) => idList(v)),
        createdAt: $checkedConvert(
          'createdAt',
          (v) => const ServerTimestampConverter().fromJson(v as String),
        ),
        updatedAt: $checkedConvert(
          'updatedAt',
          (v) => const ServerTimestampConverter().fromJson(v as String),
        ),
      );
      return val;
    });

Map<String, dynamic> _$SnapshotFolderToJson(_SnapshotFolder instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'sortOrder': instance.sortOrder,
      'bookCount': instance.bookCount,
      'bookIds': instance.bookIds,
      'previewBookIds': instance.previewBookIds,
      'createdAt': const ServerTimestampConverter().toJson(instance.createdAt),
      'updatedAt': const ServerTimestampConverter().toJson(instance.updatedAt),
    };
