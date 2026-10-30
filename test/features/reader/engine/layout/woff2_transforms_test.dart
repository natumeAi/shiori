import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/resources/reader_resource_budget.dart';
import 'package:shiori/features/reader/engine/layout/font_format.dart';
import 'package:shiori/features/reader/engine/layout/woff2_decoder.dart';

import 'woff2_decoder_test.dart' show tables;
import 'woff2_glyph_test_support.dart';
import 'woff2_test_support.dart';

void main() {
  test(
    'every triplet flag, both on-curve states, bbox calculation and overlap',
    () {
      final flags = Uint8List(128),
          glyph = BytesBuilder(),
          expected = <Object>[];
      for (var f = 0; f < 128; f++) {
        flags[f] = f | (f.isOdd ? 128 : 0);
        late int x, y;
        int sign(int flag, int value) => flag.isOdd ? value : -value;
        if (f < 10) {
          glyph.add([7]);
          x = 0;
          y = sign(f, ((f & 14) << 7) + 7);
        } else if (f < 20) {
          glyph.add([7]);
          x = sign(f, (((f - 10) & 14) << 7) + 7);
          y = 0;
        } else if (f < 84) {
          glyph.add([0x27]);
          final b = f - 20;
          x = sign(f, 3 + (b & 48));
          y = sign(f >> 1, 8 + ((b & 12) << 2));
        } else if (f < 120) {
          glyph.add([2, 7]);
          final b = f - 84;
          x = sign(f, 3 + (b ~/ 12) * 256);
          y = sign(f >> 1, 8 + ((b % 12) ~/ 4) * 256);
        } else if (f < 124) {
          glyph.add([0x12, 0x34, 0x56]);
          x = sign(f, 0x123);
          y = sign(f >> 1, 0x456);
        } else {
          glyph.add([0x01, 0x23, 0x04, 0x56]);
          x = sign(f, 0x123);
          y = sign(f >> 1, 0x456);
        }
        glyph.add([2]); // instruction length
        expected.add([
          1,
          [x, y, x, y],
          [0],
          [0xaa, 0xbb],
          [f.isEven ? 1 : 0],
          f.isEven ? 64 : 0,
          [x],
          [y],
        ]);
      }
      final glyf = transformedGlyf(128, [
        join(List.generate(128, (_) => u16(1))),
        Uint8List.fromList(List.filled(128, 1)),
        flags,
        glyph.takeBytes(),
        Uint8List(0),
        Uint8List(16),
        Uint8List.fromList(List.generate(256, (i) => i.isEven ? 0xaa : 0xbb)),
      ], overlap: Uint8List.fromList(List.filled(16, 0x55)));
      final result = const Woff2Decoder().decode(
        makeWoff2(glyphFont(128, glyf)),
      );
      expect(decodedGlyphs(tables(result.bytes)), expected);
      result.dispose();
    },
  );

  test('hmtx omitted proportional/nonproportional arrays and long loca', () {
    for (final indexFormat in [0, 1]) {
      final glyf = transformedGlyf(2, [
        join([u16(1), u16(1)]),
        Uint8List.fromList([1, 1]),
        Uint8List.fromList([11, 11]),
        Uint8List.fromList([5, 0, 7, 0]),
        Uint8List(0),
        Uint8List(4),
        Uint8List(0),
      ], indexFormat: indexFormat);
      for (final flags in [1, 2, 3]) {
        final metrics = join([
          [flags],
          u16(600),
          if ((flags & 1) == 0) u16(5),
          if ((flags & 2) == 0) u16(7),
        ]);
        final result = const Woff2Decoder().decode(
          makeWoff2(
            glyphFont(
              2,
              glyf,
              metrics: metrics,
              metricCount: 1,
              metricVersion: 1,
              indexFormat: indexFormat,
            ),
          ),
        );
        expect(tables(result.bytes)['hmtx'], join([u16(600), u16(5), u16(7)]));
        result.dispose();
      }
    }
  });

  test('UInt255 alternatives, instructions, composite components and explicit bbox', () {
    for (final code in [
      [255, 0],
      [254, 0],
      [253, 0xff, 0xff],
    ]) {
      final n = code[0] == 255
          ? 253
          : code[0] == 254
          ? 506
          : 65535;
      final instructions = Uint8List.fromList(List.generate(n, (i) => i & 255));
      final component = join([
        u16(0x183),
        u16(0),
        u16(2),
        u16(3),
        u16(0x4000),
        u16(0),
        u16(0),
        u16(0x4000),
      ]);
      final glyf = transformedGlyf(2, [
        join([u16(0), u16(-1)]),
        Uint8List(0),
        Uint8List(0),
        Uint8List.fromList(code),
        component,
        join([
          [0x40, 0, 0, 0],
          u16(-3),
          u16(-4),
          u16(20),
          u16(30),
        ]),
        instructions,
      ]);
      final result = const Woff2Decoder(maxTableBytes: 131072)
          .decode(makeWoff2(glyphFont(2, glyf)));
      final decoded = decodedGlyphs(tables(result.bytes));
      expect(decoded[0], isEmpty);
      expect(decoded[1], [
        -1,
        [-3, -4, 20, 30],
        join([component, u16(n), instructions]),
      ]);
      result.dispose();
    }
  });

  test('transformed stream inconsistencies and hmtx flags roll back', () {
    final glyf = transformedGlyf(1, [
      u16(1),
      Uint8List.fromList([1]),
      Uint8List.fromList([11]),
      Uint8List.fromList([5, 0]),
      Uint8List(0),
      Uint8List(4),
      Uint8List(0),
    ]);
    for (final mutate in <void Function(List<FontTable>)>[
      (t) => t[0].data[1] = 1, // transform version
      (t) => t[0].data[5] = 2, // maxp/glyf glyph count mismatch
      (t) => t[0].data[7] = 2, // invalid index format
      (t) => t[2].data[51] = 1, // head/glyf index format mismatch
      (t) => t[0].data[38] = 0, // no points in a contour
      (t) => t[0].data[42] = 128, // bbox bit for unavailable coordinates
      (t) => t[5] = FontTable(
        'hmtx',
        Uint8List.fromList([0, 0, 0]),
        version: 1,
        original: 4,
      ),
    ]) {
      final fresh = Uint8List.fromList(glyf);
      final input = glyphFont(1, fresh);
      mutate(input);
      final budget = ReaderResourceBudget();
      expect(
        () => const Woff2Decoder().decode(makeWoff2(input), budget: budget),
        throwsA(isA<FontFormatException>()),
      );
      expect(budget.accountedBytes, 0);
    }
  });
}
