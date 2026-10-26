// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'probe_sqlite_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProbeSqliteResult _$ProbeSqliteResultFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('_ProbeSqliteResult', json, ($checkedConvert) {
  final val = _ProbeSqliteResult(
    schemaVersion: $checkedConvert(
      'schemaVersion',
      (v) => (v as num?)?.toInt() ?? 1,
    ),
    checkedAt: $checkedConvert('checkedAt', (v) => DateTime.parse(v as String)),
    buildId: $checkedConvert('buildId', (v) => v as String),
    buildNumber: $checkedConvert('buildNumber', (v) => v as String),
    packageVersion: $checkedConvert('packageVersion', (v) => v as String),
    packageVersionSource: $checkedConvert(
      'packageVersionSource',
      (v) => v as String? ?? 'resolved_pubspec_lock_snapshot',
    ),
    ranOffRootIsolate: $checkedConvert('ranOffRootIsolate', (v) => v as bool),
    steps: $checkedConvert('steps', (v) => Map<String, bool?>.from(v as Map)),
    elapsedUs: $checkedConvert('elapsedUs', (v) => (v as num).toInt()),
    libraryVersion: $checkedConvert('libraryVersion', (v) => v as String?),
    sourceId: $checkedConvert('sourceId', (v) => v as String?),
    compileOptions: $checkedConvert(
      'compileOptions',
      (v) =>
          (v as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
    ),
    journalMode: $checkedConvert('journalMode', (v) => v as String?),
    synchronous: $checkedConvert('synchronous', (v) => (v as num?)?.toInt()),
    failure: $checkedConvert('failure', (v) => v as String?),
  );
  return val;
});

Map<String, dynamic> _$ProbeSqliteResultToJson(_ProbeSqliteResult instance) =>
    <String, dynamic>{
      'schemaVersion': instance.schemaVersion,
      'checkedAt': instance.checkedAt.toIso8601String(),
      'buildId': instance.buildId,
      'buildNumber': instance.buildNumber,
      'packageVersion': instance.packageVersion,
      'packageVersionSource': instance.packageVersionSource,
      'ranOffRootIsolate': instance.ranOffRootIsolate,
      'steps': instance.steps,
      'elapsedUs': instance.elapsedUs,
      'libraryVersion': instance.libraryVersion,
      'sourceId': instance.sourceId,
      'compileOptions': instance.compileOptions,
      'journalMode': instance.journalMode,
      'synchronous': instance.synchronous,
      'failure': instance.failure,
    };
