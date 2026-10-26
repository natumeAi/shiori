import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/cfi/cfi.dart';
import 'package:shiori/features/reader/data/cfi/cfi_numbers.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/source/source_position.dart';

import 'cfi_vector_support.dart';

Map<String, Object?> _node(
  int index,
  String kind,
  int? parent,
  int slot, {
  String? name,
  String? id,
  String? text,
}) => {
  'index': index,
  'kind': kind,
  'namespaceURI': kind == 'element' ? 'http://www.w3.org/1999/xhtml' : null,
  'localName': name,
  'id': kind == 'element' ? (id ?? '') : null,
  'parent': parent,
  'slot': slot,
  'text': text,
};

/// html > body > [p#a [text, cdata, comment, text], p#b, img, text]
SourceDocument _document() => documentFromProjection([
  _node(0, 'element', null, 0, name: 'html'),
  _node(1, 'element', 0, 0, name: 'body'),
  _node(2, 'element', 1, 0, name: 'p', id: 'a'),
  _node(3, 'text', 2, 0, text: 'Hello'),
  _node(4, 'cdata', 2, 1, text: 'World'),
  _node(5, 'comment', 2, 2, text: 'c'),
  _node(6, 'text', 2, 3, text: '!'),
  _node(7, 'element', 1, 1, name: 'p', id: 'b'),
  _node(8, 'element', 1, 2, name: 'img'),
  _node(9, 'text', 1, 3, text: 'tail'),
]);

SourcePosition _at(int node, int offset) =>
    SourcePosition(nodeIndex: node, offset: offset);

Matcher _throwsReference(String name) => throwsA(
  isA<CfiException>().having((e) => e.referenceErrorName, 'name', name),
);

void main() {
  group('numbers', () {
    test('JavaScript number formatting', () {
      expect(jsNumberToString(1e21), '1e+21');
      expect(
        jsNumberToString(123456789012345680000.0),
        '123456789012345680000',
      );
      expect(jsNumberToString(1.5e-7), '1.5e-7');
      expect(jsNumberToString(0.000001), '0.000001');
      expect(jsNumberToString(0.1), '0.1');
      expect(jsNumberToString(100.0), '100');
      expect(jsNumberToString(-2.5), '-2.5');
      expect(jsNumberToString(double.nan), 'NaN');
    });

    test('parseFloat takes the longest decimal prefix', () {
      expect(jsParseFloat('1.2.3'), 1.2);
      expect(jsParseFloat('5.'), 5);
      expect(jsParseFloat('.5'), 0.5);
      expect(jsParseFloat('.'), isNaN);
      expect(jsParseFloat(''), isNaN);
    });

    test('Range offsets convert like WebIDL unsigned long', () {
      expect(jsToUint32(null), 0);
      expect(jsToUint32(double.nan), 0);
      expect(jsToUint32(2.9), 2);
      expect(jsToUint32(4294967297), 1);
    });
  });

  group('grammar quirks', () {
    test('unknown parameters are dropped and side is kept', () {
      expect(
        Cfi.collapse('epubcfi(/6/2!/4/2[id;unknown=value])'),
        'epubcfi(/6/2!/4/2[id])',
      );
      expect(
        Cfi.collapse('epubcfi(/6/2!/4/2[id;s=a])'),
        'epubcfi(/6/2!/4/2[id;s=a])',
      );
    });

    test('an empty first assertion value keeps the ID state', () {
      final steps = Cfi.parse('epubcfi(/2[,x])').groups.single;
      expect(steps.single.id, 'x');
      expect(steps.single.text, ['']);
      expect(Cfi.collapse('epubcfi(/2[,x])'), 'epubcfi(/2[x][])');
    });

    test('escapes round trip', () {
      const cfi = r'epubcfi(/6/2[a^^b^]c^,d]!/4)';
      expect(Cfi.serialize(Cfi.parse(cfi)), cfi);
    });

    test('malformed input follows the reference', () {
      expect(Cfi.collapse(''), 'epubcfi()');
      expect(Cfi.collapse('epubcfi(/)'), 'epubcfi(/NaN)');
      expect(() => Cfi.parse('epubcfi(:2)'), _throwsReference('TypeError'));
      expect(
        () => Cfi.collapse('epubcfi(/6/2,/4/2)', toEnd: true),
        _throwsReference('TypeError'),
      );
      expect(Cfi.collapse('epubcfi(/6/2,/4/2)'), 'epubcfi(/6/2/4/2)');
    });

    test('a newline defeats the wrapper match but still tokenizes', () {
      expect(Cfi.collapse('epubcfi(/6\n/2)'), 'epubcfi(/6/2)');
    });
  });

  group('compare and sort', () {
    test('missing offsets compare neither greater nor less', () {
      expect(Cfi.compare('epubcfi(/6/2!/4/1)', 'epubcfi(/6/2!/4/1:5)'), 0);
      expect(Cfi.compare('epubcfi(/6/2!/4/1:2)', 'epubcfi(/6/2!/4/1:5)'), -1);
    });

    test('a shorter path precedes its extension', () {
      expect(Cfi.compare('epubcfi(/6/2!/4)', 'epubcfi(/6/2!/4/2)'), -1);
      expect(Cfi.compare('epubcfi(/6/2!/4/2)', 'epubcfi(/6/2!/4)'), 1);
    });

    test('ranges compare by start then end', () {
      expect(
        Cfi.compare('epubcfi(/6/2!/4,/1:0,/1:9)', 'epubcfi(/6/2!/4,/1:0,/1:3)'),
        1,
      );
    });

    test('sort is stable for equal elements', () {
      final input = [
        'epubcfi(/6/2!/4/1[x])',
        'epubcfi(/6/2!/2/1)',
        'epubcfi(/6/2!/4/1[y])',
      ];
      expect(Cfi.sort(input), [input[1], input[0], input[2]]);
    });

    test('joinIndirection unwraps and rewraps', () {
      expect(
        Cfi.joinIndirection(['epubcfi(/8/4[ref])', 'epubcfi(/4/2/1:0)']),
        'epubcfi(/8/4[ref]!/4/2/1:0)',
      );
    });
  });

  group('resolution against a source document', () {
    final document = _document();
    CfiRange resolve(String local) => Cfi.resolveLocal(document, local);

    test(
      'merged text and CDATA resolve to the preceding node at a boundary',
      () {
        expect(resolve('epubcfi(/2/2/1:7)').start, _at(4, 2));
        expect(resolve('epubcfi(/2/2/1:5)').start, _at(3, 5));
        expect(resolve('epubcfi(/2/2/1:10)').start, _at(4, 5));
        expect(resolve('epubcfi(/2/2/1:11)').start, _at(6, 1));
        expect(
          () => resolve('epubcfi(/2/2/1:12)'),
          _throwsReference('TypeError'),
        );
      },
    );

    test('a single text node keeps the offset exact', () {
      expect(resolve('epubcfi(/2/7:2)').start, _at(9, 2));
      expect(
        () => resolve('epubcfi(/2/7:5)'),
        _throwsReference('IndexSizeError'),
      );
    });

    test('the last step ID wins over the path', () {
      expect(resolve('epubcfi(/2/2/2[b])').start, _at(7, 0));
      expect(resolve('epubcfi(/999[a])').end, _at(2, 0));
    });

    test('virtual slots resolve to parent boundaries', () {
      expect(resolve('epubcfi(/2/1)').start, _at(2, 0));
      expect(resolve('epubcfi(/2/7)').start, _at(9, 0));
      expect(resolve('epubcfi(/2/0)').start, _at(0, 0));
      expect(resolve('epubcfi(/2/8)').start, _at(0, 1));
      expect(resolve('epubcfi(/0)').start, _at(-1, 0));
      expect(resolve('epubcfi(/4)').start, _at(-1, 1));
    });

    test('the before slot of an element is a boundary in its parent', () {
      expect(resolve('epubcfi(/2/2/0)').start, _at(1, 0));
    });

    test('missing and out of range slots fail', () {
      expect(() => resolve('epubcfi(/2/3)'), _throwsReference('TypeError'));
      expect(() => resolve('epubcfi(/2/99)'), _throwsReference('TypeError'));
      expect(() => resolve('epubcfi(/2/4/2)'), _throwsReference('TypeError'));
      expect(() => resolve('epubcfi()'), _throwsReference('TypeError'));
    });

    test('element offsets count raw child nodes', () {
      expect(resolve('epubcfi(/2/2:4)').start, _at(2, 4));
      expect(
        () => resolve('epubcfi(/2/2:5)'),
        _throwsReference('IndexSizeError'),
      );
    });

    test('a reversed range collapses to its end', () {
      final range = Cfi.resolve(document, 'epubcfi(/6/2!/2/2,/1:3,/1:1)');
      expect(range.start, _at(3, 1));
      expect(range.collapsed, isTrue);
    });

    test('an ancestor boundary orders by child slot', () {
      // End (body, 0) precedes start (p#a text, 1): reversed.
      final range = Cfi.resolve(document, 'epubcfi(/6/2!/2,/2/1:1,/0)');
      expect(range.start, _at(0, 0));
      expect(range.end, _at(0, 0));
    });

    test('resolve skips the package path', () {
      expect(
        Cfi.resolve(document, 'epubcfi(/8/4[ref]!/2/2/1:0)').start,
        _at(3, 0),
      );
      expect(
        () => Cfi.resolve(document, 'epubcfi(/2/2/1:0)'),
        _throwsReference('TypeError'),
      );
    });
  });

  group('export', () {
    final document = _document();

    test('exports through merged text chunks', () {
      expect(Cfi.export(document, _at(4, 2)), 'epubcfi(/2/2[a]/1:7)');
      expect(Cfi.export(document, _at(6, 0)), 'epubcfi(/2/2[a]/1:10)');
    });

    test('exports a joined section CFI', () {
      expect(
        Cfi.export(
          document,
          _at(9, 3),
          sectionBase: 'epubcfi(/8/4[ref-nonlinear])',
        ),
        'epubcfi(/8/4[ref-nonlinear]!/2/7:3)',
      );
    });

    test('a node outside the filtered children drops its step', () {
      expect(Cfi.export(document, _at(5, 0)), 'epubcfi(/2/2[a])');
    });

    test('a range shares only its common ancestors', () {
      expect(
        Cfi.export(document, _at(3, 0), end: _at(9, 2)),
        'epubcfi(/2,/2[a]/1:0,/7:2)',
      );
      expect(
        Cfi.export(document, _at(3, 1), end: _at(6, 1)),
        'epubcfi(/2/2[a],/1:1,/1:11)',
      );
    });

    test('equal start and end export as a point', () {
      expect(
        Cfi.export(document, _at(9, 1), end: _at(9, 1)),
        'epubcfi(/2/7:1)',
      );
    });

    test('the document element has no CFI step', () {
      expect(
        () => Cfi.export(document, _at(0, 0)),
        _throwsReference('TypeError'),
      );
    });

    test('exported CFIs resolve back to an equivalent position', () {
      for (final position in [_at(3, 2), _at(4, 4), _at(6, 1), _at(9, 4)]) {
        final cfi = Cfi.export(
          document,
          position,
          sectionBase: 'epubcfi(/6/2)',
        );
        final resolved = Cfi.resolve(document, cfi);
        expect(
          Cfi.export(document, resolved.start, sectionBase: 'epubcfi(/6/2)'),
          cfi,
        );
      }
    });
  });

  group('package resolution', () {
    // package > [metadata, manifest, guide, spine > itemref x3]
    SourceDocument opf() => documentFromProjection([
      _node(0, 'element', null, 0, name: 'package'),
      _node(1, 'element', 0, 0, name: 'metadata'),
      _node(2, 'element', 0, 1, name: 'manifest'),
      _node(3, 'element', 0, 2, name: 'guide'),
      _node(4, 'element', 0, 3, name: 'spine'),
      _node(5, 'element', 4, 0, name: 'itemref', id: 'r1'),
      _node(6, 'element', 4, 1, name: 'itemref', id: 'r2'),
      _node(7, 'element', 4, 2, name: 'itemref', id: 'r3'),
    ]);

    test('the real spine path decides the itemref', () {
      final package = opf();
      expect(Cfi.resolvePackageNode(package, 'epubcfi(/8/2!/4/1:0)'), 5);
      expect(Cfi.resolvePackageNode(package, 'epubcfi(/8/6!/4/1:0)'), 7);
      expect(Cfi.resolvePackageNode(package, 'epubcfi(/8/4,/2,/4)'), 6);
    });

    test('a package ID assertion is ignored once the path is followed', () {
      expect(Cfi.resolvePackageNode(opf(), 'epubcfi(/8/2[r3]!/4/1:0)'), 5);
    });

    test('an unknown ID falls back to the path', () {
      expect(Cfi.resolvePackageNode(opf(), 'epubcfi(/8/4[nope]!/4/1:0)'), 6);
    });

    test('an unresolvable path reports no node', () {
      expect(Cfi.resolvePackageNode(opf(), 'epubcfi(/8/40!/4/1:0)'), isNull);
    });
  });
}
