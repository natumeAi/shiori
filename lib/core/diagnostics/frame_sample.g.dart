// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'frame_sample.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FrameSample _$FrameSampleFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('_FrameSample', json, ($checkedConvert) {
  final val = _FrameSample(
    frameNumber: $checkedConvert('frameNumber', (v) => (v as num).toInt()),
    vsyncUs: $checkedConvert('vsyncUs', (v) => (v as num).toInt()),
    buildStartUs: $checkedConvert('buildStartUs', (v) => (v as num).toInt()),
    buildFinishUs: $checkedConvert('buildFinishUs', (v) => (v as num).toInt()),
    rasterStartUs: $checkedConvert('rasterStartUs', (v) => (v as num).toInt()),
    rasterFinishUs: $checkedConvert(
      'rasterFinishUs',
      (v) => (v as num).toInt(),
    ),
    rasterFinishWallUs: $checkedConvert(
      'rasterFinishWallUs',
      (v) => (v as num).toInt(),
    ),
    arrivalMonotonicUs: $checkedConvert(
      'arrivalMonotonicUs',
      (v) => (v as num).toInt(),
    ),
  );
  return val;
});

Map<String, dynamic> _$FrameSampleToJson(_FrameSample instance) =>
    <String, dynamic>{
      'frameNumber': instance.frameNumber,
      'vsyncUs': instance.vsyncUs,
      'buildStartUs': instance.buildStartUs,
      'buildFinishUs': instance.buildFinishUs,
      'rasterStartUs': instance.rasterStartUs,
      'rasterFinishUs': instance.rasterFinishUs,
      'rasterFinishWallUs': instance.rasterFinishWallUs,
      'arrivalMonotonicUs': instance.arrivalMonotonicUs,
    };
