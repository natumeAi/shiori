import 'dart:io';
import 'dart:typed_data';

import 'package:shiori/features/reader/data/resources/reader_resource_budget.dart';
import 'package:shiori/features/reader/engine/layout/font_format.dart';

const _malformed = FontFormatException(FontFormatFailure.malformed);
const _limit = FontFormatException(FontFormatFailure.limitExceeded);
int sfntPaddedLength(int length) => (length + 3) & ~3;

/// The converted buffer remains charged until registration physically drains.
final class ConvertedFont {
  /// The caller must reserve the buffer from [owner] before allocation.
  ConvertedFont.admitted(this.bytes, ReaderResourceSession owner)
    : _owner = owner;
  final Uint8List bytes;
  final ReaderResourceSession _owner;
  void dispose() => _owner.retire();
}

int sfntChecksum(Uint8List bytes) {
  var sum = 0;
  for (var i = 0; i < bytes.length; i += 4) {
    var word = 0;
    for (var k = 0; k < 4; k++) {
      word = (word << 8) | (i + k < bytes.length ? bytes[i + k] : 0);
    }
    sum = (sum + word) & 0xffffffff;
  }
  return sum;
}

void _inflate(Uint8List encoded, Uint8List target) {
  final sink = _TableSink(target);
  try {
    final decoder = ZLibDecoder().startChunkedConversion(sink);
    // Bound input chunks too; native zlib has a fixed-size output buffer.
    for (var i = 0; i < encoded.length; i += 4096) {
      decoder.add(
        Uint8List.sublistView(encoded, i, (i + 4096).clamp(0, encoded.length)),
      );
    }
    decoder.close();
    if (sink.written != target.length) throw _malformed;
  } on Object {
    throw _malformed;
  }
}

final class _TableSink implements Sink<List<int>> {
  _TableSink(this.target);
  final Uint8List target;
  int written = 0;
  @override
  void add(List<int> chunk) {
    if (chunk.length > target.length - written) throw _malformed;
    target.setRange(written, written + chunk.length, chunk);
    written += chunk.length;
  }

  @override
  void close() {}
}

/// WOFF 1.0 only. Count and byte caps also bound synchronous conversion work.
/// Uses platform zlib's chunked decoder, never an unbounded decode-to-list.
final class WoffDecoder {
  const WoffDecoder({
    this.maxBytes = 32 * 1024 * 1024,
    this.maxTableBytes = 16 * 1024 * 1024,
    this.maxTables = 128,
  });
  final int maxBytes, maxTableBytes, maxTables;

  ConvertedFont decode(Uint8List source, {ReaderResourceBudget? budget}) {
    if (source.length > maxBytes) throw _limit;
    if (source.length < 44) throw _malformed;
    final input = ByteData.sublistView(source);
    int u32(int at) => input.getUint32(at);
    final flavor = u32(4);
    final count = input.getUint16(12);
    final length = u32(16);
    if (u32(0) != 0x774f4646 ||
        (flavor != 0x00010000 &&
            flavor != 0x4f54544f &&
            flavor != 0x74727565) ||
        u32(8) != source.length ||
        input.getUint16(14) != 0 ||
        count == 0) {
      throw _malformed;
    }
    if (count > maxTables || length > maxBytes) throw _limit;
    final directoryEnd = 44 + count * 20;
    if (directoryEnd > source.length) throw _malformed;
    final tables =
        <({int tag, int offset, int compressed, int size, int sum})>[];
    final ranges = <(int, int)>[(0, directoryEnd)];
    var total = 12 + count * 16;
    var previousTag = -1;
    for (var i = 0; i < count; i++) {
      final at = 44 + i * 20;
      final tag = u32(at), offset = u32(at + 4);
      final compressed = u32(at + 8), size = u32(at + 12);
      if (size > maxTableBytes) throw _limit;
      if (tag <= previousTag ||
          offset % 4 != 0 ||
          compressed > size ||
          offset < directoryEnd ||
          compressed > source.length - offset ||
          offset > source.length) {
        throw _malformed;
      }
      previousTag = tag;
      total += sfntPaddedLength(size);
      if (total > maxBytes) throw _limit;
      ranges.add((offset, offset + sfntPaddedLength(compressed)));
      tables.add((
        tag: tag,
        offset: offset,
        compressed: compressed,
        size: size,
        sum: u32(at + 16),
      ));
    }
    if (length != total) throw _malformed;
    // Metadata/private blocks are not expanded, but must be valid disjoint ranges.
    for (final (offsetAt, lengthAt) in [(24, 28), (36, 40)]) {
      final offset = u32(offsetAt), size = u32(lengthAt);
      if ((offset == 0) != (size == 0) ||
          offset % 4 != 0 ||
          offset > source.length ||
          size > source.length - offset) {
        throw _malformed;
      }
      if (size != 0) ranges.add((offset, offset + size));
    }
    if ((u32(24) == 0) != (u32(32) == 0)) throw _malformed;
    ranges.sort((a, b) => a.$1.compareTo(b.$1));
    for (var i = 0; i < ranges.length; i++) {
      if (ranges[i].$2 > source.length ||
          (i > 0 && ranges[i].$1 < ranges[i - 1].$2)) {
        throw _malformed;
      }
    }
    final owner = (budget ?? ReaderResourceBudget.shared).createSession();
    try {
      // Existing encoded owner covers the source. Reserve the additional SFNT
      // buffer before allocation; no separate conversion capacity is invented.
      owner.reserve({'sfnt': length});
      final bytes = Uint8List(length);
      final output = ByteData.sublistView(bytes);
      var power = 1, selector = 0;
      while (power * 2 <= count) {
        power *= 2;
        selector++;
      }
      output.setUint32(0, flavor);
      output.setUint16(4, count);
      output.setUint16(6, power * 16);
      output.setUint16(8, selector);
      output.setUint16(10, count * 16 - power * 16);
      var offset = 12 + count * 16;
      int? head;
      for (var i = 0; i < count; i++) {
        final table = tables[i];
        final target = Uint8List.sublistView(
          bytes,
          offset,
          offset + table.size,
        );
        final encoded = Uint8List.sublistView(
          source,
          table.offset,
          table.offset + table.compressed,
        );
        if (table.compressed == table.size) {
          target.setAll(0, encoded);
        } else {
          _inflate(encoded, target);
        }
        if (table.tag == 0x68656164) {
          if (table.size < 54) throw _malformed;
          head = offset;
          output.setUint32(offset + 8, 0);
        }
        if (sfntChecksum(target) != table.sum) throw _malformed;
        final at = 12 + i * 16;
        output.setUint32(at, table.tag);
        output.setUint32(at + 4, table.sum);
        output.setUint32(at + 8, offset);
        output.setUint32(at + 12, table.size);
        offset += sfntPaddedLength(table.size);
      }
      if (head == null) throw _malformed;
      output.setUint32(
        head + 8,
        (0xb1b0afba - sfntChecksum(bytes)) & 0xffffffff,
      );
      return ConvertedFont.admitted(bytes, owner);
    } on Object {
      owner.retire();
      rethrow;
    }
  }
}
