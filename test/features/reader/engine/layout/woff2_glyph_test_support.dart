import 'dart:typed_data';

/// Independent SFNT parser: compare semantic outlines instead of compression
/// flags, coordinate encodings, repeat encodings, loca offsets or glyph padding.
List<Object> decodedGlyphs(Map<String, Uint8List> tables) {
  final head = ByteData.sublistView(tables['head']!);
  final maxp = ByteData.sublistView(tables['maxp']!);
  final loca = ByteData.sublistView(tables['loca']!);
  final glyf = tables['glyf']!;
  final short = head.getInt16(50) == 0;
  int at(int i) => short ? loca.getUint16(i * 2) * 2 : loca.getUint32(i * 4);
  final result = <Object>[];
  for (var id = 0; id < maxp.getUint16(4); id++) {
    final start = at(id), end = at(id + 1);
    if (start == end) {
      result.add(const <Object>[]);
      continue;
    }
    final bytes = Uint8List.sublistView(glyf, start, end);
    final data = ByteData.sublistView(bytes);
    var pos = 0;
    int u8() => data.getUint8(pos++);
    int u16() {
      final v = data.getUint16(pos);
      pos += 2;
      return v;
    }

    int i16() {
      final v = data.getInt16(pos);
      pos += 2;
      return v;
    }

    final contours = i16();
    if (contours == 0) {
      result.add(const <Object>[]);
      continue;
    }
    final bbox = [i16(), i16(), i16(), i16()];
    if (contours < 0) {
      final start = pos;
      var more = true, instructions = false;
      while (more) {
        final flags = u16();
        u16();
        pos += (flags & 1) != 0 ? 4 : 2;
        pos += (flags & 8) != 0
            ? 2
            : (flags & 64) != 0
            ? 4
            : (flags & 128) != 0
            ? 8
            : 0;
        instructions |= (flags & 256) != 0;
        more = (flags & 32) != 0;
      }
      if (instructions) {
        final n = u16();
        pos += n;
      }
      result.add([contours, bbox, bytes.sublist(start, pos)]);
      continue;
    }
    final ends = List.generate(contours, (_) => u16());
    final n = u16();
    final instructions = bytes.sublist(pos, pos + n);
    pos += n;
    final flags = <int>[];
    while (flags.length <= ends.last) {
      final flag = u8();
      final repeat = (flag & 8) != 0 ? u8() + 1 : 1;
      flags.addAll(List.filled(repeat, flag));
    }
    final axes = <List<int>>[];
    for (var axis = 0; axis < 2; axis++) {
      final short = axis == 0 ? 2 : 4, same = axis == 0 ? 16 : 32;
      var coordinate = 0;
      axes.add([
        for (final flag in flags)
          coordinate += (flag & short) != 0
              ? u8() * ((flag & same) != 0 ? 1 : -1)
              : (flag & same) != 0
              ? 0
              : i16(),
      ]);
    }
    result.add([
      contours,
      bbox,
      ends,
      instructions,
      [for (final f in flags) f & 1],
      flags.first & 64,
      ...axes,
    ]);
  }
  return result;
}
