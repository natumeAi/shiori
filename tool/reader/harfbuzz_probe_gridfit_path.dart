import 'dart:typed_data';
import 'dart:ui' as ui;

import 'harfbuzz_probe_draw.dart';
import 'harfbuzz_probe_ffi.dart';

// Decode complete GGO_NATIVE contours. No clipping, topology edits or snapping.
HbOutline decodeGridFitOutline(
  Uint8List bytes,
  HbLedger ledger, {
  ui.Offset Function(ui.Offset)? toLocal,
}) {
  final data = ByteData.sublistView(bytes), path = ui.Path();
  var operations = 0, payload = 0;
  void charge(int coordinates) {
    operations++;
    payload += 1 + coordinates * 8;
    if (operations > 100000 || payload > 16 * 1024 * 1024) {
      throw StateError('Grid-fitted outline exceeds probe admission');
    }
  }

  ui.Offset point(int at) {
    final p = ui.Offset(
      data.getInt32(at, Endian.little) / 65536,
      -data.getInt32(at + 4, Endian.little) / 65536,
    );
    return toLocal?.call(p) ?? p;
  }

  var polygon = 0;
  while (polygon < bytes.length) {
    if (bytes.length - polygon < 16) throw StateError('Short GDI polygon');
    final size = data.getUint32(polygon, Endian.little);
    if (size < 16 ||
        polygon + size > bytes.length ||
        data.getUint32(polygon + 4, Endian.little) != 24) {
      throw StateError('Invalid GDI polygon');
    }
    final start = point(polygon + 8);
    charge(2);
    path.moveTo(start.dx, start.dy);
    var curve = polygon + 16;
    while (curve < polygon + size) {
      if (polygon + size - curve < 4) throw StateError('Short GDI curve');
      final kind = data.getUint16(curve, Endian.little);
      final count = data.getUint16(curve + 2, Endian.little);
      curve += 4;
      if (count == 0 || curve + count * 8 > polygon + size) {
        throw StateError('Invalid GDI point count');
      }
      if (kind == 1) {
        for (var i = 0; i < count; i++) {
          final p = point(curve + i * 8);
          charge(2);
          path.lineTo(p.dx, p.dy);
        }
      } else if (kind == 2 && count >= 2) {
        for (var i = 0; i < count - 1; i++) {
          final control = point(curve + i * 8),
              next = point(curve + (i + 1) * 8);
          final end = i == count - 2 ? next : (control + next) / 2;
          charge(4);
          path.quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
        }
      } else if (kind == 3 && count % 3 == 0) {
        for (var i = 0; i < count; i += 3) {
          final a = point(curve + i * 8), b = point(curve + (i + 1) * 8);
          final end = point(curve + (i + 2) * 8);
          charge(6);
          path.cubicTo(a.dx, a.dy, b.dx, b.dy, end.dx, end.dy);
        }
      } else {
        throw StateError('Unsupported GDI curve type/count');
      }
      curve += count * 8;
    }
    charge(0);
    path.close();
    polygon += size;
  }
  return HbOutline(path, operations, payload, ledger);
}
