import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/diag/reader_export_analysis.dart';
import '../../../tool/diag/reader_export_data.dart';
import 'reader_export_cli_test.dart' show runCli;

Json modern({
  int latency = 8000,
  bool pending = false,
  bool missingChain = false,
}) {
  final raw = jsonDecode(
    File('test/fixtures/reader/exports/passing-120hz-a1-1.json')
        .readAsStringSync(),
  ) as Json;
  final engine = raw['engine'] as Json;
  (engine['metadata'] as Json)['readerDemandVersion'] = 1;
  const start = 7100000;
  Json event(String name, int time) => {
    'event': name,
    'monotonicUs': time,
    'captureEpoch': 1,
    'inputId': 1,
  };
  raw['readerEvents'] = [
    event('inputReceived', 7000000),
    event('inputRecognized', start),
    event('recognizedAdmission', start),
    if (!missingChain) event('frameDemandStart', start),
    if (!missingChain) event('dragDirty', start),
    if (!missingChain) event('visualMutation', start + 1),
    if (!pending) event('dragClean', start + latency),
    if (!pending) event('motionSubmission', start + latency),
    if (!pending && !missingChain) event('frameDemandEnd', start + latency),
  ];
  return raw;
}

String gate(ReaderExportAnalysis a, String name) =>
    a.gates.singleWhere((g) => g.name == name).status;
const warm = 'warm admitted input to first submission', stall = 'motion stalls';
void main() {
  test('modern recognition latency uses inclusive 16.7ms threshold', () {
    for (final latency in [16700, 16701]) {
      final a = ReaderExportAnalysis(modern(latency: latency));
      expect(gate(a, warm), latency == 16700 ? 'pass' : 'fail');
      expect(gate(a, stall), 'pass');
    }
  });
  test('pending demand with no first frame fails by capture stop', () {
    final a = ReaderExportAnalysis(modern(pending: true));
    expect(gate(a, warm), 'unavailable');
    expect(gate(a, stall), 'fail');
    expect(a.demand.candidates, hasLength(3));
  });
  test('missing demand capability chain cannot establish absence', () {
    final a = ReaderExportAnalysis(modern(missingChain: true));
    expect(gate(a, stall), 'unavailable');
  });
  test('Dart event loss makes absence and warm timing unavailable', () {
    final raw = modern();
    (raw['overflow'] as Json)['events'] = 1;
    final a = ReaderExportAnalysis(raw);
    expect(gate(a, warm), 'unavailable');
    expect(gate(a, stall), 'unavailable');
  });
  test(
    'legacy native zero loss cannot establish repaired sampling completeness',
    () {
      final raw = modern();
      expect(
        gate(ReaderExportAnalysis(raw), 'native sample loss'),
        'unavailable',
      );
      (raw['presentation'] as Json)['lossAccountingVersion'] = 1;
      expect(gate(ReaderExportAnalysis(raw), 'native sample loss'), 'pass');
    },
  );
  test('native loss includes contention and unmatched callbacks', () {
    for (final key in ['overflow', 'unmatchedCallbacks']) {
      final raw = modern();
      (raw['presentation'] as Json)[key] = 1;
      expect(gate(ReaderExportAnalysis(raw), 'native sample loss'), 'fail');
    }
  });
  test('pure Dart CLI reports real pending-demand failure', () async {
    final directory = Directory.systemTemp.createTempSync(
      'reader-modern-demand-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/pending.json')
      ..writeAsStringSync(jsonEncode(modern(pending: true)));
    final result = await runCli([file.path]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(result.stdout, contains('pendingFrameDemand'));
    expect(result.stdout, contains('recognized admission to first submission'));
  });
}
