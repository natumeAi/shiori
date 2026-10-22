import 'dart:convert';
import 'dart:io';

import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/source/source_node.dart';

/// Synthetic fixture ids that have WebKit oracle vectors.
const oracleFixtureIds = <String>[
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

/// Loads the authoritative WebKit vector file of a fixture.
Map<String, Object?> loadWebkitVectors(String fixtureId) {
  final file = File('test/fixtures/reader/oracle/$fixtureId.webkit.json');
  return jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
}

/// Test-only: rebuilds a [SourceDocument] from a vector's projected node
/// list. Production code must never do this; it exists to test CFI
/// resolution independently of the native parser.
SourceDocument documentFromProjection(List<Object?> projection) {
  final childLists = <int, List<(int slot, int index)>>{};
  for (final raw in projection) {
    final node = raw! as Map<String, Object?>;
    final parent = node['parent'] as int?;
    if (parent != null) {
      (childLists[parent] ??= []).add((
        node['slot']! as int,
        node['index']! as int,
      ));
    }
  }
  int? documentElement;
  final nodes = <SourceNode>[];
  for (final raw in projection) {
    final node = raw! as Map<String, Object?>;
    final index = node['index']! as int;
    final kind = switch (node['kind']) {
      'element' => SourceNodeKind.element,
      'text' => SourceNodeKind.text,
      'cdata' => SourceNodeKind.cdata,
      'comment' => SourceNodeKind.comment,
      'pi' => SourceNodeKind.processingInstruction,
      final other => throw StateError('Unknown projected kind $other'),
    };
    final parent = node['parent'] as int?;
    if (parent == null && kind == SourceNodeKind.element) {
      documentElement = index;
    }
    final children = (childLists[index] ?? [])
      ..sort((a, b) => a.$1.compareTo(b.$1));
    nodes.add(
      SourceNode(
        index: index,
        kind: kind,
        childSlot: node['slot']! as int,
        namespaceUri: node['namespaceURI'] as String?,
        localName: node['localName'] as String?,
        id: node['id'] as String?,
        parentIndex: parent,
        text: node['text'] as String?,
        children: [for (final child in children) child.$2],
      ),
    );
  }
  return SourceDocument(
    nodes: nodes,
    documentElementIndex: documentElement!,
    parserMode: SourceParserMode.xhtml,
  );
}

/// Normalizes decoded JSON so numerically equal ints and doubles compare
/// equal and key order does not matter.
Object? canonicalJson(Object? value) => switch (value) {
  final Map<Object?, Object?> map => {
    for (final key in map.keys) key: canonicalJson(map[key]),
  },
  final List<Object?> list => list.map(canonicalJson).toList(),
  final double number when number == number.truncateToDouble() =>
    number.toInt(),
  _ => value,
};
