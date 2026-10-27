// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Book _$BookFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_Book', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const [
          'id',
          'folderId',
          'title',
          'author',
          'description',
          'publisher',
          'language',
          'identifier',
          'fileName',
          'fileSize',
          'coverPath',
          'coverUrl',
          'coverThumbnailSmallPath',
          'coverThumbnailLargePath',
          'coverThumbnailUrl',
          'coverThumbnail2xUrl',
          'coverThumbnailVersion',
          'sortOrder',
          'createdAt',
          'updatedAt',
        ],
      );
      final val = _Book(
        id: $checkedConvert('id', (v) => positiveId(v)),
        folderId: $checkedConvert('folderId', (v) => nullableId(v)),
        title: $checkedConvert('title', (v) => v as String),
        author: $checkedConvert('author', (v) => v as String?),
        description: $checkedConvert('description', (v) => v as String?),
        publisher: $checkedConvert('publisher', (v) => v as String?),
        language: $checkedConvert('language', (v) => v as String?),
        identifier: $checkedConvert('identifier', (v) => v as String?),
        fileName: $checkedConvert('fileName', (v) => v as String),
        fileSize: $checkedConvert('fileSize', (v) => nonnegativeInteger(v)),
        coverPath: $checkedConvert('coverPath', (v) => v as String?),
        coverUrl: $checkedConvert('coverUrl', (v) => v as String?),
        coverThumbnailSmallPath: $checkedConvert(
          'coverThumbnailSmallPath',
          (v) => v as String?,
        ),
        coverThumbnailLargePath: $checkedConvert(
          'coverThumbnailLargePath',
          (v) => v as String?,
        ),
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
      );
      return val;
    });

Map<String, dynamic> _$BookToJson(_Book instance) => <String, dynamic>{
  'id': instance.id,
  'folderId': instance.folderId,
  'title': instance.title,
  'author': instance.author,
  'description': instance.description,
  'publisher': instance.publisher,
  'language': instance.language,
  'identifier': instance.identifier,
  'fileName': instance.fileName,
  'fileSize': instance.fileSize,
  'coverPath': instance.coverPath,
  'coverUrl': instance.coverUrl,
  'coverThumbnailSmallPath': instance.coverThumbnailSmallPath,
  'coverThumbnailLargePath': instance.coverThumbnailLargePath,
  'coverThumbnailUrl': instance.coverThumbnailUrl,
  'coverThumbnail2xUrl': instance.coverThumbnail2xUrl,
  'coverThumbnailVersion': instance.coverThumbnailVersion,
  'sortOrder': instance.sortOrder,
  'createdAt': const ServerTimestampConverter().toJson(instance.createdAt),
  'updatedAt': const ServerTimestampConverter().toJson(instance.updatedAt),
};
