part of 'harfbuzz.dart';

final class HarfBuzzGlyph {
  const HarfBuzzGlyph._(
    this.index,
    this.id,
    this.cluster,
    this.advance,
    this.yAdvance,
    this.xOffset,
    this.yOffset,
  );
  final int index, id, cluster, advance, yAdvance, xOffset, yOffset;
}

List<HarfBuzzGlyph> _shapePass(
  HarfBuzzFont owner,
  String text,
  int script,
  String language,
  HarfBuzzDirection direction,
  List<HarfBuzzFeature> features,
  int maxGlyphs,
  PublicationCancellation? cancellation,
) {
  final api = owner.bindings, resources = owner.resources;
  final buffer = resources._handle(
    'buffer',
    api._bufferCreate,
    (p) => api._destroy('buffer', p),
    workspaceBytes: maxGlyphs * 40,
  );
  final allocations = <_HbMemory>[];
  Pointer<T> allocate<T extends NativeType>(int bytes) {
    final memory = resources._allocate(api, bytes);
    allocations.add(memory);
    return memory.pointer.cast<T>();
  }

  try {
    if (api._preAllocate(buffer.pointer, maxGlyphs) == 0) {
      throw const HarfBuzzException(HarfBuzzFailure.allocation);
    }
    final input = allocate<Uint16>(text.length * 2);
    input.asTypedList(text.length).setAll(0, text.codeUnits);
    final lang = allocate<Uint8>(language.length);
    lang.asTypedList(language.length).setAll(0, language.codeUnits);
    final length = allocate<Uint32>(4);
    Pointer<_HbFeature> featureInput = nullptr;
    if (features.isNotEmpty) {
      featureInput = allocate<_HbFeature>(
        features.length * sizeOf<_HbFeature>(),
      );
      for (var i = 0; i < features.length; i++) {
        final f = features[i];
        featureInput[i]
          ..tag = f.tag
          ..value = f.value
          ..start = f.start
          ..end = f.end;
      }
    }
    api._bufferAdd(buffer.pointer, input, text.length, 0, text.length);
    api._direction(buffer.pointer, 4 + direction.index);
    api._script(buffer.pointer, script);
    api._language(
      buffer.pointer,
      api._languageFromString(lang, language.length),
    );
    api._clusterLevel(buffer.pointer, 0); // MONOTONE_GRAPHEMES
    _checkCancellation(cancellation);
    api._shape(
      owner._font!.pointer,
      buffer.pointer,
      featureInput,
      features.length,
    );
    _checkCancellation(cancellation);
    if (api._allocationOk(buffer.pointer) == 0) {
      throw const HarfBuzzException(HarfBuzzFailure.allocation);
    }
    final infos = api._infos(buffer.pointer, length);
    final count = length.value;
    final positions = api._positions(buffer.pointer, length);
    if (count == 0 ||
        count > maxGlyphs ||
        count != length.value ||
        infos == nullptr ||
        positions == nullptr) {
      throw const HarfBuzzException(HarfBuzzFailure.invalidShaping);
    }
    final glyphs = <HarfBuzzGlyph>[];
    for (var i = 0; i < count; i++) {
      final info = infos[i], pos = positions[i];
      if (info.codepoint == 0) {
        throw const HarfBuzzException(HarfBuzzFailure.missingGlyph);
      }
      if (info.cluster >= text.length ||
          (i == 0 && info.cluster != 0) ||
          (i > 0 && info.cluster < infos[i - 1].cluster) ||
          pos.yAdvance != 0 ||
          pos.xAdvance < 0) {
        throw const HarfBuzzException(HarfBuzzFailure.unsupportedRun);
      }
      glyphs.add(
        HarfBuzzGlyph._(
          i,
          info.codepoint,
          info.cluster,
          pos.xAdvance,
          pos.yAdvance,
          pos.xOffset,
          pos.yOffset,
        ),
      );
    }
    return List.unmodifiable(glyphs); // Copy before the HB buffer is destroyed.
  } finally {
    for (final allocation in allocations.reversed) {
      allocation.dispose();
    }
    buffer.dispose();
  }
}
