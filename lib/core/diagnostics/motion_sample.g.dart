// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'motion_sample.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MotionSample _$MotionSampleFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_MotionSample', json, ($checkedConvert) {
      final val = _MotionSample(
        frameNumber: $checkedConvert('frameNumber', (v) => (v as num).toInt()),
        schedulerUs: $checkedConvert('schedulerUs', (v) => (v as num).toInt()),
        rawSchedulerUs: $checkedConvert(
          'rawSchedulerUs',
          (v) => (v as num).toInt(),
        ),
        monotonicUs: $checkedConvert('monotonicUs', (v) => (v as num).toInt()),
        progress: $checkedConvert('progress', (v) => (v as num).toDouble()),
      );
      return val;
    });

Map<String, dynamic> _$MotionSampleToJson(_MotionSample instance) =>
    <String, dynamic>{
      'frameNumber': instance.frameNumber,
      'schedulerUs': instance.schedulerUs,
      'rawSchedulerUs': instance.rawSchedulerUs,
      'monotonicUs': instance.monotonicUs,
      'progress': instance.progress,
    };
