import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/resources/reader_resource_budget.dart';
import 'package:shiori/features/reader/engine/layout/font_format.dart';
import 'package:shiori/features/reader/engine/layout/woff_decoder.dart';

Uint8List _source() =>
    File('test/fixtures/reader/fixed_layout/Roboto-Regular.woff')
        .readAsBytesSync();
Matcher _failure(FontFormatFailure failure) => throwsA(
  isA<FontFormatException>().having((e) => e.failure, 'failure', failure),
);

// Make the pinned fixture exercise zlib without committing or editing fixtures.
Uint8List _compressTables(Uint8List source) {
  final header = ByteData.sublistView(source);
  final count = header.getUint16(12);
  final prefix = Uint8List.fromList(source.sublist(0, 44 + count * 20));
  final directory = ByteData.sublistView(prefix);
  final output = BytesBuilder()..add(prefix);
  for (var i = 0; i < count; i++) {
    final at = 44 + i * 20;
    final start = header.getUint32(at + 4);
    final size = header.getUint32(at + 12);
    final original = source.sublist(start, start + size);
    final compressed = ZLibEncoder().convert(original);
    final data = compressed.length < size ? compressed : original;
    directory.setUint32(at + 4, output.length);
    directory.setUint32(at + 8, data.length);
    output.add(data);
    output.add(List.filled((4 - data.length % 4) % 4, 0));
  }
  final result = output.takeBytes();
  // BytesBuilder copied the prefix before the offsets were updated.
  result.setRange(0, prefix.length, prefix);
  ByteData.sublistView(result).setUint32(8, result.length);
  return result;
}

void main() {
  test('uncompressed and zlib tables reconstruct identical SFNT bytes', () {
    final budget = ReaderResourceBudget();
    final original = const WoffDecoder().decode(_source(), budget: budget);
    final compressed = const WoffDecoder().decode(
      _compressTables(_source()),
      budget: budget,
    );
    expect(compressed.bytes, original.bytes);
    expect(original.bytes.length, 171676);
    expect(budget.reservedBytes, original.bytes.length * 2);
    original.dispose();
    compressed.dispose();
    compressed.dispose();
    expect(budget.accountedBytes, 0);
  });

  test(
    'conversion reserves before allocation and rolls back corrupt output',
    () {
      final tiny = ReaderResourceBudget(maxBytes: 1);
      expect(
        () => const WoffDecoder().decode(_source(), budget: tiny),
        throwsA(
          isA<ReaderResourceException>().having(
            (e) => e.failure,
            'failure',
            ReaderResourceFailure.budgetExceeded,
          ),
        ),
      );
      expect(tiny.accountedBytes, 0);
      final corrupt = _source();
      final data = ByteData.sublistView(corrupt);
      corrupt[data.getUint32(48)] ^= 1;
      final budget = ReaderResourceBudget();
      expect(
        () => const WoffDecoder().decode(corrupt, budget: budget),
        _failure(FontFormatFailure.malformed),
      );
      expect(budget.accountedBytes, 0);
    },
  );

  test(
    'table/total/count limits reject oversized declarations before charge',
    () {
      for (final (offset, value, short) in [
        (16, 0x7fffffff, false),
        (56, 0x7fffffff, false),
        (12, 129, true),
      ]) {
        final bytes = _source();
        final data = ByteData.sublistView(bytes);
        if (short) {
          data.setUint16(offset, value);
        } else {
          data.setUint32(offset, value);
        }
        final budget = ReaderResourceBudget();
        expect(
          () => const WoffDecoder().decode(bytes, budget: budget),
          _failure(FontFormatFailure.limitExceeded),
        );
        expect(budget.accountedBytes, 0);
      }
    },
  );

  test(
    'length mismatch, overlapping tables, checksum and zlib corruption fail',
    () {
      for (final mutate in <void Function(ByteData)>[
        (d) => d.setUint32(16, d.getUint32(16) - 4),
        (d) => d.setUint32(68, d.getUint32(48)),
        (d) => d.setUint32(60, d.getUint32(60) ^ 1),
        (d) => d.setUint32(8, d.getUint32(8) - 1),
      ]) {
        final bytes = _source();
        mutate(ByteData.sublistView(bytes));
        expect(
          () => const WoffDecoder().decode(bytes),
          _failure(FontFormatFailure.malformed),
        );
      }
      final bytes = _compressTables(_source());
      final at = ByteData.sublistView(bytes).getUint32(48);
      bytes[at] ^= 0xff;
      expect(
        () => const WoffDecoder().decode(bytes),
        _failure(FontFormatFailure.malformed),
      );
    },
  );

  test('zlib output cannot exceed or undershoot the admitted table buffer', () {
    for (final delta in [-4, 4]) {
      final bytes = _compressTables(_source());
      final data = ByteData.sublistView(bytes);
      final count = data.getUint16(12);
      final at = List.generate(count, (i) => 44 + i * 20).firstWhere(
        (at) => data.getUint32(at + 12) - data.getUint32(at + 8) > 4,
      );
      data.setUint32(at + 12, data.getUint32(at + 12) + delta);
      data.setUint32(16, data.getUint32(16) + delta);
      final budget = ReaderResourceBudget();
      expect(
        () => const WoffDecoder().decode(bytes, budget: budget),
        _failure(FontFormatFailure.malformed),
      );
      expect(budget.accountedBytes, 0);
    }
  });
}
