// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diagnostic_record.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DiagnosticRecord _$DiagnosticRecordFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('_DiagnosticRecord', json, ($checkedConvert) {
  final val = _DiagnosticRecord(
    schemaVersion: $checkedConvert(
      'schemaVersion',
      (v) => (v as num?)?.toInt() ?? 1,
    ),
    scenarioId: $checkedConvert(
      'scenarioId',
      (v) => v as String? ?? 'synthetic_transform',
    ),
    runId: $checkedConvert('runId', (v) => v as String),
    buildId: $checkedConvert('buildId', (v) => v as String),
    startedAt: $checkedConvert('startedAt', (v) => DateTime.parse(v as String)),
    stoppedAt: $checkedConvert('stoppedAt', (v) => DateTime.parse(v as String)),
    startedMonotonicUs: $checkedConvert(
      'startedMonotonicUs',
      (v) => (v as num).toInt(),
    ),
    stoppedMonotonicUs: $checkedConvert(
      'stoppedMonotonicUs',
      (v) => (v as num).toInt(),
    ),
    finalizedMonotonicUs: $checkedConvert(
      'finalizedMonotonicUs',
      (v) => (v as num).toInt(),
    ),
    stopReason: $checkedConvert('stopReason', (v) => v as String),
    declarations: $checkedConvert(
      'declarations',
      (v) => ProbeDeclarations.fromJson(v as Map<String, dynamic>),
    ),
    metadata: $checkedConvert('metadata', (v) => v as Map<String, dynamic>),
    clocks: $checkedConvert('clocks', (v) => v as Map<String, dynamic>),
    frames: $checkedConvert(
      'frames',
      (v) => (v as List<dynamic>)
          .map((e) => FrameSample.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    motion: $checkedConvert(
      'motion',
      (v) => (v as List<dynamic>)
          .map((e) => MotionSample.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    frameOverflow: $checkedConvert('frameOverflow', (v) => (v as num).toInt()),
    motionOverflow: $checkedConvert(
      'motionOverflow',
      (v) => (v as num).toInt(),
    ),
    reportsDuringDrain: $checkedConvert(
      'reportsDuringDrain',
      (v) => (v as num).toInt(),
    ),
    omittedOutsideMotion: $checkedConvert(
      'omittedOutsideMotion',
      (v) => (v as num).toInt(),
    ),
    incompleteTrailingBatch: $checkedConvert(
      'incompleteTrailingBatch',
      (v) => v as bool,
    ),
    errors: $checkedConvert(
      'errors',
      (v) => (v as List<dynamic>).map((e) => e as String).toList(),
    ),
    aggregates: $checkedConvert('aggregates', (v) => v as Map<String, dynamic>),
    physicalPresentation: $checkedConvert(
      'physicalPresentation',
      (v) => v as String? ?? 'unverified',
    ),
  );
  return val;
});

Map<String, dynamic> _$DiagnosticRecordToJson(_DiagnosticRecord instance) =>
    <String, dynamic>{
      'schemaVersion': instance.schemaVersion,
      'scenarioId': instance.scenarioId,
      'runId': instance.runId,
      'buildId': instance.buildId,
      'startedAt': instance.startedAt.toIso8601String(),
      'stoppedAt': instance.stoppedAt.toIso8601String(),
      'startedMonotonicUs': instance.startedMonotonicUs,
      'stoppedMonotonicUs': instance.stoppedMonotonicUs,
      'finalizedMonotonicUs': instance.finalizedMonotonicUs,
      'stopReason': instance.stopReason,
      'declarations': instance.declarations.toJson(),
      'metadata': instance.metadata,
      'clocks': instance.clocks,
      'frames': instance.frames.map((e) => e.toJson()).toList(),
      'motion': instance.motion.map((e) => e.toJson()).toList(),
      'frameOverflow': instance.frameOverflow,
      'motionOverflow': instance.motionOverflow,
      'reportsDuringDrain': instance.reportsDuringDrain,
      'omittedOutsideMotion': instance.omittedOutsideMotion,
      'incompleteTrailingBatch': instance.incompleteTrailingBatch,
      'errors': instance.errors,
      'aggregates': instance.aggregates,
      'physicalPresentation': instance.physicalPresentation,
    };
