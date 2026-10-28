part of 'harfbuzz.dart';

final class HarfBuzzRun {
  HarfBuzzRun._(
    this.text,
    this.layoutGlyphs,
    this.paintGlyphs,
    this._outlines,
    this.factor,
    this.resources,
    this._charge,
  ) {
    layoutClusters = _ranges(layoutGlyphs);
    paintClusters = _ranges(paintGlyphs);
    advance = layoutGlyphs.fold<int>(0, (s, g) => s + g.advance) * factor;
    _metricOffsets = Float64List(text.length + 1);
    final advances = <int, int>{};
    for (final glyph in layoutGlyphs) {
      advances[glyph.cluster] = (advances[glyph.cluster] ?? 0) + glyph.advance;
    }
    var offset = 0.0;
    for (final range in layoutClusters) {
      final width = advances[range.start]! * factor;
      for (var i = range.start; i < range.end; i++) {
        _metricOffsets[i] =
            offset + width * (i - range.start) / (range.end - range.start);
      }
      offset += width;
    }
    _metricOffsets[text.length] = offset;
    for (final glyph in paintGlyphs) {
      (_paintIndices[glyph.cluster] ??= []).add(glyph.index);
    }
    var layoutIndex = 0;
    for (final paint in paintClusters) {
      while (layoutClusters[layoutIndex].end <= paint.start) {
        layoutIndex++;
      }
      final layout = layoutClusters[layoutIndex];
      if (layout.start > paint.start || layout.end < paint.end) {
        dispose();
        throw const HarfBuzzException(HarfBuzzFailure.unsupportedRun);
      }
      _layoutByPaint[paint.start] = layout;
    }
  }
  final String text;
  final List<HarfBuzzGlyph> layoutGlyphs, paintGlyphs;
  final List<_HbOutline> _outlines;
  final double factor;
  final HarfBuzzResources resources;
  final _HbCharge _charge;
  late final List<Utf16Range> layoutClusters, paintClusters;
  late final Float64List _metricOffsets;
  final _paintIndices = <int, List<int>>{};
  final _layoutByPaint = <int, Utf16Range>{};
  bool _disposed = false;
  late final double advance;

  List<Utf16Range> _ranges(List<HarfBuzzGlyph> glyphs) {
    final boundaries = [...glyphs.map((g) => g.cluster).toSet(), text.length]
      ..sort();
    return List.unmodifiable([
      for (var i = 0; i + 1 < boundaries.length; i++)
        Utf16Range(boundaries[i], boundaries[i + 1]),
    ]);
  }

  double _metricOffset(int index) => _metricOffsets[index];

  /// Reuses both shaped maps and outlines. A3 keeps this owner until all desired
  /// placements are built; placed results independently retain their own Paths.
  HarfBuzzPlacedRun place({
    List<HarfBuzzPosition> positions = const [],
    double x = 0,
    double y = 0,
    bool anchorMiddle = false,
    double? textLength,
    HarfBuzzLengthAdjust lengthAdjust = HarfBuzzLengthAdjust.spacing,
    HarfBuzzQuadraticPath? path,
    HarfBuzzStartOffset startOffset = const HarfBuzzStartOffset.absolute(0),
    int sourceOffset = 0,
    PublicationCancellation? cancellation,
  }) {
    _control();
    _checkCancellation(cancellation);
    if (_disposed) throw const HarfBuzzException(HarfBuzzFailure.disposed);
    if ((positions.isNotEmpty && positions.length != text.length) ||
        !x.isFinite ||
        !y.isFinite ||
        sourceOffset < 0 ||
        (textLength != null && (!textLength.isFinite || textLength <= 0)) ||
        (textLength != null && advance <= 0)) {
      throw ArgumentError('Invalid placement request');
    }
    return _placeRun(
      this,
      positions,
      x,
      y,
      anchorMiddle,
      textLength,
      lengthAdjust,
      path,
      startOffset,
      sourceOffset,
      cancellation,
    );
  }

  void dispose() {
    _control();
    if (_disposed) return;
    _disposed = true;
    for (final outline in _outlines.reversed) {
      outline.dispose();
    }
    _charge.release();
  }
}

final class HarfBuzzPosition {
  HarfBuzzPosition({
    this.x,
    this.y,
    this.dx = 0,
    this.dy = 0,
    this.rotationDegrees = 0,
  }) {
    if ([x, y, dx, dy, rotationDegrees].any((v) => v != null && !v.isFinite)) {
      throw ArgumentError('Positions must be finite');
    }
  }
  final double? x, y;
  final double dx, dy, rotationDegrees;
}

final class HarfBuzzFragment {
  HarfBuzzFragment._(
    this.geometry,
    this.layoutRange,
    this.glyphIndices,
    this.placementAdvance,
    this._outline,
  );
  final ClusterGeometry geometry;
  final Utf16Range layoutRange;
  final List<int> glyphIndices;
  final double placementAdvance;
  final _HbOutline _outline;

  /// Borrowed, immutable-by-contract Path in authored run coordinates. Its
  /// lifetime is the placed result. Draw it; do not mutate or retain after close.
  ui.Path get path => _outline.path;
}

final class HarfBuzzPlacedRun {
  HarfBuzzPlacedRun._(this.fragments, this.advance, this._charge);
  final List<HarfBuzzFragment> fragments;
  final double advance;
  final _HbCharge _charge;
  bool _disposed = false;
  void dispose() {
    _control();
    if (_disposed) return;
    _disposed = true;
    for (final fragment in fragments.reversed) {
      fragment._outline.dispose();
    }
    _charge.release();
  }
}
