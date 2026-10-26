import 'package:freezed_annotation/freezed_annotation.dart';

part 'probe_sqlite_result.freezed.dart';
part 'probe_sqlite_result.g.dart';

@freezed
abstract class ProbeSqliteResult with _$ProbeSqliteResult {
  const ProbeSqliteResult._();

  const factory ProbeSqliteResult({
    @Default(1) int schemaVersion,
    required DateTime checkedAt,
    required String buildId,
    required String buildNumber,
    required String packageVersion,
    @Default('resolved_pubspec_lock_snapshot') String packageVersionSource,
    required bool ranOffRootIsolate,
    required Map<String, bool?> steps,
    required int elapsedUs,
    String? libraryVersion,
    String? sourceId,
    @Default([]) List<String> compileOptions,
    String? journalMode,
    int? synchronous,
    String? failure,
  }) = _ProbeSqliteResult;

  factory ProbeSqliteResult.fromJson(Map<String, Object?> json) =>
      _$ProbeSqliteResultFromJson(_validatedJson(json));

  static Map<String, Object?> _validatedJson(Map<String, Object?> json) {
    // Generated defaults and num.toInt() must not repair persisted evidence.
    if (json['schemaVersion'] is! int || json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported SQLite self-check schema');
    }
    final checkedAt = json['checkedAt'];
    final steps = json['steps'];
    final elapsedUs = json['elapsedUs'];
    final synchronous = json['synchronous'];
    final compileOptions = json['compileOptions'];
    if (checkedAt is! String ||
        DateTime.tryParse(checkedAt)?.isUtc != true ||
        ![
          'buildId',
          'buildNumber',
          'packageVersion',
          'packageVersionSource',
        ].every((key) => json[key] is String) ||
        json['ranOffRootIsolate'] is! bool ||
        steps is! Map<String, Object?> ||
        steps.length != stepNames.length ||
        !stepNames.every(steps.containsKey) ||
        !steps.values.every((value) => value == null || value is bool) ||
        elapsedUs is! int ||
        elapsedUs < 0 ||
        (synchronous != null && synchronous is! int) ||
        (compileOptions != null &&
            (compileOptions is! List ||
                !compileOptions.every((value) => value is String))) ||
        ![
          'libraryVersion',
          'sourceId',
          'journalMode',
          'failure',
        ].every((key) => json[key] == null || json[key] is String)) {
      throw const FormatException('Invalid SQLite self-check result');
    }
    return json;
  }

  static const metadataKey = 'sqliteSelfCheck';
  static const stepNames = [
    'open',
    'commit',
    'reopen',
    'rollback',
    'futureSchema',
    'cleanup',
  ];

  bool get passed => stepNames.every((name) => steps[name] == true);

  static ProbeSqliteResult? fromMetadata(Map<String, Object?> metadata) {
    if (!metadata.containsKey(metadataKey)) return null;
    final json = metadata[metadataKey];
    if (json is! Map<String, Object?>) {
      throw const FormatException('Invalid SQLite self-check result');
    }
    return ProbeSqliteResult.fromJson(json);
  }
}
