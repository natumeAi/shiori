import 'dart:typed_data';

Uint8List u16(int v) =>
    (ByteData(2)..setUint16(0, v & 65535)).buffer.asUint8List();
Uint8List u32(int v) => (ByteData(4)..setUint32(0, v)).buffer.asUint8List();
Uint8List join(Iterable<List<int>> chunks) {
  final b = BytesBuilder(copy: false);
  for (final chunk in chunks) {
    b.add(chunk);
  }
  return b.takeBytes();
}

Uint8List base128(int value) {
  final bytes = <int>[value & 127];
  while ((value >>= 7) != 0) {
    bytes.insert(0, (value & 127) | 128);
  }
  return Uint8List.fromList(bytes);
}

final class FontTable {
  FontTable(this.tag, this.data, {this.version = 0, int? original})
    : original = original ?? data.length;
  final String tag;
  final Uint8List data;
  final int version, original;
}

/// Standards-defined uncompressed Brotli blocks; no compression tool at runtime.
Uint8List storedBrotli(Uint8List raw) {
  final bits = <int>[0]; // WBITS=16
  void add(int v, int n) {
    for (var i = 0; i < n; i++) {
      bits.add((v >> i) & 1);
    }
  }

  void align() {
    while (bits.length % 8 != 0) {
      bits.add(0);
    }
  }

  add(0, 1); // not last (uncompressed blocks cannot be last)
  final nibbles = raw.length <= 65536
      ? 4
      : raw.length <= 1048576
      ? 5
      : 6;
  add(nibbles - 4, 2);
  add(raw.length - 1, nibbles * 4);
  add(1, 1);
  align();
  final prefix = [
    for (var i = 0; i < bits.length; i += 8)
      [for (var j = 0; j < 8; j++) bits[i + j] << j]
          .fold(0, (int a, int b) => a | b),
  ];
  return join([
    prefix,
    raw,
    [3],
  ]); // last + empty + zero padding
}

Uint8List makeWoff2(List<FontTable> tables) {
  final directory = BytesBuilder(copy: false),
      stream = BytesBuilder(copy: false);
  var originalSize = 12 + tables.length * 16;
  for (final t in tables) {
    directory.add([63 | (t.version << 6), ...t.tag.codeUnits]);
    directory.add(base128(t.original));
    final glyph = t.tag == 'glyf' || t.tag == 'loca';
    if (glyph ? t.version == 0 : t.version != 0) {
      directory.add(base128(t.data.length));
    }
    stream.add(t.data);
    originalSize += (t.original + 3) & ~3;
  }
  final compressed = storedBrotli(stream.takeBytes());
  final header = ByteData(48)
    ..setUint32(0, 0x774f4632)
    ..setUint32(4, 0x00010000)
    ..setUint32(8, 48 + directory.length + compressed.length)
    ..setUint16(12, tables.length)
    ..setUint32(16, originalSize)
    ..setUint32(20, compressed.length);
  return join([header.buffer.asUint8List(), directory.takeBytes(), compressed]);
}

Uint8List transformedGlyf(
  int count,
  List<Uint8List> streams, {
  Uint8List? overlap,
  int indexFormat = 0,
}) => join([
  u16(0),
  u16(overlap == null ? 0 : 1),
  u16(count),
  u16(indexFormat),
  for (final s in streams) u32(s.length),
  ...streams,
  ?overlap,
]);

List<FontTable> glyphFont(
  int count,
  Uint8List glyf, {
  Uint8List? metrics,
  int? metricCount,
  int? metricVersion,
  int indexFormat = 0,
}) {
  final head = Uint8List(54);
  ByteData.sublistView(head).setUint16(50, indexFormat);
  final hhea = Uint8List(36);
  ByteData.sublistView(hhea).setUint16(34, metricCount ?? count);
  final maxp = join([u32(0x10000), u16(count)]);
  return [
    FontTable('glyf', glyf, original: count * 24),
    FontTable(
      'loca',
      Uint8List(0),
      original: (count + 1) * (indexFormat == 0 ? 2 : 4),
    ),
    FontTable('head', head),
    FontTable('hhea', hhea),
    FontTable('maxp', maxp),
    FontTable(
      'hmtx',
      metrics ?? Uint8List(count * 4),
      version: metricVersion ?? 0,
      original: count * 2 + (metricCount ?? count) * 2,
    ),
  ];
}
