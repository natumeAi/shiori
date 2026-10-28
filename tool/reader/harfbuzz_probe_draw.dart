import 'dart:ffi';
import 'dart:ui' as ui;

import 'harfbuzz_probe_ffi.dart';

final class HbOutline {
  HbOutline(this.path, this.operations, this.payloadBytes, this.ledger) {
    ledger.take('outline', payloadBytes);
  }
  final ui.Path path;
  final int operations, payloadBytes;
  final HbLedger ledger;
  bool _closed = false;
  void close() {
    if (_closed) return;
    _closed = true;
    path.reset(); // dart:ui Path has no dispose; native backing is GC-managed.
    ledger.release('outline', payloadBytes);
  }
}

/// All callbacks run synchronously on the calling isolate; no listener queue.
final class HbDrawing {
  HbDrawing(this.api, this.ledger, this.factor) {
    funcs = api.drawCreate();
    if (funcs == nullptr) throw StateError('hb_draw_funcs_create failed');
    ledger.take('draw_funcs');
    try {
      move = NativeCallable<HbPoint>.isolateLocal((
        Pointer<Void> a,
        Pointer<Void> b,
        Pointer<Void> c,
        double x,
        double y,
        Pointer<Void> d,
      ) {
        if (_charge(2)) _path.moveTo(x * factor, -y * factor);
      });
      ledger.take('callback');
      line = NativeCallable<HbPoint>.isolateLocal((
        Pointer<Void> a,
        Pointer<Void> b,
        Pointer<Void> c,
        double x,
        double y,
        Pointer<Void> d,
      ) {
        if (_charge(2)) _path.lineTo(x * factor, -y * factor);
      });
      ledger.take('callback');
      quad = NativeCallable<HbQuad>.isolateLocal((
        Pointer<Void> a,
        Pointer<Void> b,
        Pointer<Void> c,
        double x1,
        double y1,
        double x2,
        double y2,
        Pointer<Void> d,
      ) {
        if (_charge(4)) {
          _path.quadraticBezierTo(
            x1 * factor,
            -y1 * factor,
            x2 * factor,
            -y2 * factor,
          );
        }
      });
      ledger.take('callback');
      cubic = NativeCallable<HbCubic>.isolateLocal((
        Pointer<Void> a,
        Pointer<Void> b,
        Pointer<Void> c,
        double x1,
        double y1,
        double x2,
        double y2,
        double x3,
        double y3,
        Pointer<Void> d,
      ) {
        if (_charge(6)) {
          _path.cubicTo(
            x1 * factor,
            -y1 * factor,
            x2 * factor,
            -y2 * factor,
            x3 * factor,
            -y3 * factor,
          );
        }
      });
      ledger.take('callback');
      closePath = NativeCallable<HbClose>.isolateLocal((
        Pointer<Void> a,
        Pointer<Void> b,
        Pointer<Void> c,
        Pointer<Void> d,
      ) {
        if (_charge(0)) _path.close();
      });
      ledger.take('callback');
      api.setMove(funcs, move!.nativeFunction, nullptr, nullptr);
      api.setLine(funcs, line!.nativeFunction, nullptr, nullptr);
      api.setQuad(funcs, quad!.nativeFunction, nullptr, nullptr);
      api.setCubic(funcs, cubic!.nativeFunction, nullptr, nullptr);
      api.setClose(funcs, closePath!.nativeFunction, nullptr, nullptr);
    } catch (_) {
      close();
      rethrow;
    }
  }
  final HbApi api;
  final HbLedger ledger;
  final double factor;
  late final Pointer<Void> funcs;
  NativeCallable<HbPoint>? move, line;
  NativeCallable<HbQuad>? quad;
  NativeCallable<HbCubic>? cubic;
  NativeCallable<HbClose>? closePath;
  late ui.Path _path;
  int _operations = 0, _payload = 0;
  bool _closed = false, _overflow = false;

  bool _charge(int coordinates) {
    if (_overflow) return false;
    if (_operations == 100000 ||
        _payload + 1 + coordinates * 8 > 16 * 1024 * 1024) {
      _overflow = true;
      return false; // Do not throw across an FFI callback.
    }
    _operations++;
    _payload += 1 + coordinates * 8;
    return true;
  }

  HbOutline outline(Pointer<Void> font, int glyph) {
    if (_closed) throw StateError('Closed draw owner');
    _path = ui.Path();
    _operations = _payload = 0;
    _overflow = false;
    api.drawGlyph(font, glyph, funcs, nullptr);
    if (_overflow) {
      _path.reset();
      throw StateError('Outline exceeded bounded probe admission');
    }
    return HbOutline(_path, _operations, _payload, ledger);
  }

  void close() {
    if (_closed) return;
    _closed = true;
    api.destroy('draw_funcs', funcs);
    ledger.release('draw_funcs');
    for (final callback in <NativeCallable<Function>?>[
      move,
      line,
      quad,
      cubic,
      closePath,
    ]) {
      if (callback != null) {
        callback.close();
        ledger.release('callback');
      }
    }
  }
}
