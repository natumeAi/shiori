// Generates the canonical-text exclusion table from the committed WebKit
// oracle table. Run from the repository root:
//
//   dart run tool/reader/generate_unicode_table.dart
//
// The input is `test/fixtures/reader/oracle/unicode-table.json` (key
// `webkit`). The output is committed; a test regenerates it in memory and
// compares.
import 'dart:convert';
import 'dart:io';

const inputPath = 'test/fixtures/reader/oracle/unicode-table.json';
const outputPath =
    'lib/features/reader/data/canonical/unicode_exclusion_table.g.dart';

/// Renders the generated Dart source for [table] (the parsed JSON document).
String renderTable(Map<String, Object?> table) {
  final webkit = table['webkit']! as Map<String, Object?>;
  final ranges = (webkit['excludedRanges']! as List<Object?>)
      .map((range) => (range! as List<Object?>).cast<int>())
      .toList();
  final buffer = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.')
    ..writeln('// Source: $inputPath (key "webkit").')
    ..writeln(
      '// Engine: ${webkit['engineName']} ${webkit['engineVersion']} '
      '(normalization v${webkit['normalizationVersion']}).',
    )
    ..writeln('// Generator: tool/reader/generate_unicode_table.dart.')
    ..writeln()
    ..writeln('/// Browser engine whose `White_Space`, `Cc`, `Cf` and `Cs`')
    ..writeln('/// classification produced [canonicalExcludedRanges].')
    ..writeln(
      "const canonicalTableEngine = '${webkit['engineName']} "
      "${webkit['engineVersion']}';",
    )
    ..writeln()
    ..writeln(
      '/// Inclusive `[start, end]` code point ranges, ascending, that do',
    )
    ..writeln('/// not count as canonical characters (flattened pairs).')
    ..writeln('const canonicalExcludedRanges = <int>[');
  for (final range in ranges) {
    buffer
      ..writeln('  ${range[0]},')
      ..writeln('  ${range[1]},');
  }
  buffer.writeln('];');
  return buffer.toString();
}

void main() {
  final table =
      jsonDecode(File(inputPath).readAsStringSync()) as Map<String, Object?>;
  File(outputPath).writeAsStringSync(renderTable(table));
  stdout.writeln('Wrote $outputPath');
}
