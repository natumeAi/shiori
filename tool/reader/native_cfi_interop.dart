// Native -> oracle CFI interoperability check (needs Node and Playwright, so
// it is not part of `flutter test`). From the repository root:
//
//   dart run tool/reader/native_cfi_interop.dart export build/interop
//   (cd tool/oracle && npm run resolve -- ../../build/interop/cfi-list.json)
//   dart run tool/reader/native_cfi_interop.dart compare build/interop
//
// `export` opens every synthetic fixture natively, exports a CFI for each
// sampled position of the committed WebKit vectors, and also records the
// native resolution of that CFI. `compare` checks Foliate's resolution
// (WebKit authoritative, Chromium cross-check) against the native one.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shiori/features/reader/data/cfi/cfi.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/data/epub/epub_loader.dart';
import 'package:shiori/features/reader/data/source/source_position.dart';

const fixtureIds = [
  'cfi-structure',
  'chapters',
  'html-fallback',
  'images',
  'inert-content',
  'long-content',
  'one-page',
  'opf-variants',
  'styles',
  'unicode',
  'unsupported-fixed',
  'unsupported-rtl',
  'unsupported-vertical',
];

SourcePosition _position(Object? json) {
  final map = json! as Map<String, Object?>;
  return SourcePosition(
    nodeIndex: map['node']! as int,
    offset: map['offset']! as int,
  );
}

Map<String, Object?> _json(SourcePosition p) => {
  'node': p.nodeIndex,
  'offset': p.offset,
};

void main(List<String> args) {
  if (args.length != 2 || !{'export', 'compare'}.contains(args[0])) {
    stderr.writeln('usage: native_cfi_interop.dart export|compare <dir>');
    exit(64);
  }
  final directory = Directory(args[1])..createSync(recursive: true);
  if (args[0] == 'export') {
    _export(directory);
  } else {
    _compare(directory);
  }
}

void _export(Directory directory) {
  final requests = <Object?>[];
  final expected = <Object?>[];
  var total = 0;
  for (final id in fixtureIds) {
    final book = EpubBook.open(
      Uint8List.fromList(
        File('assets/reader_fixtures/$id.epub').readAsBytesSync(),
      ),
      tokens: const ResourceTokenScheme(prefix: 'oracle-resource:'),
    );
    final vector = jsonDecode(
      File('test/fixtures/reader/oracle/$id.webkit.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final sections = vector['sections']! as List<Object?>;
    final cfis = <String>[];
    final native = <Object?>[];
    for (var index = 0; index < sections.length; index++) {
      final section = sections[index]! as Map<String, Object?>;
      final document = book.loadSection(index);
      final base = book.sections[index].spine.cfiBase;
      for (final raw in section['samples']! as List<Object?>) {
        final input =
            (raw! as Map<String, Object?>)['input']! as Map<String, Object?>;
        final collapsed = input['collapsed']! as bool;
        final cfi = Cfi.export(
          document,
          _position(input['start']),
          end: collapsed ? null : _position(input['end']),
          sectionBase: base,
        );
        final range = Cfi.resolve(document, cfi);
        cfis.add(cfi);
        native.add({
          'cfi': cfi,
          'sectionIndex': book.sections[index].spine.sectionIndex,
          'start': _json(range.start),
          'end': _json(range.end),
        });
      }
    }
    total += cfis.length;
    requests.add({'fixtureId': id, 'cfis': cfis});
    expected.add({'fixtureId': id, 'native': native});
  }
  File('${directory.path}/cfi-list.json')
      .writeAsStringSync(jsonEncode(requests));
  File('${directory.path}/native-expected.json')
      .writeAsStringSync(jsonEncode(expected));
  stdout.writeln('Exported $total CFIs for ${fixtureIds.length} fixtures.');
}

void _compare(Directory directory) {
  final expected = jsonDecode(
    File('${directory.path}/native-expected.json').readAsStringSync(),
  ) as List<Object?>;
  final resolved = jsonDecode(
    File('build/oracle-local/resolve-results.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final groups = resolved['results']! as List<Object?>;
  if (groups.length != expected.length) {
    stderr.writeln(
      'Group count differs: ${groups.length} vs ${expected.length}',
    );
    exit(1);
  }
  final counts = <String, int>{'webkit': 0, 'chromium': 0};
  final mismatches = <String, int>{'webkit': 0, 'chromium': 0};
  for (var g = 0; g < groups.length; g++) {
    final group = groups[g]! as Map<String, Object?>;
    final native =
        (expected[g]! as Map<String, Object?>)['native']! as List<Object?>;
    final engines = group['results']! as Map<String, Object?>;
    for (final entry in engines.entries) {
      final results = entry.value! as List<Object?>;
      if (results.length != native.length) {
        stderr.writeln('${entry.key}/${fixtureIds[g]}: result count differs');
        mismatches[entry.key] = mismatches[entry.key]! + 1;
        continue;
      }
      for (var k = 0; k < results.length; k++) {
        final actual = results[k]! as Map<String, Object?>;
        final want = native[k]! as Map<String, Object?>;
        counts[entry.key] = counts[entry.key]! + 1;
        final same =
            actual['error'] == null &&
            actual['sectionIndex'] == want['sectionIndex'] &&
            jsonEncode(actual['start']) == jsonEncode(want['start']) &&
            jsonEncode(actual['end']) == jsonEncode(want['end']);
        if (!same) {
          mismatches[entry.key] = mismatches[entry.key]! + 1;
          if (mismatches[entry.key]! <= 10) {
            stderr.writeln(
              '${entry.key} ${fixtureIds[g]}[$k] ${want['cfi']}: '
              'oracle ${jsonEncode(actual)} native ${jsonEncode(want)}',
            );
          }
        }
      }
    }
  }
  stdout.writeln('Compared: $counts; mismatches: $mismatches');
  if (mismatches.values.any((count) => count > 0)) exit(1);
}
