// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reading_position.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ReadingPosition _$ReadingPositionFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_ReadingPosition', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const [
          'bookId',
          'cfi',
          'progress',
          'chapterHref',
          'chapterLabel',
          'chapterCount',
          'chapterIndex',
          'updatedAt',
        ],
      );
      final val = _ReadingPosition(
        bookId: $checkedConvert('bookId', (v) => positiveId(v)),
        cfi: $checkedConvert('cfi', (v) => v as String?),
        progress: $checkedConvert('progress', (v) => progressValue(v)),
        chapterHref: $checkedConvert('chapterHref', (v) => v as String?),
        chapterLabel: $checkedConvert('chapterLabel', (v) => v as String?),
        chapterCount: $checkedConvert('chapterCount', (v) => nullableCount(v)),
        chapterIndex: $checkedConvert('chapterIndex', (v) => nullableIndex(v)),
        updatedAt: $checkedConvert(
          'updatedAt',
          (v) => const ServerTimestampConverter().fromJson(v as String),
        ),
      );
      return val;
    });

Map<String, dynamic> _$ReadingPositionToJson(_ReadingPosition instance) =>
    <String, dynamic>{
      'bookId': instance.bookId,
      'cfi': instance.cfi,
      'progress': instance.progress,
      'chapterHref': instance.chapterHref,
      'chapterLabel': instance.chapterLabel,
      'chapterCount': instance.chapterCount,
      'chapterIndex': instance.chapterIndex,
      'updatedAt': const ServerTimestampConverter().toJson(instance.updatedAt),
    };
