import 'dart:convert';
import 'dart:io';

import 'reader_export_analysis.dart';
import 'reader_export_data.dart';
import 'reader_export_report.dart';

Future<void> main(List<String> arguments) async {
  final strict = arguments.contains('--strict');
  final paths = arguments.where((a) => a != '--strict').toList();
  if (paths.isEmpty || paths.any((a) => a.startsWith('--'))) {
    stderr.writeln(
      'Usage: dart run tool/diag/analyze_reader_export.dart [--strict] <export.json>...',
    );
    exitCode = 64;
    return;
  }
  final runs = <ReaderExportAnalysis>[];
  var invalid = false;
  for (final path in paths) {
    try {
      final raw = object(jsonDecode(await File(path).readAsString()), 'export');
      runs.add(ReaderExportAnalysis(raw, source: path));
    } on FormatException catch (error) {
      stderr.writeln('$path: ${error.message}');
      invalid = true;
    } on FileSystemException catch (error) {
      stderr.writeln('$path: ${error.message}');
      invalid = true;
    }
  }
  if (runs.isNotEmpty) stdout.write(renderReaderReport(runs));
  // Gate failure is a reported measurement. Strict status specifically checks
  // NC6 aggregate parity; incomplete evidence is never silently promoted.
  exitCode = invalid
      ? 65
      : strict && runs.any((r) => r.mismatches.isNotEmpty)
      ? 1
      : 0;
}
