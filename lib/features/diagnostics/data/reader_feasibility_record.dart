import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shiori/core/diagnostics/diagnostic_record.dart';

part 'reader_feasibility_record.freezed.dart';
part 'reader_feasibility_record.g.dart';

/// Book-derived fields are deliberately limited to a digest and fixture ID.
@freezed
abstract class ReaderFeasibilityRecord with _$ReaderFeasibilityRecord {
  const factory ReaderFeasibilityRecord({
    @Default('reader_feasibility') String kind,
    @Default(1) int schemaVersion,
    required String bookSha256,
    required String? fixtureId,
    required String scenarioId,
    required int repeatIndex,
    required int repeatCount,
    required String input,
    required DiagnosticRecord engine,
    required List<Map<String, Object?>> readerEvents,
    required List<Map<String, Object?>> layoutCosts,
    required List<Map<String, Object?>> resources,
    required Map<String, Object?> presentation,
    required Map<String, Object?> aggregates,
    required Map<String, int> overflow,
    required Map<String, Object?> omissions,
  }) = _ReaderFeasibilityRecord;

  factory ReaderFeasibilityRecord.fromJson(Map<String, Object?> json) =>
      _$ReaderFeasibilityRecordFromJson(json);
}
