import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shiori/core/diagnostics/frame_sample.dart';
import 'package:shiori/core/diagnostics/motion_sample.dart';
import 'package:shiori/core/diagnostics/probe_declarations.dart';
part 'diagnostic_record.freezed.dart';
part 'diagnostic_record.g.dart';

@freezed
abstract class DiagnosticRecord with _$DiagnosticRecord {
  const factory DiagnosticRecord({
    @Default(1) int schemaVersion,
    @Default('synthetic_transform') String scenarioId,
    required String runId,
    required String buildId,
    required DateTime startedAt,
    required DateTime stoppedAt,
    required int startedMonotonicUs,
    required int stoppedMonotonicUs,
    required int finalizedMonotonicUs,
    required String stopReason,
    required ProbeDeclarations declarations,
    required Map<String, Object?> metadata,
    required Map<String, Object?> clocks,
    required List<FrameSample> frames,
    required List<MotionSample> motion,
    required int frameOverflow,
    required int motionOverflow,
    required int reportsDuringDrain,
    required int omittedOutsideMotion,
    required bool incompleteTrailingBatch,
    required List<String> errors,
    required Map<String, Object?> aggregates,
    @Default('unverified') String physicalPresentation,
  }) = _DiagnosticRecord;
  factory DiagnosticRecord.fromJson(Map<String, Object?> json) =>
      _$DiagnosticRecordFromJson(json);
}
