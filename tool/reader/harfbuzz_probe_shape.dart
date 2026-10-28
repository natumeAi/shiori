import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'harfbuzz_probe_draw.dart';
import 'harfbuzz_probe_ffi.dart';
import 'harfbuzz_probe_gridfit.dart';

final class HbGlyph {
  HbGlyph(
    this.index,
    this.id,
    this.cluster,
    this.advance,
    this.yAdvance,
    this.xOffset,
    this.yOffset,
    this.outline,
  );
  final int index, id, cluster, advance, yAdvance, xOffset, yOffset;
  HbOutline outline;
  Map<String, Object?> json(double factor) => {
    'index': index,
    'glyph': id,
    'cluster': cluster,
    'fontUnits': [advance, yAdvance, xOffset, yOffset],
    'cssPx': [
      advance * factor,
      yAdvance * factor,
      xOffset * factor,
      yOffset * factor,
    ],
    'outlineOperations': outline.operations,
    'outlineBounds': [
      outline.path.getBounds().left,
      outline.path.getBounds().top,
      outline.path.getBounds().right,
      outline.path.getBounds().bottom,
    ],
  };
}

final class HbRun {
  HbRun(
    this.text,
    this.glyphs,
    this.factor,
    this.ligatures, {
    this.gridFitted = false,
  });
  final String text;
  final List<HbGlyph> glyphs;
  final double factor;
  final bool ligatures;
  final bool gridFitted;
  double get width => glyphs.fold<int>(0, (sum, g) => sum + g.advance) * factor;
  List<int> get boundaries =>
      [...glyphs.map((g) => g.cluster).toSet(), text.length]..sort();
  List<List<int>> get clusterMap {
    final b = boundaries;
    return [
      for (var i = 0; i < b.length - 1; i++) [b[i], b[i + 1]],
    ];
  }

  Map<String, Object?> json() => {
    'text': text,
    'features': ligatures ? 'default' : 'liga=0',
    'outlineBackend': gridFitted
        ? 'GDI transform-aware grid-fit, nominal 20px, exact font bytes'
        : 'HB OT unhinted',
    'clusterMap': clusterMap,
    'widthCssPx': width,
    'glyphs': [for (final glyph in glyphs) glyph.json(factor)],
  };
  void close() {
    for (final glyph in glyphs) {
      glyph.outline.close();
    }
    glyphs.clear();
  }
}

final class HbShaper {
  HbShaper(this.api, this.ledger, Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > 32 * 1024 * 1024) {
      throw ArgumentError('Font exceeds probe admission');
    }
    try {
      _fontBytes = _allocate(bytes.length, 'font-input');
      _fontBytes!.cast<Uint8>().asTypedList(bytes.length).setAll(0, bytes);
      fontByteCount = bytes.length;
      // READONLY: the backing allocation outlives blob/face/font.
      blob = api.blobCreate(
        _fontBytes!.cast(),
        bytes.length,
        1,
        nullptr,
        nullptr,
      );
      _own('blob', blob);
      face = api.faceCreate(blob, 0);
      _own('face', face);
      upem = api.faceUpem(face);
      if (upem == 0) throw StateError('Invalid units per em');
      font = api.fontCreate(face);
      _own('font', font);
      api.fontFuncs(font);
      api.fontScale(font, upem, upem);
      drawing = HbDrawing(api, ledger, factor);
    } catch (_) {
      close();
      rethrow;
    }
  }
  final HbApi api;
  final HbLedger ledger;
  Pointer<Void> blob = nullptr, face = nullptr, font = nullptr;
  Pointer<Void>? _fontBytes;
  HbDrawing? drawing;
  HbGridFit? gridFitting;
  int upem = 0, fontByteCount = 0;
  bool _closed = false;
  double get factor => 20 / upem;

  Pointer<Void> _allocate(int bytes, String label) {
    final pointer = api.malloc(bytes);
    if (pointer == nullptr) throw StateError('Allocation failed: $label');
    ledger.take(label, bytes);
    return pointer;
  }

  void _free(Pointer<Void> p, int bytes, String label) {
    api.free(p);
    ledger.release(label, bytes);
  }

  void _own(String label, Pointer<Void> p) {
    if (p == nullptr) throw StateError('hb_$label allocation failed');
    ledger.take(label);
  }

  HbRun shape(String text, {bool ligatures = true, bool gridFit = false}) {
    if (_closed || text.isEmpty || text.length > 4096) {
      throw ArgumentError(
        'Closed shaper or input exceeds bounded UTF-16 probe',
      );
    }
    if (gridFit) {
      gridFitting ??= HbGridFit(api, ledger, _fontBytes!, fontByteCount);
    }
    final buffer = api.bufferCreate();
    _own('buffer', buffer);
    final allocations = <(Pointer<Void>, int, String)>[];
    final glyphs = <HbGlyph>[];
    var glyphPayload = 0;
    Pointer<Void> allocate(int n, String kind) {
      final p = _allocate(n, kind);
      allocations.add((p, n, kind));
      return p;
    }

    try {
      final input = allocate(text.length * 2, 'utf16-input').cast<Uint16>();
      input.asTypedList(text.length).setAll(0, text.codeUnits);
      final en = allocate(3, 'language-input').cast<Uint8>();
      en.asTypedList(3).setAll(0, [101, 110, 0]);
      final length = allocate(4, 'length-output').cast<Uint32>();
      api.bufferAdd(buffer, input, text.length, 0, text.length);
      api.direction(buffer, 4); // HB_DIRECTION_LTR
      api.script(buffer, 0x4c61746e); // HB_SCRIPT_LATIN / 'Latn'
      api.language(buffer, api.languageFromString(en, 2));
      api.clusterLevel(
        buffer,
        0,
      ); // MONOTONE_GRAPHEMES: combining sequences merge.
      Pointer<Void> features = nullptr;
      if (!ligatures) {
        final feature = allocate(
          sizeOf<HbFeature>(),
          'feature-input',
        ).cast<HbFeature>();
        feature.ref
          ..tag =
              0x6c696761 // 'liga'
          ..value = 0
          ..start = 0
          ..end = 0xffffffff;
        features = feature.cast();
      }
      api.shape(font, buffer, features, ligatures ? 0 : 1);
      if (api.allocationSuccessful(buffer) == 0) {
        throw StateError('HB buffer OOM');
      }
      final infos = api.infos(buffer, length);
      final count = length.value;
      final positions = api.positions(buffer, length);
      if (count != length.value ||
          count == 0 ||
          count > 16384 ||
          infos == nullptr ||
          positions == nullptr) {
        throw StateError('Invalid glyph output');
      }
      glyphPayload = count * (sizeOf<HbInfo>() + sizeOf<HbPosition>());
      ledger.take('borrowed-glyph-payload', glyphPayload);
      for (var i = 0; i < count; i++) {
        final info = infos[i], position = positions[i];
        if (info.cluster >= text.length || info.codepoint == 0) {
          throw StateError('Missing glyph or invalid cluster');
        }
        glyphs.add(
          HbGlyph(
            i,
            info.codepoint,
            info.cluster,
            position.xAdvance,
            position.yAdvance,
            position.xOffset,
            position.yOffset,
            drawing!.outline(font, info.codepoint),
          ),
        );
      }
      return HbRun(text, glyphs, factor, ligatures, gridFitted: gridFit);
    } catch (_) {
      for (final glyph in glyphs) {
        glyph.outline.close();
      }
      rethrow;
    } finally {
      if (glyphPayload > 0) {
        ledger.release('borrowed-glyph-payload', glyphPayload);
      }
      for (final a in allocations.reversed) {
        _free(a.$1, a.$2, a.$3);
      }
      api.destroy('buffer', buffer);
      ledger.release('buffer');
    }
  }

  String get version {
    final p = api.version();
    return utf8.decode([for (var i = 0; p[i] != 0 && i < 128; i++) p[i]]);
  }

  void fitGlyph(HbGlyph glyph, double angle, double scaleX) {
    final fitted = gridFitting!.outline(glyph.id, angle, scaleX);
    glyph.outline.close();
    glyph.outline = fitted;
  }

  void close() {
    if (_closed) return;
    _closed = true;
    drawing?.close();
    gridFitting?.close();
    for (final item in [('font', font), ('face', face), ('blob', blob)]) {
      if (item.$2 != nullptr) {
        api.destroy(item.$1, item.$2);
        ledger.release(item.$1);
      }
    }
    if (_fontBytes != null) _free(_fontBytes!, fontByteCount, 'font-input');
  }
}
