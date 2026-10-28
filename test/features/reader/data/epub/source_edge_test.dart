import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/data/canonical/canonical_text.dart';
import 'package:shiori/features/reader/data/source/dom_node.dart';
import 'package:shiori/features/reader/data/source/html_adapter.dart';
import 'package:shiori/features/reader/data/source/source_parser.dart';

import 'oracle_comparison.dart';

/// Hand-written edge cases (malformed XML, fallbacks, inert content, CSS
/// rewriting, namespaces, HTML tree-builder cases) checked against WebKit
/// vectors made by `tool/reader/source_edge/make_edge_epubs.py`.
void main() {
  test(
    'head template cannot leak body, formatting, nested or raw-text content',
    () {
      final document = const SourceParser().parse(
        '''<!doctype html><html><head>
<template id="outer"><p id="hidden">hidden<b><template>nested</template>
<script>"</template>"</script><style>"</template>"</style></b></p></template>
<title>kept title</title></head><body><p id="visible">Visible</p></body></html>''',
        mediaType: htmlMediaType,
      );
      final template = document.nodes.singleWhere((n) => n.id == 'outer');
      expect(template.localName, 'template');
      expect(template.children, isEmpty);
      expect(document.node(template.parentIndex!).localName, 'head');
      expect(document.nodes.any((n) => n.id == 'hidden'), isFalse);
      expect(document.nodes.where((n) => n.localName == 'body'), hasLength(1));
      expect(document.nodes.any((n) => n.localName == 'b'), isFalse);
      expect(CanonicalIndex.build(document).length, 'Visible'.length);
    },
  );

  test(
    'body template leaves surrounding paragraph and following CFI slots intact',
    () {
      final document = const SourceParser().parse(
        '<p id="p">Before<template id="t"><p>hidden</p></template>After</p><p id="q">Next</p>',
        mediaType: htmlMediaType,
      );
      final p = document.nodes.singleWhere((n) => n.id == 'p');
      expect(document.node(p.children[1]).localName, 'template');
      expect(p.children, hasLength(3));
      expect(document.node(p.children.last).text, 'After');
      expect(
        document.nodes.singleWhere((n) => n.id == 'q').childSlot,
        p.childSlot + 1,
      );
      expect(CanonicalIndex.build(document).length, 'BeforeAfterNext'.length);
    },
  );

  test('disabled noscript block closes the open paragraph before final raw-text parse', () {
    final tree = parseHtmlDocument(
      '<p id="a">A<noscript id="n"><p id="b">B</p></noscript>C',
    );
    final a = tree.descendantElements.singleWhere((n) => n.id == 'a');
    final b = tree.descendantElements.singleWhere((n) => n.id == 'b');
    final noscript = tree.descendantElements.singleWhere((n) => n.id == 'n');
    expect(noscript.parent, same(a));
    expect(noscript.children, isEmpty);
    expect(b.parent!.localName, 'body');
    final document = const SourceParser().parse(
      '<p id="a">A<noscript id="n"><p id="b">B</p></noscript>C',
      mediaType: htmlMediaType,
    );
    final projected = document.nodes.singleWhere((n) => n.id == 'n');
    expect(projected.children, isEmpty);
    expect(CanonicalIndex.build(document).length, 3);
  });

  test(
    'script-enabled noscript stays raw and foreign template stays ordinary',
    () {
      final tree = parseHtmlDocument(
        '<body><noscript><p>raw</p></noscript><svg><template id="foreign"><text>T</text></template></svg>',
        scripting: true,
      );
      final noscript = tree.descendantElements.singleWhere(
        (n) => n.localName == 'noscript',
      );
      expect(noscript.children.single.data, '<p>raw</p>');
      final foreign = tree.descendantElements.singleWhere(
        (n) => n.id == 'foreign',
      );
      expect(foreign.namespaceUri, svgNamespace);
      expect(foreign.children.single.localName, 'text');
    },
  );

  test('disabled body noscript decodes entities once; ignored tags cannot rename select', () {
    final tree = parseHtmlDocument(
      '<body><noscript id="n">&lt;b&gt;</noscript>'
      '<select id="s"><noscript>choice</noscript><option>A</option></select>',
    );
    final noscript = tree.descendantElements.singleWhere((n) => n.id == 'n');
    expect(noscript.children.single.kind, DomKind.text);
    expect(noscript.children.single.data, '<b>');
    expect(
      tree.descendantElements.singleWhere((n) => n.id == 's').localName,
      'select',
    );
  });

  const dir = 'test/fixtures/reader/source_edge';
  for (final name in ['edge-xhtml', 'edge-html']) {
    test('$name equals the WebKit vectors', () {
      final book = EpubBook.open(
        File('$dir/$name.epub').readAsBytesSync(),
        tokens: oracleTokens,
      );
      final vector = readJsonObject('$dir/$name.webkit.json');
      final differences = compareBookToVector(book, vector);
      final skipped = <(int, int)>{};
      if (name == 'edge-html') {
        // Documented limitation: attribute URLs are not tokenized, so the
        // raw text of the script-enabled <noscript> in h2-noscript-head.html
        // keeps the package href instead of the reference resource token.
        final sections = vector['sections']! as List<Object?>;
        final index = sections.indexWhere(
          (s) =>
              (s! as Map<String, Object?>)['href'] ==
              'OEBPS/h2-noscript-head.html',
        );
        expect(index, greaterThanOrEqualTo(0));
        final document = book.loadSection(index);
        final noscript = document.nodes.indexWhere(
          (n) => n.localName == 'noscript',
        );
        final text = document.node(noscript).children.single;
        skipped.add((index, text));
        expect(differences, [
          'section[$index].projection[$text].text: ${differences.single.split(': ').skip(1).join(': ')}',
        ]);
        expect(
          differences.single,
          startsWith('section[$index].projection[$text].text: expected <<link'),
        );
      } else {
        expect(differences, isEmpty);
      }
      final cfi = compareNativeCfi(book, vector, skipNodes: skipped);
      expect(cfi.samples, greaterThan(0));
      expect(cfi.failures, isEmpty);
    });
  }
}
