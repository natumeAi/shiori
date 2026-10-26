import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shiori/features/diagnostics/data/diagnostic_export_repository.dart';
import 'package:shiori/features/diagnostics/data/probe_marker_repository.dart';
import 'package:shiori/features/diagnostics/data/probe_saved_state.dart';
part 'probe_storage_controller.g.dart';

@riverpod
class ProbeStorageController extends _$ProbeStorageController {
  @override
  Future<ProbeSavedState> build() async {
    final marker = ref.watch(probeMarkerRepositoryProvider);
    final exports = ref.watch(diagnosticExportRepositoryProvider);
    final value = await marker.load();
    if (!ref.mounted) return ProbeSavedState(marker: value);
    final last = await exports.loadLast();
    return ProbeSavedState(marker: value, lastRecord: last);
  }

  Future<void> saveMarker(String marker) async {
    await ref.read(probeMarkerRepositoryProvider).save(marker);
    if (!ref.mounted) return;
    final current = state.asData?.value;
    if (current != null) state = AsyncData(current.copyWith(marker: marker));
  }
}
