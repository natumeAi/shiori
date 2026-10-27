// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shelf_ref.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ShelfBookRef _$ShelfBookRefFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ShelfBookRef', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['id', 'sortOrder']);
      final val = ShelfBookRef(
        id: $checkedConvert('id', (v) => positiveId(v)),
        sortOrder: $checkedConvert('sortOrder', (v) => safeInteger(v)),
        $type: $checkedConvert('type', (v) => v as String?),
      );
      return val;
    }, fieldKeyMap: const {r'$type': 'type'});

Map<String, dynamic> _$ShelfBookRefToJson(ShelfBookRef instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sortOrder': instance.sortOrder,
      'type': instance.$type,
    };

ShelfFolderRef _$ShelfFolderRefFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ShelfFolderRef', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['id', 'sortOrder']);
      final val = ShelfFolderRef(
        id: $checkedConvert('id', (v) => positiveId(v)),
        sortOrder: $checkedConvert('sortOrder', (v) => safeInteger(v)),
        $type: $checkedConvert('type', (v) => v as String?),
      );
      return val;
    }, fieldKeyMap: const {r'$type': 'type'});

Map<String, dynamic> _$ShelfFolderRefToJson(ShelfFolderRef instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sortOrder': instance.sortOrder,
      'type': instance.$type,
    };
