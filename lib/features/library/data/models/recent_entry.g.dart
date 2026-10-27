// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recent_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RecentEntry _$RecentEntryFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_RecentEntry', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['bookId', 'progress']);
      final val = _RecentEntry(
        bookId: $checkedConvert('bookId', (v) => positiveId(v)),
        progress: $checkedConvert(
          'progress',
          (v) => ReadingPosition.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$RecentEntryToJson(_RecentEntry instance) =>
    <String, dynamic>{
      'bookId': instance.bookId,
      'progress': instance.progress.toJson(),
    };
