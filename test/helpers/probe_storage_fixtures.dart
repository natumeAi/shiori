import 'dart:io';

import 'package:mocktail/mocktail.dart';
import 'package:shiori/core/diagnostics/diagnostic_record.dart';
import 'package:shiori/core/diagnostics/frame_source.dart';
import 'package:shiori/core/diagnostics/probe_clock.dart';
import 'package:shiori/core/diagnostics/probe_declarations.dart';
import 'package:shiori/core/storage/app_directories.dart';
import 'package:shiori/features/diagnostics/data/diagnostic_export_repository.dart';
import 'package:shiori/features/diagnostics/data/probe_marker_repository.dart';

class TestDirectories implements AppDirectories {
  TestDirectories(this.root);
  final Directory root;
  @override
  Future<Directory> applicationSupport() async =>
      Directory('${root.path}/support');
  @override
  Future<Directory> documents() async => Directory('${root.path}/documents');
  @override
  Future<Directory> caches() async => Directory('${root.path}/caches');
}

class MockDirectories extends Mock implements AppDirectories {}

class MockMarkerRepository extends Mock implements ProbeMarkerRepository {}

class MockExportRepository extends Mock implements DiagnosticExportRepository {}

class MockProbeFrameSource extends Mock implements FrameSource {}

class WidgetProbeClock implements ProbeClock {
  @override
  int get monotonicUs => 1234;
  @override
  DateTime utcNow() => DateTime.utc(2026, 10, 22);
}

DiagnosticRecord storageRecord() => DiagnosticRecord(
  runId: 'run-fixture',
  buildId: 'commit-gh-42',
  startedAt: DateTime.utc(2026, 10, 22),
  stoppedAt: DateTime.utc(2026, 10, 22, 0, 0, 1),
  startedMonotonicUs: 0,
  stoppedMonotonicUs: 1000000,
  finalizedMonotonicUs: 2200000,
  stopReason: 'user_stop',
  declarations: const ProbeDeclarations(lowPowerMode: DeclaredSetting.off),
  metadata: const {
    'os': 'fixture-os',
    'buildNumber': {'value': '42', 'source': 'compile_time_CI_define'},
  },
  clocks: const {'correlation': 'unavailable'},
  frames: const [],
  motion: const [],
  frameOverflow: 0,
  motionOverflow: 0,
  reportsDuringDrain: 0,
  omittedOutsideMotion: 0,
  incompleteTrailingBatch: true,
  errors: const ['engine_timings_unavailable'],
  aggregates: const {'cadencePattern': 'insufficient_correlated_samples'},
);
