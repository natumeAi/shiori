part of 'woff2_decoder.dart';

final class _Directory {
  _Directory(Uint8List source, int maxBytes, int maxTableBytes, int maxTables) {
    if (source.length > maxBytes) throw _limit;
    final r = _Reader(source);
    if (source.length < 48 || r.u32() != 0x774f4632) throw _malformed;
    flavor = r.u32();
    if (flavor == 0x74746366) {
      throw const FontFormatException(FontFormatFailure.unsupportedFormat);
    }
    if (flavor != 0x00010000 && flavor != 0x4f54544f && flavor != 0x74727565) {
      throw _malformed;
    }
    if (r.u32() != source.length) throw _malformed;
    final count = r.u16();
    if (r.u16() != 0 || count == 0) throw _malformed;
    final declared = r.u32();
    compressedSize = r.u32();
    if (count > maxTables || declared > maxBytes) throw _limit;
    r.u16(); // major/minor are informational.
    r.u16();
    final metaOffset = r.u32(), metaLength = r.u32(), metaOriginal = r.u32();
    final privateOffset = r.u32(), privateLength = r.u32();
    var originalTotal = 12 + count * 16;
    for (var i = 0; i < count; i++) {
      final flags = r.u8();
      final tagIndex = flags & 63;
      final tag = tagIndex == 63 ? r.u32() : _knownTags[tagIndex];
      final version = flags >> 6;
      final glyph = tag == _tag('glyf') || tag == _tag('loca');
      if ((glyph && version != 0 && version != 3) ||
          (!glyph && version != 0 && !(tag == _tag('hmtx') && version == 1))) {
        throw _malformed;
      }
      final original = r.base128();
      final transformed = glyph ? version == 0 : version != 0;
      final size = transformed ? r.base128() : original;
      if (original > maxTableBytes || size > maxTableBytes) throw _limit;
      if (tables.any((t) => t.tag == tag)) throw _malformed;
      if (tag == _tag('loca') && transformed && size != 0) {
        throw _malformed;
      }
      tables.add(_Table(tag, original, transformed, size, streamSize));
      streamSize += size;
      originalTotal += sfntPaddedLength(original);
      if (streamSize > maxBytes || originalTotal > maxBytes) throw _limit;
    }
    if (declared != originalTotal || compressedSize == 0) throw _malformed;
    final glyf = table('glyf'), loca = table('loca');
    if ((glyf == null) != (loca == null) ||
        (glyf != null &&
            (glyf.transformed != loca!.transformed ||
                tables.indexOf(glyf) > tables.indexOf(loca)))) {
      throw _malformed;
    }
    streamOffset = r.pos;
    final ranges = <(int, int)>[(0, streamOffset + compressedSize)];
    for (final (at, size) in [
      (metaOffset, metaLength),
      (privateOffset, privateLength),
    ]) {
      if ((at == 0) != (size == 0) ||
          at % 4 != 0 ||
          at > source.length ||
          size > source.length - at) {
        throw _malformed;
      }
      if (size > 0) ranges.add((at, at + size));
    }
    if ((metaOffset == 0) != (metaOriginal == 0)) throw _malformed;
    ranges.sort((a, b) => a.$1.compareTo(b.$1));
    var previousEnd = 0;
    for (final (start, end) in ranges) {
      if (start < previousEnd ||
          start > sfntPaddedLength(previousEnd) ||
          end > source.length) {
        throw _malformed;
      }
      for (var j = previousEnd; j < start; j++) {
        if (source[j] != 0) throw _malformed;
      }
      previousEnd = end;
    }
    if (source.length > sfntPaddedLength(previousEnd)) throw _malformed;
    for (var j = previousEnd; j < source.length; j++) {
      if (source[j] != 0) throw _malformed;
    }
  }
  late final int flavor, compressedSize, streamOffset;
  int streamSize = 0;
  final tables = <_Table>[];
  _Table? table(String tag) {
    for (final t in tables) {
      if (t.tag == _tag(tag)) return t;
    }
    return null;
  }
}
