// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reader_feasibility_record.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ReaderFeasibilityRecord _$ReaderFeasibilityRecordFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('_ReaderFeasibilityRecord', json, ($checkedConvert) {
  final val = _ReaderFeasibilityRecord(
    kind: $checkedConvert('kind', (v) => v as String? ?? 'reader_feasibility'),
    schemaVersion: $checkedConvert(
      'schemaVersion',
      (v) => (v as num?)?.toInt() ?? 1,
    ),
    bookSha256: $checkedConvert('bookSha256', (v) => v as String),
    fixtureId: $checkedConvert('fixtureId', (v) => v as String?),
    scenarioId: $checkedConvert('scenarioId', (v) => v as String),
    repeatIndex: $checkedConvert('repeatIndex', (v) => (v as num).toInt()),
    repeatCount: $checkedConvert('repeatCount', (v) => (v as num).toInt()),
    input: $checkedConvert('input', (v) => v as String),
    engine: $checkedConvert(
      'engine',
      (v) => DiagnosticRecord.fromJson(v as Map<String, dynamic>),
    ),
    readerEvents: $checkedConvert(
      'readerEvents',
      (v) =>
          (v as List<dynamic>).map((e) => e as Map<String, dynamic>).toList(),
    ),
    layoutCosts: $checkedConvert(
      'layoutCosts',
      (v) =>
          (v as List<dynamic>).map((e) => e as Map<String, dynamic>).toList(),
    ),
    resources: $checkedConvert(
      'resources',
      (v) =>
          (v as List<dynamic>).map((e) => e as Map<String, dynamic>).toList(),
    ),
    presentation: $checkedConvert(
      'presentation',
      (v) => v as Map<String, dynamic>,
    ),
    aggregates: $checkedConvert('aggregates', (v) => v as Map<String, dynamic>),
    overflow: $checkedConvert(
      'overflow',
      (v) => Map<String, int>.from(v as Map),
    ),
    omissions: $checkedConvert('omissions', (v) => v as Map<String, dynamic>),
  );
  return val;
});

Map<String, dynamic> _$ReaderFeasibilityRecordToJson(
  _ReaderFeasibilityRecord instance,
) => <String, dynamic>{
  'kind': instance.kind,
  'schemaVersion': instance.schemaVersion,
  'bookSha256': instance.bookSha256,
  'fixtureId': instance.fixtureId,
  'scenarioId': instance.scenarioId,
  'repeatIndex': instance.repeatIndex,
  'repeatCount': instance.repeatCount,
  'input': instance.input,
  'engine': instance.engine.toJson(),
  'readerEvents': instance.readerEvents,
  'layoutCosts': instance.layoutCosts,
  'resources': instance.resources,
  'presentation': instance.presentation,
  'aggregates': instance.aggregates,
  'overflow': instance.overflow,
  'omissions': instance.omissions,
};
