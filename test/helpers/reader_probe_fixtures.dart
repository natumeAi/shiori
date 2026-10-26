import 'package:shiori/core/diagnostics/diagnostic_recorder.dart';
import 'package:shiori/core/diagnostics/probe_declarations.dart';
import 'package:shiori/features/diagnostics/data/reader_feasibility_record.dart';
import 'package:shiori/features/diagnostics/data/reader_probe_recorder.dart';

import 'diagnostics_fixtures.dart';

const readerDigest =
    '9084f32798fe18eab6f995de10cff260c2171ba3d6aab91f21be9f2a4e73916e';
ReaderProbeRecorder readerRecorder({
  int capacity = 4,
  DiagnosticTestClock? clock,
  DiagnosticTestFrameSource? source,
  Duration drain = Duration.zero,
}) => ReaderProbeRecorder(
  engine: DiagnosticRecorder(
    clock: clock ?? DiagnosticTestClock(),
    source: source ?? DiagnosticTestFrameSource(),
    capacity: capacity,
    drainDuration: drain,
  ),
  capacity: capacity,
);

Future<void> startReader(
  ReaderProbeRecorder recorder, {
  String scenario = 'R01',
  String runId = 'reader-test',
}) => recorder.start(
  runId: runId,
  bookSha256: readerDigest,
  fixtureId: scenario == 'R11' ? null : 'chapters',
  scenarioId: scenario,
  repeatIndex: 1,
  repeatCount: scenario == 'R11' ? 1 : 3,
  input: scenario == 'R11' ? 'manual_touch' : 'synthetic_injected',
  declarations: const ProbeDeclarations(),
  metadata: const {},
);

Future<ReaderFeasibilityRecord> sampleReaderRecord() async {
  final recorder = readerRecorder();
  await startReader(recorder);
  final record = await recorder.stop();
  recorder.dispose();
  return record!;
}
