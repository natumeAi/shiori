import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/canonical/canonical_text.dart';
import 'package:shiori/features/reader/data/canonical/fnv1a64.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/source/source_parser.dart';

SourceDocument _document(String body) => const SourceParser().parse(
  '<html><head><title>Ignored title</title><style>p{color:red}</style></head>'
  '<body>$body</body></html>',
  mediaType: htmlMediaType,
);

void main() {
  // readingActivityText.test.ts:17-72,85-89. The mutable DOM cache at :74
  // belongs to the browser; S2 indexes immutable source snapshots explicitly.
  test('FNV-1a 64 matches the published test vectors', () {
    expect(fnv1a64Hex(''), 'cbf29ce484222325');
    expect(fnv1a64Hex('a'), 'af63dc4c8601ec8c');
    expect(fnv1a64Hex('foobar'), '85944171f73967e8');
  });

  test(
    'normalization v1 counts non-whitespace code points and punctuation',
    () {
      expect(countCanonicalCharacters('Hello, world!'), 12);
      expect(
        countCanonicalCharacters(
          '\u4e2d\u6587\uff0c\u6ca1\u6709\u7a7a\u683c\u3002',
        ),
        8,
      );
      expect(
        countCanonicalCharacters('a\u00a0b\u3000c\u200bd\u200de\ufefff'),
        6,
      );
      expect(countCanonicalCharacters('\u0007\t\n\r x'), 1);
      expect(countCanonicalCharacters('\u{1f600}\u{20000}'), 2);
      expect(countCanonicalCharacters('\ud800x'), 1);
      expect(isCanonicalCodePoint(0x3002), isTrue);
      expect(isCanonicalCodePoint(0x200b), isFalse);
    },
  );

  test(
    'UTF-16 offsets map canonical characters across surrogates and spaces',
    () {
      final document = _document('<p>a \u{1f600}b</p>');
      final entry = CanonicalIndex.build(document).entries.single;
      final starts = entry.canonicalToUtf16;
      expect(starts, [0, 2, 4]);
      final text = document.node(entry.nodeIndex).text!;
      int end(int i) => starts[i] + (text.runeAt(starts[i]) > 0xffff ? 2 : 1);
      expect(end(1), 4);
      expect(end(2), 5);
      expect(entry.utf16Length, 5);
    },
  );

  test('index excludes nonprose and keeps CSS-hidden prose coordinates', () {
    final document = _document(
      '<h1>\u7b2c\u4e00\u7ae0</h1>'
      '<p style="display:none">\u9690\u85cf</p>'
      '<p>\u6b63\u6587<span style="visibility:hidden">\u85cf</span>\u5185\u5bb9</p>'
      '<span></span><script>ignored</script><style>ignored</style>'
      '<svg xmlns="http://www.w3.org/2000/svg"><text>SVG</text></svg>'
      '<math xmlns="http://www.w3.org/1998/Math/MathML"><mi>x</mi></math>'
      '<noscript>ignored</noscript><p>  \u5c3e </p>',
    );
    final index = CanonicalIndex.build(document);
    expect(index.entries.map((e) => document.node(e.nodeIndex).text!.trim()), [
      '\u7b2c\u4e00\u7ae0',
      '\u9690\u85cf',
      '\u6b63\u6587',
      '\u85cf',
      '\u5185\u5bb9',
      '\u5c3e',
    ]);
    expect(index.length, 11);
    expect(index.entries.map((e) => e.start), [0, 3, 5, 7, 8, 10]);
    expect(index.signature, matches(RegExp(r'^fnv1a64:[0-9a-f]{16}$')));
  });

  test(
    'signature is stable across markup and whitespace and changes with text',
    () {
      final first = CanonicalIndex.build(
        _document(
          '<p>\u6625\u7720\u4e0d\u89c9\u6653</p><p>\u5904\u5904\u95fb\u557c\u9e1f</p>',
        ),
      );
      final reflowed = CanonicalIndex.build(
        _document(
          '<div><p>\u6625\u7720 \u4e0d\u89c9\u6653</p>\n  '
          '<p><em>\u5904\u5904</em>\u95fb\u557c\u9e1f</p></div>',
        ),
      );
      final changed = CanonicalIndex.build(
        _document(
          '<p>\u6625\u7720\u4e0d\u89c9\u6653</p><p>\u5904\u5904\u95fb\u557c\u9e21</p>',
        ),
      );
      expect(first.length, 10);
      expect(first.signature, reflowed.signature);
      expect(first.signature, isNot(changed.signature));
    },
  );

  test('an image-only section has zero canonical length', () {
    final index = CanonicalIndex.build(
      _document(
        '\n  <div><img src="a.png" alt="illustration description"/></div>\n',
      ),
    );
    expect(index.length, 0);
    expect(index.entries, isEmpty);
  });
}

extension on String {
  int runeAt(int offset) => substring(offset).runes.first;
}
