import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/resources/reader_resource_budget.dart';
import 'package:shiori/features/reader/engine/layout/font_format.dart';
import 'package:shiori/features/reader/engine/layout/woff2_decoder.dart';

import 'woff2_test_support.dart';

void main() {
  final minimal = [
    FontTable('head', Uint8List(54)),
    FontTable('TEST', Uint8List.fromList([1, 2, 3])),
  ];
  void malformed(Uint8List source) {
    final budget = ReaderResourceBudget();
    expect(
      () => const Woff2Decoder().decode(source, budget: budget),
      throwsA(
        isA<FontFormatException>().having(
          (e) => e.failure,
          'failure',
          FontFormatFailure.malformed,
        ),
      ),
    );
    expect(budget.accountedBytes, 0);
  }

  test('explicit unknown tags, metadata/private bounds and padding', () {
    final bytes = makeWoff2(minimal);
    final padded = (bytes.length + 3) & ~3;
    final withMetadata = Uint8List(padded + 8)..setAll(0, bytes);
    final h = ByteData.sublistView(withMetadata)
      ..setUint32(8, withMetadata.length)
      ..setUint32(28, padded)
      ..setUint32(32, 3)
      ..setUint32(36, 100)
      ..setUint32(40, padded + 4)
      ..setUint32(44, 4);
    withMetadata.setAll(padded, [1, 2, 3, 0, 4, 5, 6, 7]);
    const Woff2Decoder().decode(withMetadata).dispose();
    h.setUint32(40, padded);
    malformed(withMetadata);
    h.setUint32(40, padded + 4);
    h.setUint32(36, 0);
    malformed(withMetadata);
    h.setUint32(36, 100);
    h.setUint32(28, padded + 1);
    malformed(withMetadata);
    final trailing = Uint8List(bytes.length + 5)..setAll(0, bytes);
    ByteData.sublistView(trailing).setUint32(8, trailing.length);
    malformed(trailing);
  });
  test(
    'UIntBase128 rejects leading zero, overflow, overlong and truncation',
    () {
      final original = makeWoff2(minimal);
      for (final replacement in <List<int>>[
        [0x80, 54],
        [0x90, 0x80, 0x80, 0x80, 0],
        [0x81, 0x81, 0x81, 0x81, 0x81, 0],
      ]) {
        final bytes = join([
          original.sublist(0, 53),
          replacement,
          original.sublist(54),
        ]);
        ByteData.sublistView(bytes).setUint32(8, bytes.length);
        malformed(bytes);
      }
      final truncated = original.sublist(0, 54)..[53] = 0x81;
      ByteData.sublistView(truncated).setUint32(8, truncated.length);
      malformed(truncated);
    },
  );
  test(
    'duplicates, invalid transform versions and unpaired glyph tables fail',
    () {
      for (final input in [
        [...minimal, FontTable('head', Uint8List(54))],
        [FontTable('head', Uint8List(54), version: 1)],
        [...minimal, FontTable('glyf', Uint8List(0), version: 3)],
        [...minimal, FontTable('loca', Uint8List(0), version: 3)],
        [
          ...minimal,
          FontTable('loca', Uint8List(0)),
          FontTable('glyf', Uint8List(0)),
        ],
        [
          ...minimal,
          FontTable('loca', Uint8List(0), version: 2),
          FontTable('glyf', Uint8List(0), version: 2),
        ],
      ]) {
        malformed(makeWoff2(input));
      }
    },
  );
  test(
    'SFNT admission failure releases the already decoded temporary stream',
    () {
      final source = makeWoff2(minimal);
      final budget = ReaderResourceBudget(maxBytes: 60);
      expect(
        () => const Woff2Decoder().decode(source, budget: budget),
        throwsA(isA<ReaderResourceException>()),
      );
      expect(budget.accountedBytes, 0);
    },
  );
}
