import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/diag/reader_export_analysis.dart';
import '../../../tool/diag/reader_export_data.dart';
import '../../helpers/reader_analyzer_exports.dart';

const exportDirectory = 'test/fixtures/reader/exports';

void main() {
  final exports = readerAnalyzerExports();
  for (final entry in exports.entries) {
    test('NC6 app-produced aggregates reproduce ${entry.key}', () {
      final file = File('$exportDirectory/${entry.key}');
      if (Platform.environment['REGENERATE_READER_EXPORTS'] == '1') {
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert(entry.value)}${String.fromCharCode(10)}',
        );
      }
      final json = object(jsonDecode(file.readAsStringSync()), entry.key);
      // Structural comparison tolerates core.autocrlf without hiding data drift.
      expect(
        json,
        entry.value,
        reason: 'Regenerate using the documented helper path',
      );
      if (entry.key == 'unknown-schema.json') {
        expect(() => ReaderExportAnalysis(json), throwsFormatException);
        return;
      }
      final analysis = ReaderExportAnalysis(json);
      expect(analysis.readerAggregates, json['aggregates']);
      expect(
        analysis.engine.aggregates,
        object(json['engine'], 'engine')['aggregates'],
      );
      expect(analysis.mismatches, isEmpty);
    });
  }
}
