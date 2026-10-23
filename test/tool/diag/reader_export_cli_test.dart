import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const cli = 'tool/diag/analyze_reader_export.dart';
const fixtures = 'test/fixtures/reader/exports';

Future<ProcessResult> runCli(List<String> args) async {
  final executable = File(Platform.resolvedExecutable);
  final dartName = Platform.isWindows ? 'dart.exe' : 'dart';
  final dart = executable.path.endsWith(dartName)
      ? executable.path
      : '${executable.parent.parent.parent.parent.path}/dart-sdk/bin/$dartName';
  final child = await Process.start(dart, ['run', cli, ...args]);
  final output = child.stdout.transform(utf8.decoder).join();
  final errors = child.stderr.transform(utf8.decoder).join();
  final code = await child.exitCode.timeout(
    const Duration(seconds: 20),
    onTimeout: () {
      child.kill();
      throw TimeoutException('Dart CLI subprocess exceeded 20 seconds');
    },
  );
  return ProcessResult(child.pid, code, await output, await errors);
}

void main() {
  test('pure Dart CLI prints tables and strict aggregate match for passing exports', () async {
    final result = await runCli([
      '--strict',
      for (var i = 1; i <= 3; i++) '$fixtures/passing-120hz-a1-$i.json',
    ]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(
      result.stdout,
      contains('| Gate | Observed | Threshold | Result | Reason |'),
    );
    expect(result.stdout, contains('MATCH (reader and engine)'));
    expect(result.stdout, contains('pass: 3 required repeats present'));
    expect(result.stdout, contains('## R01 / repeat 3 of 3'));
  });
  test('unknown schema and kind fail clearly with nonzero exit', () async {
    final version = await runCli(['$fixtures/unknown-schema.json']);
    expect(version.exitCode, 65);
    expect(version.stderr, contains('Unsupported schemaVersion: 2'));
    final root = await Directory.systemTemp.createTemp('reader-analyzer-kind-');
    addTearDown(() => root.delete(recursive: true));
    final file = File('${root.path}/kind.json');
    await file.writeAsString(jsonEncode({'kind': 'other', 'schemaVersion': 1}));
    final kind = await runCli([file.path]);
    expect(kind.exitCode, 65);
    expect(kind.stderr, contains('Unsupported kind: other'));
  });
  test('strict exits nonzero only for aggregate mismatch while normal mode reports it', () async {
    final root = await Directory.systemTemp.createTemp(
      'reader-analyzer-mismatch-',
    );
    addTearDown(() => root.delete(recursive: true));
    final raw = jsonDecode(
      await File('$fixtures/passing-120hz-a1-1.json').readAsString(),
    ) as Map<String, Object?>;
    (raw['aggregates'] as Map<String, Object?>)['acceptedTurns'] = 123;
    final file = File('${root.path}/mismatch.json');
    await file.writeAsString(jsonEncode(raw));
    final normal = await runCli([file.path]);
    final strict = await runCli(['--strict', file.path]);
    expect(normal.exitCode, 0);
    expect(
      normal.stdout,
      contains('aggregates.acceptedTurns: app=123; recomputed=4'),
    );
    expect(strict.exitCode, 1);
    expect(strict.stdout, contains('MISMATCH'));
  });
  test(
    'failed measurement gates remain visible with strict aggregate parity',
    () async {
      final result = await runCli([
        '--strict',
        '$fixtures/failing-budgets-a2.json',
        '$fixtures/stall-b.json',
        '$fixtures/overflowed-rings.json',
        '$fixtures/double-acceptance.json',
        '$fixtures/cap-breach.json',
      ]);
      expect(result.exitCode, 0);
      expect(result.stdout, contains('| fail |'));
      expect(result.stdout, contains('contentionDrops'));
      expect(result.stdout, contains('atLeast12500Us'));
      expect(result.stdout, contains('correctness / committed destinations'));
      expect(result.stdout, contains('unbounded: pictureBytes'));
      expect(
        result.stdout,
        contains('system_drawable_presentation_non_product_path'),
      );
    },
  );
  test('CLI reports malformed JSON missing files and usage errors', () async {
    expect((await runCli([])).exitCode, 64);
    expect((await runCli(['--unknown'])).exitCode, 64);
    expect((await runCli(['$fixtures/no-such-export.json'])).exitCode, 65);
    final root = await Directory.systemTemp.createTemp(
      'reader-analyzer-malformed-',
    );
    addTearDown(() => root.delete(recursive: true));
    final file = File('${root.path}/bad.json');
    await file.writeAsString('{');
    expect((await runCli([file.path])).exitCode, 65);
  });
}
