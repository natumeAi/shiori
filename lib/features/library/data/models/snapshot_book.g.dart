// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'snapshot_book.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SnapshotBook _$SnapshotBookFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_SnapshotBook', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const [
          'id',
          'folderId',
          'title',
          'author',
          'identifier',
          'fileName',
          'fileSize',
          'coverPath',
          'coverUrl',
          'coverThumbnailUrl',
          'coverThumbnail2xUrl',
          'coverThumbnailVersion',
          'sortOrder',
          'createdAt',
          'updatedAt',
          'readingProgress',
          'readingUpdatedAt',
        ],
      );
      final val = _SnapshotBook(
        id: $checkedConvert('id', (v) => positiveId(v)),
        folderId: $checkedConvert('folderId', (v) => nullableId(v)),
        title: $checkedConvert('title', (v) => v as String),
        author: $checkedConvert('author', (v) => v as String?),
        identifier: $checkedConvert('identifier', (v) => v as String?),
        fileName: $checkedConvert('fileName', (v) => v as String),
        fileSize: $checkedConvert('fileSize', (v) => nonnegativeInteger(v)),
        coverPath: $checkedConvert('coverPath', (v) => v as String?),
        coverUrl: $checkedConvert('coverUrl', (v) => v as String?),
        coverThumbnailUrl: $checkedConvert(
          'coverThumbnailUrl',
          (v) => v as String?,
        ),
        coverThumbnail2xUrl: $checkedConvert(
          'coverThumbnail2xUrl',
          (v) => v as String?,
        ),
        coverThumbnailVersion: $checkedConvert(
          'coverThumbnailVersion',
          (v) => v as String?,
        ),
        sortOrder: $checkedConvert('sortOrder', (v) => safeInteger(v)),
        createdAt: $checkedConvert(
          'createdAt',
          (v) => const ServerTimestampConverter().fromJson(v as String),
        ),
        updatedAt: $checkedConvert(
          'updatedAt',
          (v) => const ServerTimestampConverter().fromJson(v as String),
        ),
        readingProgress: $checkedConvert(
          'readingProgress',
          (v) => nullableProgress(v),
        ),
        readingUpdatedAt: $checkedConvert(
          'readingUpdatedAt',
          (v) => _$JsonConverterFromJson<String, ServerTimestamp>(
            v,
            const ServerTimestampConverter().fromJson,
          ),
        ),
      );
      return val;
    });

Map<String, dynamic> _$SnapshotBookToJson(_SnapshotBook instance) =>
    <String, dynamic>{
      'id': instance.id,
      'folderId': instance.folderId,
      'title': instance.title,
      'author': instance.author,
      'identifier': instance.identifier,
      'fileName': instance.fileName,
      'fileSize': instance.fileSize,
      'coverPath': instance.coverPath,
      'coverUrl': instance.coverUrl,
      'coverThumbnailUrl': instance.coverThumbnailUrl,
      'coverThumbnail2xUrl': instance.coverThumbnail2xUrl,
      'coverThumbnailVersion': instance.coverThumbnailVersion,
      'sortOrder': instance.sortOrder,
      'createdAt': const ServerTimestampConverter().toJson(instance.createdAt),
      'updatedAt': const ServerTimestampConverter().toJson(instance.updatedAt),
      'readingProgress': instance.readingProgress,
      'readingUpdatedAt': _$JsonConverterToJson<String, ServerTimestamp>(
        instance.readingUpdatedAt,
        const ServerTimestampConverter().toJson,
      ),
    };

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) => json == null ? null : fromJson(json as Json);

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);
