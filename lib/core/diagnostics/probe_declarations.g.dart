// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'probe_declarations.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProbeDeclarations _$ProbeDeclarationsFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_ProbeDeclarations', json, ($checkedConvert) {
      final val = _ProbeDeclarations(
        deviceModel: $checkedConvert('deviceModel', (v) => v as String? ?? ''),
        lowPowerMode: $checkedConvert(
          'lowPowerMode',
          (v) =>
              $enumDecodeNullable(_$DeclaredSettingEnumMap, v) ??
              DeclaredSetting.unknown,
        ),
        limitFrameRate: $checkedConvert(
          'limitFrameRate',
          (v) =>
              $enumDecodeNullable(_$DeclaredSettingEnumMap, v) ??
              DeclaredSetting.unknown,
        ),
        charging: $checkedConvert(
          'charging',
          (v) =>
              $enumDecodeNullable(_$DeclaredSettingEnumMap, v) ??
              DeclaredSetting.unknown,
        ),
        warm: $checkedConvert(
          'warm',
          (v) =>
              $enumDecodeNullable(_$DeclaredSettingEnumMap, v) ??
              DeclaredSetting.unknown,
        ),
        source: $checkedConvert(
          'source',
          (v) => v as String? ?? 'user_provided',
        ),
      );
      return val;
    });

Map<String, dynamic> _$ProbeDeclarationsToJson(_ProbeDeclarations instance) =>
    <String, dynamic>{
      'deviceModel': instance.deviceModel,
      'lowPowerMode': _$DeclaredSettingEnumMap[instance.lowPowerMode]!,
      'limitFrameRate': _$DeclaredSettingEnumMap[instance.limitFrameRate]!,
      'charging': _$DeclaredSettingEnumMap[instance.charging]!,
      'warm': _$DeclaredSettingEnumMap[instance.warm]!,
      'source': instance.source,
    };

const _$DeclaredSettingEnumMap = {
  DeclaredSetting.on: 'on',
  DeclaredSetting.off: 'off',
  DeclaredSetting.unknown: 'unknown',
};
