import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/features/reader/data/epub/epub_archive.dart';
import 'package:shiori/features/reader/data/epub/epub_url.dart';
import 'package:shiori/features/reader/data/source/source_parser.dart';
import 'package:shiori/features/reader/data/source/xml_parser.dart';

void main() {
  group('resolveUrl', () {
    test('resolves, drops query, keeps fragment and decodes', () {
      expect(
        resolveUrl('../x/a%20b.xhtml?q#f', 'OPS/Text/c.xhtml'),
        'OPS/x/a b.xhtml#f',
      );
      expect(resolveUrl('a.xhtml', 'c.opf'), 'a.xhtml');
      expect(resolveUrl('/a/../b', 'OPS/c.opf'), 'b');
      expect(resolveUrl('%zz', 'OPS/c.opf'), '%zz');
      expect(resolveUrl('a%2Fb', 'OPS/c.opf'), 'OPS/a%2Fb');
    });
    test('isExternalUrl', () {
      expect(isExternalUrl('http://x'), isTrue);
      expect(isExternalUrl('blob:x'), isFalse);
      expect(isExternalUrl('a/b'), isFalse);
    });
  });

  group('strict XML', () {
    for (final bad in [
      '<a><b></a>',
      '<a x=1/>',
      '<a x="1" x="2"/>',
      '<p:a/>',
      '<a x="<"/>',
      '<a><!-- -- --></a>',
      '<a>]]></a>',
      '<a>&foo;</a>',
      '\n<?xml version="1.0"?><a/>',
      '<a/><b/>',
      '<a/>junk',
      '<a>\u0001</a>',
      '<a>&#0;</a>',
      '<a>&amp</a>',
    ]) {
      test('rejects ${bad.length} chars: ${bad.codeUnits.take(8)}', () {
        expect(() => parseXmlDocument(bad), throwsA(isA<XmlSyntaxException>()));
      });
    }
    test('parses entities and CDATA', () {
      final document = parseXmlDocument(
        '<a xmlns="urn:x">&lt;&#x41;<![CDATA[<]]></a>',
      );
      final root = document.documentElement!;
      expect(root.namespaceUri, 'urn:x');
      expect(root.children.map((c) => c.data), ['<A', '<']);
    });
  });

  group('SourceParser', () {
    test('falls back to HTML on malformed XHTML', () {
      final document = const SourceParser().parse(
        '<html xmlns="http://www.w3.org/1999/xhtml"><body><p>a</b></body></html>',
      );
      expect(document.parserUsed, 'html-fallback');
      expect(document.parserErrorClass, 'xml_parsererror');
    });
    test('template children are hidden and empty ids never match', () {
      final document = const SourceParser().parse(
        '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>t</title>'
        '</head><body><template><p id="x"/></template><p id="y"/></body></html>',
      );
      expect(document.getElementById('x'), isNull);
      expect(document.getElementById('y'), isNotNull);
      expect(document.getElementById(''), isNull);
    });
  });

  group('EpubArchive limits', () {
    Uint8List zip(int entries) {
      final archive = Archive();
      for (var i = 0; i < entries; i++) {
        archive.addFile(ArchiveFile.string('f$i.txt', 'hello'));
      }
      return Uint8List.fromList(ZipEncoder().encode(archive));
    }

    test('reads text and rejects excess entries and sizes', () {
      expect(EpubArchive.open(zip(2)).text('f1.txt'), 'hello');
      expect(EpubArchive.open(zip(2)).text('none'), isNull);
      expect(
        () => EpubArchive.open(zip(3), limits: const EpubLimits(maxEntries: 2)),
        throwsA(isA<ParseException>()),
      );
      expect(
        () => EpubArchive.open(
          zip(1),
          limits: const EpubLimits(maxEntryBytes: 2),
        ),
        throwsA(isA<ParseException>()),
      );
      expect(
        () => EpubArchive.open(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<ParseException>()),
      );
    });
  });
}
