import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';

import 'oracle_comparison.dart';

/// Hand-written edge cases (malformed XML, fallbacks, inert content, CSS
/// rewriting, namespaces, HTML tree-builder cases) checked against WebKit
/// vectors made by `tool/reader/source_edge/make_edge_epubs.py`.
void main() {
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
