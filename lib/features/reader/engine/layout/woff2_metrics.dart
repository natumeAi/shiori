part of 'woff2_decoder.dart';

void _hmtx(Uint8List source, Uint8List target, int metrics, Int16List xMin) {
  final count = xMin.length;
  if (metrics < 1 ||
      metrics > count ||
      target.length != metrics * 2 + count * 2) {
    throw _malformed;
  }
  final r = _Reader(source);
  final flags = r.u8();
  if ((flags & ~3) != 0 || flags == 0) throw _malformed;
  // Read the advances directly into their final interleaved positions.
  final data = ByteData.sublistView(target);
  for (var i = 0; i < metrics; i++) {
    data.setUint16(4 * i, r.u16());
  }
  for (var i = 0; i < count; i++) {
    final omitted = (flags & (i < metrics ? 1 : 2)) != 0;
    final bearing = omitted ? xMin[i] : r.i16();
    data.setInt16(
      i < metrics ? i * 4 + 2 : metrics * 4 + (i - metrics) * 2,
      bearing,
    );
  }
  r.done();
}

void _readXMin(
  Uint8List glyf,
  Uint8List loca,
  Uint8List head,
  _GlyphScratch scratch,
) {
  final format = ByteData.sublistView(head).getInt16(50);
  if (format != 0 && format != 1) throw _malformed;
  final count = scratch.xMin.length;
  final r = _Reader(loca);
  if (loca.length != (count + 1) * (format == 0 ? 2 : 4)) throw _malformed;
  int offset() => format == 0 ? r.u16() * 2 : r.u32();
  var previous = offset();
  if (previous != 0) throw _malformed;
  final data = ByteData.sublistView(glyf);
  for (var i = 0; i < count; i++) {
    final end = offset();
    if (end < previous ||
        end > glyf.length ||
        (end > previous && end - previous < 10)) {
      throw _malformed;
    }
    scratch.xMin[i] = end == previous ? 0 : data.getInt16(previous + 2);
    previous = end;
  }
}
