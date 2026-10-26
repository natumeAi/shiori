import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/engine/layout/inline_accumulator.dart';
import 'package:shiori/features/reader/engine/layout/paragraph_map.dart';
import 'package:shiori/features/reader/engine/style/computed_style.dart';

const _normal = ComputedStyle();
const _pre = ComputedStyle(whiteSpace: StyleWhiteSpace.pre);
const _preLine = ComputedStyle(whiteSpace: StyleWhiteSpace.preLine);

InlineResult _finish(InlineAccumulator acc, {List<InlinePrefix>? prefixes}) =>
    acc.finish(_normal, prefixes ?? const [])!;

void main() {
  group('white-space normal', () {
    test('collapses runs, trims block edges and records every unit', () {
      final acc = InlineAccumulator()
        ..addText(1, '  a \n\t b  ', _normal)
        ..addText(2, ' c', _normal);
      final result = _finish(acc);
      expect(result.text, 'a b c');
      expect(
        [for (final e in result.map.entries) e.kind],
        [
          MapKind.removed, // leading "  "
          MapKind.exact, // a
          MapKind.collapsed, // the middle whitespace run
          MapKind.exact, // b
          MapKind.collapsed, // trailing "  " of node 1, kept before "c"
          MapKind.removed, // leading " " of node 2
          MapKind.exact, // c
        ],
      );
      // Every source unit of both nodes is covered exactly once.
      for (final (node, length) in [(1, 10), (2, 2)]) {
        var covered = 0;
        for (final e in result.map.entries.where((e) => e.nodeIndex == node)) {
          expect(e.sourceStart, covered);
          covered = e.sourceEnd;
        }
        expect(covered, length);
      }
    });

    test(
      'a collapsed space is one paragraph space; removed ones have none',
      () {
        final acc = InlineAccumulator()..addText(1, 'a   b', _normal);
        final result = _finish(acc);
        expect(result.text, 'a b');
        final collapsed = result.map.entries.singleWhere(
          (e) => e.kind == MapKind.collapsed,
        );
        expect(collapsed.paraEnd - collapsed.paraStart, 1);
        expect(collapsed.sourceEnd - collapsed.sourceStart, 3);
        expect(result.map.sourceAt(1)!.offset, 1);
        expect(result.map.paraOffsetOf(1, 3), 1);
        expect(result.map.paraOffsetOf(1, 4), 2);
        expect(result.map.paraOffsetOf(1, 5), 3);
      },
    );

    test('whitespace-only content yields no paragraph', () {
      final acc = InlineAccumulator()..addText(1, ' \n ', _normal);
      expect(acc.hasContent, isFalse);
      expect(acc.finish(_normal, const []), isNull);
    });

    test('a space after a collapsed space in the next node is removed', () {
      final acc = InlineAccumulator()
        ..addText(1, 'a ', _normal)
        ..addText(2, ' b', _normal);
      expect(_finish(acc).text, 'a b');
    });
  });

  group('white-space pre and pre-line', () {
    test('pre keeps spaces, tabs and newlines one to one', () {
      final acc = InlineAccumulator()..addText(1, 'a  b\n\tc', _pre);
      final result = _finish(acc);
      expect(result.text, 'a  b\n\tc');
      expect(result.map.entries.single.kind, MapKind.exact);
    });

    test('pre-line keeps newlines and collapses other spaces', () {
      final acc = InlineAccumulator()..addText(1, 'a  b\nc', _preLine);
      expect(_finish(acc).text, 'a b\nc');
    });
  });

  group('br and generated text', () {
    test('br is a generated newline and removes the space before it', () {
      final acc = InlineAccumulator()
        ..addText(1, 'a ', _normal)
        ..addBreak(9, _normal)
        ..addText(2, ' b', _normal);
      final result = _finish(acc);
      expect(result.text, 'a\nb');
      final lineBreak = result.map.entries.singleWhere(
        (e) => e.kind == MapKind.lineBreak,
      );
      expect(lineBreak.nodeIndex, 9);
      expect(result.map.sourceAt(lineBreak.paraStart), isNull);
    });

    test('a trailing br does not open another line; a lone br keeps one', () {
      final trailing = InlineAccumulator()
        ..addText(1, 'a', _normal)
        ..addBreak(9, _normal);
      expect(_finish(trailing).text, 'a');
      final lone = InlineAccumulator()..addBreak(9, _normal);
      expect(lone.sawBreak, isTrue);
      final result = _finish(lone);
      expect(result.text, '​');
      expect(result.map.entries.single.kind, MapKind.synthetic);
    });

    test('prefixes are synthetic and shift source coordinates', () {
      final acc = InlineAccumulator()..addText(1, 'ab', _normal);
      final result = _finish(
        acc,
        prefixes: [
          const InlinePrefix.text('• ', _normal),
          const InlinePrefix.placeholder(36, _normal),
        ],
      );
      expect(result.text, '• ￼ab');
      expect(result.map.sourceAt(0), isNull);
      expect(result.map.sourceAt(2), isNull);
      expect(result.map.sourceAt(3)!.offset, 0);
      expect(result.map.paraOffsetOf(1, 1), 4);
      expect(result.runs.first.placeholderWidth, isNull);
      expect(result.runs[1].placeholderWidth, 36);
    });

    test('source spans of a range merge per node and skip generated text', () {
      final acc = InlineAccumulator()
        ..addText(1, 'ab', _normal)
        ..addSynthetic('(', _normal)
        ..addText(2, 'cd', _normal);
      final map = _finish(acc).map;
      expect(map.sourceSpans(0, 5).map((s) => (s.nodeIndex, s.start, s.end)), [
        (1, 0, 2),
        (2, 0, 2),
      ]);
      expect(map.sourceSpans(1, 4).map((s) => (s.nodeIndex, s.start, s.end)), [
        (1, 1, 2),
        (2, 0, 1),
      ]);
    });
  });
}
