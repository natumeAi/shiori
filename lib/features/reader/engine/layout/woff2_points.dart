part of 'woff2_decoder.dart';

extension _GlyfPoints on _Glyf {
  (int, int, int, int) _simple(_Writer out, int contours, int id) {
    var points = 0;
    for (var i = 0; i < contours; i++) {
      final n = streams[1].uint255();
      if (n == 0 || n > 65536 - points) throw _malformed;
      points += n;
      scratch.ends[i] = points - 1;
      out.u16(points - 1);
    }
    if (points == 0) throw _malformed;
    var x = 0, y = 0;
    var xmin = 32767, ymin = 32767, xmax = -32768, ymax = -32768;
    for (var i = 0; i < points; i++) {
      final flag = streams[2].u8();
      final (dx, dy) = _triplet(flag & 127);
      if (dx < -32768 || dx > 32767 || dy < -32768 || dy > 32767) {
        throw _malformed;
      }
      x += dx;
      y += dy;
      if (x < -32768 || x > 32767 || y < -32768 || y > 32767) throw _malformed;
      if (x < xmin) xmin = x;
      if (x > xmax) xmax = x;
      if (y < ymin) ymin = y;
      if (y > ymax) ymax = y;
      scratch.x[i] = dx;
      scratch.y[i] = dy;
      var f = (flag & 128) == 0 ? 1 : 0;
      if (dx == 0) {
        f |= 16;
      } else if (dx.abs() < 256) {
        f |= 2 | (dx > 0 ? 16 : 0);
      }
      if (dy == 0) {
        f |= 32;
      } else if (dy.abs() < 256) {
        f |= 4 | (dy > 0 ? 32 : 0);
      }
      if (i == 0 && _overlap(id)) f |= 64;
      scratch.flags[i] = f;
    }
    _instructions(out);
    for (var i = 0; i < points;) {
      final f = scratch.flags[i];
      var run = 1;
      while (run < 256 && i + run < points && scratch.flags[i + run] == f) {
        run++;
      }
      out.u8(f | (run > 1 ? 8 : 0));
      if (run > 1) out.u8(run - 1);
      i += run;
    }
    for (var axis = 0; axis < 2; axis++) {
      final shortBit = axis == 0 ? 2 : 4;
      final sameBit = axis == 0 ? 16 : 32;
      final values = axis == 0 ? scratch.x : scratch.y;
      for (var i = 0; i < points; i++) {
        final f = scratch.flags[i];
        if ((f & shortBit) != 0) {
          out.u8(values[i].abs());
        } else if ((f & sameBit) == 0) {
          out.u16(values[i]);
        }
      }
    }
    return (xmin, ymin, xmax, ymax);
  }

  (int, int) _triplet(int flag) {
    final r = streams[3];
    int sign(int f, int v) => (f & 1) != 0 ? v : -v;
    if (flag < 10) {
      return (0, sign(flag, ((flag & 14) << 7) + r.u8()));
    }
    if (flag < 20) {
      return (sign(flag, (((flag - 10) & 14) << 7) + r.u8()), 0);
    }
    if (flag < 84) {
      final b0 = flag - 20, b1 = r.u8();
      return (
        sign(flag, 1 + (b0 & 0x30) + (b1 >> 4)),
        sign(flag >> 1, 1 + ((b0 & 0x0c) << 2) + (b1 & 15)),
      );
    }
    if (flag < 120) {
      final b0 = flag - 84;
      return (
        sign(flag, 1 + ((b0 ~/ 12) << 8) + r.u8()),
        sign(flag >> 1, 1 + (((b0 % 12) >> 2) << 8) + r.u8()),
      );
    }
    if (flag < 124) {
      final a = r.u8(), b = r.u8(), c = r.u8();
      return (
        sign(flag, (a << 4) | (b >> 4)),
        sign(flag >> 1, ((b & 15) << 8) | c),
      );
    }
    final dx = r.u16(), dy = r.u16();
    return (sign(flag, dx), sign(flag >> 1, dy));
  }
}
