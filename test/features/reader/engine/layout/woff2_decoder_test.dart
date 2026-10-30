import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/resources/reader_resource_budget.dart';
import 'package:shiori/features/reader/engine/layout/font_format.dart';
import 'package:shiori/features/reader/engine/layout/woff_decoder.dart';
import 'package:shiori/features/reader/engine/layout/woff2_decoder.dart';

import 'woff2_glyph_test_support.dart';
import 'woff2_test_support.dart';

Uint8List source() =>
    File('test/fixtures/reader/fixed_layout/Roboto-Regular.woff2')
        .readAsBytesSync();

Map<String, Uint8List> tables(Uint8List bytes) {
  final d = ByteData.sublistView(bytes);
  return {
    for (var i = 0; i < d.getUint16(4); i++)
      String.fromCharCodes(
        bytes.sublist(12 + i * 16, 16 + i * 16),
      ): Uint8List.sublistView(
        bytes,
        d.getUint32(20 + i * 16),
        d.getUint32(20 + i * 16) + d.getUint32(24 + i * 16),
      ),
  };
}

void main() {
  test('Roboto reconstructs every table and whole-font checksum', () {
    final budget = ReaderResourceBudget();
    final result = const Woff2Decoder().decode(source(), budget: budget);
    final control = tables(
      File('tool/oracle/fixtures/styles/EPUB/fonts/Roboto-Regular.ttf')
          .readAsBytesSync(),
    );
    final converted = tables(result.bytes);
    expect(converted.keys, unorderedEquals(control.keys));
    for (final tag in control.keys) {
      if (tag == 'head') {
        final a = Uint8List.fromList(converted[tag]!);
        final b = Uint8List.fromList(control[tag]!);
        a.fillRange(8, 12, 0);
        b.fillRange(8, 12, 0);
        expect(a, b, reason: tag);
      } else {
        expect(converted[tag], control[tag], reason: tag);
      }
    }
    expect(sfntChecksum(result.bytes), 0xb1b0afba);
    expect(budget.accountedBytes, result.bytes.length);
    expect(result.bytes.length, 171676);
    result.dispose();
    result.dispose();
    expect(budget.accountedBytes, 0);
  });

  test('caps, malformed header and Brotli failure roll back admission', () {
    for (final decoder in [
      const Woff2Decoder(maxBytes: 1),
      const Woff2Decoder(maxTableBytes: 1),
      const Woff2Decoder(maxTables: 1),
    ]) {
      expect(
        () => decoder.decode(source()),
        throwsA(isA<FontFormatException>()),
      );
    }
    final tiny = ReaderResourceBudget(maxBytes: 1);
    expect(
      () => const Woff2Decoder().decode(source(), budget: tiny),
      throwsA(isA<ReaderResourceException>()),
    );
    expect(tiny.accountedBytes, 0);
    for (final mutate in <void Function(Uint8List)>[
      (b) => b[0] = 0,
      (b) => b[14] = 1,
      (b) => b[97] = 0xff,
      (b) => ByteData.sublistView(b).setUint32(16, 12),
      (b) => ByteData.sublistView(b).setUint32(20, 0xffffffff),
    ]) {
      final b = source();
      mutate(b);
      final budget = ReaderResourceBudget();
      expect(
        () => const Woff2Decoder().decode(b, budget: budget),
        throwsA(isA<FontFormatException>()),
      );
      expect(budget.accountedBytes, 0);
    }
    final collection = source();
    ByteData.sublistView(collection).setUint32(4, 0x74746366);
    expect(
      () => const Woff2Decoder().decode(collection),
      throwsA(
        isA<FontFormatException>().having(
          (e) => e.failure,
          'failure',
          FontFormatFailure.unsupportedFormat,
        ),
      ),
    );
  });

  test('transformed Roboto reconstructs glyf/loca and hmtx', () {
    final bytes = File('test/fixtures/reader/fonts/roboto-transformed.woff2')
        .readAsBytesSync();
    final budget = ReaderResourceBudget();
    final result = const Woff2Decoder().decode(bytes, budget: budget);
    expect(sfntChecksum(result.bytes), 0xb1b0afba);
    final actual = tables(result.bytes);
    final control = tables(
      File('tool/oracle/fixtures/styles/EPUB/fonts/Roboto-Regular.ttf')
          .readAsBytesSync(),
    );
    for (final tag in control.keys.where(
      (t) => !['head', 'glyf', 'loca'].contains(t),
    )) {
      expect(actual[tag], control[tag], reason: tag);
    }
    final glyphs = decodedGlyphs(actual), reference = decodedGlyphs(control);
    expect(glyphs, hasLength(1294));
    for (var i = 0; i < reference.length; i++) {
      expect(glyphs[i], reference[i], reason: 'glyph $i');
    }
    result.dispose();
    expect(budget.accountedBytes, 0);
  });

  test('hmtx reconstruction reads xMin from null-transformed glyf/loca', () {
    final control = tables(
      File('tool/oracle/fixtures/styles/EPUB/fonts/Roboto-Regular.ttf')
          .readAsBytesSync(),
    );
    final hmtx = ByteData.sublistView(control['hmtx']!);
    final count = ByteData.sublistView(control['hhea']!).getUint16(34);
    final encoded = join([
      [2],
      for (var i = 0; i < count; i++) u16(hmtx.getUint16(i * 4)),
      for (var i = 0; i < count; i++) u16(hmtx.getUint16(i * 4 + 2)),
    ]);
    final input = [
      for (final entry in control.entries)
        FontTable(
          entry.key,
          entry.key == 'hmtx' ? encoded : entry.value,
          version: entry.key == 'hmtx'
              ? 1
              : ['glyf', 'loca'].contains(entry.key)
              ? 3
              : 0,
          original: entry.value.length,
        ),
    ];
    final result = const Woff2Decoder().decode(makeWoff2(input));
    expect(tables(result.bytes)['hmtx'], control['hmtx']);
    result.dispose();
  });
}
