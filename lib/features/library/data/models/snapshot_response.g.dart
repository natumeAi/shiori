// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'snapshot_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SnapshotResponse _$SnapshotResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_SnapshotResponse', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['snapshot']);
      final val = _SnapshotResponse(
        snapshot: $checkedConvert(
          'snapshot',
          (v) => LibrarySnapshot.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$SnapshotResponseToJson(_SnapshotResponse instance) =>
    <String, dynamic>{'snapshot': instance.snapshot.toJson()};
