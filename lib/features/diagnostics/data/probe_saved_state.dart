import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shiori/core/diagnostics/diagnostic_record.dart';
part 'probe_saved_state.freezed.dart';

@freezed
abstract class ProbeSavedState with _$ProbeSavedState {
  const factory ProbeSavedState({
    required String marker,
    DiagnosticRecord? lastRecord,
  }) = _ProbeSavedState;
}
