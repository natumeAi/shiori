part of 'woff2_decoder.dart';

/// Reused across both passes. No per-point objects or growing output buffers.
final class _GlyphScratch {
  _GlyphScratch(int count)
    : locations = Uint32List(count + 1),
      xMin = Int16List(count);
  static int byteSize(int count) => 65536 * 11 + (count + 1) * 4 + count * 2;
  final x = Int32List(65536), y = Int32List(65536);
  final flags = Uint8List(65536);
  final ends = Uint16List(65536);
  final Uint32List locations;
  final Int16List xMin;
}

final class _Glyf {
  _Glyf(this.source, this.scratch, this.limit) {
    final r = _Reader(source);
    if (r.u16() != 0) throw _malformed;
    final options = r.u16();
    if ((options & ~1) != 0) throw _malformed;
    count = r.u16();
    indexFormat = r.u16();
    if (count != scratch.xMin.length || indexFormat > 1) throw _malformed;
    final sizes = List.generate(7, (_) => r.u32());
    streams = [for (final size in sizes) _Reader(r.take(size))];
    if (options == 1) overlap = r.take((count + 7) >> 3);
    r.done();
    if (sizes[0] != count * 2) throw _malformed;
    bboxMap = streams[5].take(((count + 31) >> 5) * 4);
  }
  final Uint8List source;
  final _GlyphScratch scratch;
  final int limit;
  late final int count, indexFormat;
  late final List<_Reader> streams;
  late final Uint8List bboxMap;
  Uint8List? overlap;

  bool _bit(Uint8List map, int id) => (map[id >> 3] & (128 >> (id & 7))) != 0;
  // WOFF2 overlapSimpleBitmap uses the opposite bit order to bboxBitmap.
  bool _overlap(int id) =>
      overlap != null && (overlap![id >> 3] & (1 << (id & 7))) != 0;

  int run([Uint8List? target]) {
    final out = _Writer(target?.length ?? limit, target);
    for (var id = 0; id < count; id++) {
      scratch.locations[id] = out.pos;
      final contours = streams[0].i16();
      final hasBox = _bit(bboxMap, id);
      if (contours == 0) {
        if (hasBox || _overlap(id)) throw _malformed;
        scratch.xMin[id] = 0;
        continue;
      }
      if (contours < -1) throw _malformed;
      final start = out.pos;
      out.u16(contours);
      // The bbox occupies these eight bytes; compute simple bounds from points.
      for (var i = 0; i < 4; i++) {
        out.u16(0);
      }
      late (int, int, int, int) box;
      if (contours == -1) {
        if (!hasBox) throw _malformed;
        _composite(out);
        box = _box();
      } else {
        final computed = _simple(out, contours, id);
        box = hasBox ? _box() : computed;
      }
      if (box.$1 > box.$3 || box.$2 > box.$4) throw _malformed;
      scratch.xMin[id] = box.$1;
      if (out.data case final data?) {
        for (final (i, v) in [
          (0, box.$1),
          (1, box.$2),
          (2, box.$3),
          (3, box.$4),
        ]) {
          data.setInt16(start + 2 + i * 2, v);
        }
      }
      out.pad(4);
    }
    scratch.locations[count] = out.pos;
    if (indexFormat == 0 && out.pos > 131070) throw _malformed;
    for (final s in streams) {
      s.done();
    }
    if (target != null && out.pos != target.length) throw _malformed;
    return out.pos;
  }

  (int, int, int, int) _box() =>
      (streams[5].i16(), streams[5].i16(), streams[5].i16(), streams[5].i16());

  void _instructions(_Writer out) {
    final length = streams[3].uint255();
    out.u16(length);
    out.add(streams[6].take(length));
  }

  void _composite(_Writer out) {
    final r = streams[4];
    var haveInstructions = false;
    var flags = 0;
    do {
      flags = r.u16();
      final glyph = r.u16();
      if (glyph >= count || (flags & 0xe010) != 0) throw _malformed;
      out.u16(flags);
      out.u16(glyph);
      out.add(r.take((flags & 1) != 0 ? 4 : 2));
      final transform = flags & (8 | 64 | 128);
      if (transform != 0 &&
          transform != 8 &&
          transform != 64 &&
          transform != 128) {
        throw _malformed;
      }
      out.add(
        r.take(switch (transform) {
          8 => 2,
          64 => 4,
          128 => 8,
          _ => 0,
        }),
      );
      haveInstructions |= (flags & 256) != 0;
    } while ((flags & 32) != 0);
    if (haveInstructions) _instructions(out);
  }
}
