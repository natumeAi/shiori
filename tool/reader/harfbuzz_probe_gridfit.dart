// Windows host raster evidence only; not an iOS font backend.
import 'dart:ffi';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';

import 'harfbuzz_probe_draw.dart';
import 'harfbuzz_probe_ffi.dart';
import 'harfbuzz_probe_gridfit_path.dart';

final class HbGridFit {
  HbGridFit(this.api, this.ledger, Pointer<Void> bytes, int length) {
    try {
      _scratch(4, (count) {
        resource = _addFont(bytes, length, nullptr, count.cast());
        _own('gdi-memory-font', resource);
        if (count.cast<Uint32>().value != 1) {
          throw StateError('Unexpected GDI faces');
        }
      });
      dc = _createDC(nullptr);
      _own('gdi-dc', dc);
      _scratch(92, (logFont) {
        // LOGFONTW: nominal font size, regular weight, TrueType AA quality.
        logFont.cast<Uint8>().asTypedList(92).fillRange(0, 92, 0);
        logFont.cast<Int32>()[0] = -20;
        logFont.cast<Int32>()[4] = 400;
        logFont.cast<Uint8>()[23] = 1;
        logFont.cast<Uint8>()[26] = 4;
        logFont
            .cast<Uint16>()
            .asTypedList(46)
            .setRange(14, 20, 'Roboto'.codeUnits);
        font = _createFont(logFont);
        _own('gdi-font', font);
      });
      previous = _select(dc, font);
      if (previous == nullptr || previous.address == 0xffffffffffffffff) {
        throw StateError('Cannot select GDI font');
      }
      final actualLength = _fontData(dc, 0, 0, nullptr, 0);
      if (actualLength != length) {
        throw StateError('GDI font byte length mismatch');
      }
      _scratch(length, (copy) {
        if (_fontData(dc, 0, 0, copy, length) != length ||
            sha256.convert(copy.cast<Uint8>().asTypedList(length)).toString() !=
                sha256
                    .convert(bytes.cast<Uint8>().asTypedList(length))
                    .toString()) {
          throw StateError('GDI selected a different font');
        }
      });
    } catch (_) {
      close();
      rethrow;
    }
  }

  final HbApi api;
  final HbLedger ledger;
  final _gdi = DynamicLibrary.open('gdi32.dll');
  Pointer<Void> resource = nullptr,
      dc = nullptr,
      font = nullptr,
      previous = nullptr;
  bool _closed = false;
  late final _addFont = _gdi
      .lookupFunction<
        Pointer<Void> Function(
          Pointer<Void>,
          Uint32,
          Pointer<Void>,
          Pointer<Uint32>,
        ),
        Pointer<Void> Function(
          Pointer<Void>,
          int,
          Pointer<Void>,
          Pointer<Uint32>,
        )
      >('AddFontMemResourceEx');
  late final _removeFont = _gdi
      .lookupFunction<
        Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)
      >('RemoveFontMemResourceEx');
  late final _createDC = _gdi
      .lookupFunction<
        Pointer<Void> Function(Pointer<Void>),
        Pointer<Void> Function(Pointer<Void>)
      >('CreateCompatibleDC');
  late final _createFont = _gdi
      .lookupFunction<
        Pointer<Void> Function(Pointer<Void>),
        Pointer<Void> Function(Pointer<Void>)
      >('CreateFontIndirectW');
  late final _select = _gdi
      .lookupFunction<
        Pointer<Void> Function(Pointer<Void>, Pointer<Void>),
        Pointer<Void> Function(Pointer<Void>, Pointer<Void>)
      >('SelectObject');
  late final _deleteObject = _gdi
      .lookupFunction<
        Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)
      >('DeleteObject');
  late final _deleteDC = _gdi
      .lookupFunction<
        Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)
      >('DeleteDC');
  late final _fontData = _gdi
      .lookupFunction<
        Uint32 Function(Pointer<Void>, Uint32, Uint32, Pointer<Void>, Uint32),
        int Function(Pointer<Void>, int, int, Pointer<Void>, int)
      >('GetFontData');
  late final _glyphOutline = _gdi
      .lookupFunction<
        Uint32 Function(
          Pointer<Void>,
          Uint32,
          Uint32,
          Pointer<Void>,
          Uint32,
          Pointer<Void>,
          Pointer<Void>,
        ),
        int Function(
          Pointer<Void>,
          int,
          int,
          Pointer<Void>,
          int,
          Pointer<Void>,
          Pointer<Void>,
        )
      >('GetGlyphOutlineW');

  void _own(String name, Pointer<Void> handle) {
    if (handle == nullptr) throw StateError('GDI allocation failed: $name');
    ledger.take(name);
  }

  T _scratch<T>(int size, T Function(Pointer<Void>) work) {
    final pointer = api.malloc(size);
    if (pointer == nullptr) throw StateError('GDI scratch allocation failed');
    ledger.take('gdi-scratch', size);
    try {
      return work(pointer);
    } finally {
      api.free(pointer);
      ledger.release('gdi-scratch', size);
    }
  }

  HbOutline outline(int glyph, double angle, double scaleX) {
    if (_closed) throw StateError('Closed GDI outline owner');
    return _scratch(36, (scratch) {
      // Grid fit in the fragment's actual SVG transform, before translation.
      // GLYPHMETRICS=20 bytes; MAT2=16 bytes, signed 16.16 FIXED matrix.
      final matrix = (scratch.cast<Uint8>() + 20).cast<Void>();
      final cosine = math.cos(angle), sine = math.sin(angle);
      matrix.cast<Int32>().asTypedList(4).setAll(0, [
        (cosine * scaleX * 65536).round(),
        (-sine * scaleX * 65536).round(),
        (sine * 65536).round(),
        (cosine * 65536).round(),
      ]);
      const format =
          2 | 0x80; // GGO_NATIVE | GGO_GLYPH_INDEX; grid fitting enabled.
      final size = _glyphOutline(
        dc,
        glyph,
        format,
        scratch,
        0,
        nullptr,
        matrix,
      );
      if (size == 0xffffffff || size > 16 * 1024 * 1024) {
        throw StateError('GDI glyph outline unavailable/over admission');
      }
      if (size == 0) return decodeGridFitOutline(Uint8List(0), ledger);
      return _scratch(size, (buffer) {
        if (_glyphOutline(dc, glyph, format, scratch, size, buffer, matrix) !=
            size) {
          throw StateError('GDI outline size changed');
        }
        return decodeGridFitOutline(
          buffer.cast<Uint8>().asTypedList(size),
          ledger,
          toLocal: (p) => ui.Offset(
            (cosine * p.dx + sine * p.dy) / scaleX,
            -sine * p.dx + cosine * p.dy,
          ),
        );
      });
    });
  }

  void close() {
    if (_closed) return;
    _closed = true;
    if (dc != nullptr && previous != nullptr) _select(dc, previous);
    final failures = <String>[];
    for (final item in [
      ('gdi-font', font, _deleteObject),
      ('gdi-dc', dc, _deleteDC),
      ('gdi-memory-font', resource, _removeFont),
    ]) {
      if (item.$2 == nullptr) continue;
      if (item.$3(item.$2) == 0) {
        failures.add(item.$1);
      } else {
        ledger.release(item.$1);
      }
    }
    if (failures.isNotEmpty) throw StateError('GDI release failed: $failures');
  }
}
