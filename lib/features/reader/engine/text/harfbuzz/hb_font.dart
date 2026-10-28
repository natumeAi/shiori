part of 'harfbuzz.dart';

/// A successful process-font admission of these exact immutable bytes and face.
/// A3 retains the encoded resource lease; callers must not mutate its backing
/// buffer. The descriptor is A3's exact canonical process-font key (including
/// collection index), so requesting this token coalesces its existing admission.
/// This token has no unload/reset and creates no second process budget.
final class HarfBuzzAdmittedFont {
  HarfBuzzAdmittedFont._(this.bytes, this.alias, this.faceIndex);
  final Uint8List bytes;
  final String alias;
  final int faceIndex;
  static Future<HarfBuzzAdmittedFont> load(
    Uint8List bytes, {
    required String faceDescriptor,
    required Future<void> Function(Uint8List, String) register,
    ProcessFontBudget? processFonts,
    int faceIndex = 0,
    PublicationCancellation? cancellation,
  }) async {
    _control();
    _checkCancellation(cancellation);
    if (bytes.isEmpty ||
        faceDescriptor.trim().isEmpty ||
        faceIndex < 0 ||
        faceIndex > 0xffff ||
        bytes.length > 32 * 1024 * 1024) {
      throw const HarfBuzzException(HarfBuzzFailure.invalidFont);
    }
    final alias = await (processFonts ?? ProcessFontBudget.shared).load(
      bytes,
      face: faceDescriptor,
      register: register,
      cancellation: cancellation,
    );
    _checkCancellation(cancellation);
    return HarfBuzzAdmittedFont._(bytes.asUnmodifiableView(), alias, faceIndex);
  }
}

final class HarfBuzzFont {
  factory HarfBuzzFont.open(
    HarfBuzzAdmittedFont admitted, {
    required HarfBuzzBindings bindings,
    required HarfBuzzResources resources,
    double fontSize = 20,
    PublicationCancellation? cancellation,
  }) {
    _control();
    _checkCancellation(cancellation);
    if (!fontSize.isFinite || fontSize <= 0) {
      throw ArgumentError('Font size must be positive and finite');
    }
    final result = HarfBuzzFont._(bindings, resources, fontSize);
    try {
      final memory = resources._allocate(bindings, admitted.bytes.length);
      result._fontBytes = memory;
      memory.pointer
          .cast<Uint8>()
          .asTypedList(admitted.bytes.length)
          .setAll(0, admitted.bytes);
      final blob = result._own(
        'blob',
        () => bindings._blobCreate(
          memory.pointer.cast(),
          admitted.bytes.length,
          1,
          nullptr,
          nullptr,
        ),
      );
      if (bindings._blobLength(blob.pointer) != admitted.bytes.length) {
        throw const HarfBuzzException(HarfBuzzFailure.allocation);
      }
      final face = result._own(
        'face',
        () => bindings._faceCreate(blob.pointer, admitted.faceIndex),
      );
      result.upem = bindings._upem(face.pointer);
      if (result.upem == 0 || bindings._glyphCount(face.pointer) == 0) {
        throw const HarfBuzzException(HarfBuzzFailure.invalidFont);
      }
      result._font = result._own(
        'font',
        () => bindings._fontCreate(face.pointer),
      );
      bindings._fontFuncs(result._font!.pointer);
      bindings._fontScale(result._font!.pointer, result.upem, result.upem);
      result._drawing = _HbDrawing(bindings, resources, result.factor);
      _checkCancellation(cancellation);
      return result;
    } catch (_) {
      result.dispose();
      rethrow;
    }
  }
  HarfBuzzFont._(this.bindings, this.resources, this.fontSize);
  final HarfBuzzBindings bindings;
  final HarfBuzzResources resources;
  final double fontSize;
  int upem = 0;
  double get factor => fontSize / upem;
  final _handles = <_HbHandle>[];
  _HbMemory? _fontBytes;
  _HbHandle? _font;
  _HbDrawing? _drawing;
  bool _disposed = false;

  _HbHandle _own(String kind, Pointer<Void> Function() create) {
    final handle = resources._handle(
      kind,
      create,
      (p) => bindings._destroy(kind, p),
    );
    _handles.add(handle);
    return handle;
  }

  /// One preparation, with two whole-run HB passes: requested layout features
  /// and the same features plus liga=0 for paint. Never shapes substrings.
  /// The SVG placement profile is horizontal LTR; other directions are typed
  /// refusals until their placement/decomposition contracts are established.
  HarfBuzzRun shapeRun(
    String text, {
    HarfBuzzDirection direction = HarfBuzzDirection.ltr,
    String script = 'Latn',
    String language = 'en',
    List<HarfBuzzFeature> features = const [],
    PublicationCancellation? cancellation,
    int? maxGlyphs,
  }) {
    _control();
    _checkCancellation(cancellation);
    if (_disposed) throw const HarfBuzzException(HarfBuzzFailure.disposed);
    if (direction != HarfBuzzDirection.ltr) {
      throw const HarfBuzzException(HarfBuzzFailure.unsupportedRun);
    }
    final glyphLimit = maxGlyphs ?? math.min(65536, text.length * 8 + 16);
    if (text.isEmpty ||
        text.length > 65536 ||
        glyphLimit <= 0 ||
        glyphLimit > 65536 ||
        language.isEmpty ||
        language.length > 128 ||
        language.codeUnits.any((c) => c < 32 || c > 126) ||
        features.length > 256) {
      throw ArgumentError('Invalid or oversized shaping input');
    }
    final tag = harfBuzzTag(script);
    final charge = resources._reserve('run', {
      SceneResource.paragraphs: 1,
      SceneResource.textCodeUnits: text.length,
      // Copied glyph records, range/index maps and per-UTF16 metric slots.
      // This is logical payload admission, not allocator/VM heap measurement.
      SceneResource.sourceBytes: text.length * 10 + glyphLimit * 2 * 128 + 8,
    });
    final outlines = <_HbOutline>[];
    try {
      final metrics = _shapePass(
        this,
        text,
        tag,
        language,
        direction,
        features,
        glyphLimit,
        cancellation,
      );
      final paint = _shapePass(
        this,
        text,
        tag,
        language,
        direction,
        [...features, HarfBuzzFeature('liga', 0)],
        glyphLimit,
        cancellation,
      );
      for (final glyph in paint) {
        _checkCancellation(cancellation);
        outlines.add(_drawing!.outline(_font!.pointer, glyph.id));
      }
      return HarfBuzzRun._(
        text,
        metrics,
        paint,
        outlines,
        factor,
        resources,
        charge,
      );
    } catch (_) {
      for (final outline in outlines.reversed) {
        outline.dispose();
      }
      charge.release();
      rethrow;
    }
  }

  void dispose() {
    _control();
    if (_disposed) return;
    _disposed = true;
    _drawing?.dispose();
    for (final handle in _handles.reversed) {
      handle.dispose();
    }
    _fontBytes?.dispose();
  }
}
