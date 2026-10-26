import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/canonical/canonical_text.dart';
import 'package:shiori/features/reader/data/canonical/fnv1a64.dart';
import 'package:shiori/features/reader/data/source/source_parser.dart';

import '../../../../../tool/reader/generate_unicode_table.dart' as generator;

void main() {
  test('FNV-1a64 reference vectors', () {
    expect(fnv1a64Hex(''), 'cbf29ce484222325');
    expect(fnv1a64Hex('a'), 'af63dc4c8601ec8c');
    expect(fnv1a64Hex('foobar'), '85944171f73967e8');
  });

  test('generated table matches its source', () {
    final table = jsonDecode(
      File(generator.inputPath).readAsStringSync(),
    ) as Map<String, Object?>;
    // Compare content, not line endings: with core.autocrlf a Windows
    // checkout writes the committed LF file back as CRLF.
    expect(
      File(generator.outputPath).readAsStringSync().replaceAll('\r\n', '\n'),
      generator.renderTable(table),
    );
  });

  test('code point classification', () {
    expect(isCanonicalCodePoint(0x20), isFalse);
    expect(isCanonicalCodePoint(0xa0), isFalse);
    expect(isCanonicalCodePoint(0xad), isFalse);
    expect(isCanonicalCodePoint(0xd800), isFalse);
    expect(isCanonicalCodePoint(0x61), isTrue);
    expect(isCanonicalCodePoint(0x1f600), isTrue);
    expect(isCanonicalCodePoint(0x301), isTrue);
    expect(countCanonicalCharacters('a \u{1F600}b'), 3);
  });

  test('index maps canonical characters to UTF-16 offsets', () {
    final document = const SourceParser().parse(
      '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>t</title>'
      '</head><body><p>a \u{1F600}b</p><script>zz</script>'
      '<svg xmlns="http://www.w3.org/2000/svg"><text>q</text></svg>'
      '<p><![CDATA[cd]]>e</p></body></html>',
    );
    final index = CanonicalIndex.build(document);
    expect(index.length, 4);
    expect(index.entries, hasLength(2));
    expect(index.entries.first.canonicalToUtf16, [0, 2, 4]);
    expect(index.entries.last.length, 1);
    expect(index.signature, startsWith('fnv1a64:'));
  });
}
