import 'dart:convert';
import 'dart:io';

import 'package:shiori/features/reader/data/canonical/canonical_text.dart';
import 'package:shiori/features/reader/data/cfi/cfi.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/data/epub/epub_loader.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/source/source_position.dart';

/// Token scheme that reproduces the oracle's stable stylesheet URL stand-ins.
const oracleTokens = ResourceTokenScheme(prefix: 'oracle-resource:');

Map<String, Object?> readJsonObject(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

/// Collects differences between [expected] and [actual] JSON-like values.
///
/// With [showValues] false (private books) only paths, kinds and lengths are
/// reported, never content.
void diffJson(
  Object? expected,
  Object? actual,
  String path,
  List<String> out, {
  bool showValues = true,
  int limit = 20,
}) {
  if (out.length >= limit) return;
  if (expected is Map<String, Object?> && actual is Map<String, Object?>) {
    final keys = {...expected.keys, ...actual.keys}.toList()..sort();
    for (final key in keys) {
      if (!expected.containsKey(key)) {
        out.add('$path.$key: unexpected key');
      } else if (!actual.containsKey(key)) {
        out.add('$path.$key: missing key');
      } else {
        diffJson(
          expected[key],
          actual[key],
          '$path.$key',
          out,
          showValues: showValues,
          limit: limit,
        );
      }
    }
  } else if (expected is List<Object?> && actual is List<Object?>) {
    if (expected.length != actual.length) {
      out.add('$path: length ${expected.length} != ${actual.length}');
    }
    final count = expected.length < actual.length
        ? expected.length
        : actual.length;
    for (var k = 0; k < count; k++) {
      diffJson(
        expected[k],
        actual[k],
        '$path[$k]',
        out,
        showValues: showValues,
        limit: limit,
      );
    }
  } else if (expected != actual) {
    if (showValues) {
      out.add('$path: expected <$expected> actual <$actual>');
    } else {
      out.add(
        '$path: ${expected.runtimeType}/${_shape(expected)} != '
        '${actual.runtimeType}/${_shape(actual)}',
      );
    }
  }
}

String _shape(Object? value) => value is String ? '${value.length}u' : '$value';

Map<String, Object?> packageJson(EpubBook book) => {
  'opfPath': book.package.opfPath,
  'spine': [
    for (final item in book.package.spine)
      {
        'idref': item.idref,
        'id': item.id,
        'linear': item.linear,
        if (item.properties != null) 'properties': item.properties,
        'sectionIndex': item.sectionIndex,
        if (item.href != null) 'href': item.href,
        'cfiBase': item.cfiBase,
      },
  ],
  'toc': book.package.toc?.map((item) => item.toJson()).toList() ?? [],
  'direction': book.package.direction,
  'rendition': book.package.rendition,
};

Map<String, Object?> sectionJson(SourceDocument document, EpubBook book) {
  final canonical = CanonicalIndex.build(document);
  return {
    'parser': {
      'originalType': document.originalMediaType,
      'used': document.parserUsed,
      'errorClass': document.parserErrorClass,
    },
    'projection': document.toProjectionJson(),
    'canonical': canonical.toJson(),
  };
}

/// Compares a book with an oracle vector; returns bounded difference lines.
List<String> compareBookToVector(
  EpubBook book,
  Map<String, Object?> vector, {
  bool showValues = true,
}) {
  final out = <String>[];
  final package = vector['package']! as Map<String, Object?>;
  final expectedPackage = {
    for (final key in const [
      'opfPath',
      'spine',
      'toc',
      'direction',
      'rendition',
    ])
      key: package[key],
  };
  diffJson(
    expectedPackage,
    jsonDecode(jsonEncode(packageJson(book))),
    'package',
    out,
    showValues: showValues,
  );
  final sections = vector['sections']! as List<Object?>;
  if (sections.length != book.sections.length) {
    out.add('sections: ${sections.length} != ${book.sections.length}');
    return out;
  }
  for (var index = 0; index < sections.length; index++) {
    final expected = sections[index]! as Map<String, Object?>;
    final document = book.loadSection(index);
    final actual = jsonDecode(
      jsonEncode(sectionJson(document, book)),
    ) as Map<String, Object?>;
    for (final key in const ['parser', 'projection', 'canonical']) {
      diffJson(
        expected[key],
        actual[key],
        'section[$index].$key',
        out,
        showValues: showValues,
      );
    }
  }
  return out;
}

SourcePosition _position(Object? json) {
  final map = json! as Map<String, Object?>;
  return SourcePosition(
    nodeIndex: map['node']! as int,
    offset: map['offset']! as int,
  );
}

/// Result of [compareNativeCfi].
final class NativeCfiResult {
  final failures = <String>[];
  var samples = 0;
}

/// For every sampled vector CFI: resolves it against the natively parsed
/// section and exports it back from the native document. Failure lines hold
/// section index, sample index and coordinates only (no book text).
NativeCfiResult compareNativeCfi(
  EpubBook book,
  Map<String, Object?> vector, {
  Set<(int section, int node)> skipNodes = const {},
}) {
  final result = NativeCfiResult();
  final sections = vector['sections']! as List<Object?>;
  for (var index = 0; index < sections.length; index++) {
    final section = sections[index]! as Map<String, Object?>;
    final document = book.loadSection(index);
    final base = book.sections[index].spine.cfiBase;
    final samples = (section['samples']! as List<Object?>)
        .cast<Map<String, Object?>>();
    for (var k = 0; k < samples.length; k++) {
      final sample = samples[k];
      final sampleInput = sample['input']! as Map<String, Object?>;
      final touched = {
        (sampleInput['start']! as Map<String, Object?>)['node'],
        (sampleInput['end']! as Map<String, Object?>)['node'],
      };
      if (skipNodes.any((e) => e.$1 == index && touched.contains(e.$2))) {
        continue;
      }
      result.samples++;
      final cfi = sample['cfi']! as String;
      final expected = sample['resolved']! as Map<String, Object?>;
      void fail(String what) {
        if (result.failures.length < 20) {
          result.failures.add('section[$index] sample[$k]: $what');
        }
      }

      try {
        final range = Cfi.resolve(document, cfi);
        if (range.start != _position(expected['start']) ||
            range.end != _position(expected['end']) ||
            range.collapsed != expected['collapsed']) {
          fail('resolve $range');
        }
      } on Object catch (error) {
        fail('resolve threw ${error.runtimeType}');
      }
      final input = sample['input']! as Map<String, Object?>;
      final collapsed = input['collapsed']! as bool;
      try {
        final exported = Cfi.export(
          document,
          _position(input['start']),
          end: collapsed ? null : _position(input['end']),
          sectionBase: base,
        );
        if (exported != cfi) fail('export differs (${exported.length} chars)');
      } on Object catch (error) {
        fail('export threw ${error.runtimeType}');
      }
    }
  }
  return result;
}
