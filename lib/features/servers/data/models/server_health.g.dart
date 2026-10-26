// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_health.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ServerHealth _$ServerHealthFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_ServerHealth', json, ($checkedConvert) {
      final val = _ServerHealth(
        status: $checkedConvert('status', (v) => v as String),
        service: $checkedConvert('service', (v) => v as String),
        database: $checkedConvert('database', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$ServerHealthToJson(_ServerHealth instance) =>
    <String, dynamic>{
      'status': instance.status,
      'service': instance.service,
      'database': instance.database,
    };
