import 'package:shiori/features/reader/data/geometry/affine_transform.dart';
import 'package:shiori/features/reader/data/geometry/cluster_geometry.dart';

import 'dart:typed_data';
import 'dart:collection';

/// Resolved rounded rectangle in local coordinates with its actual matrix.
final class GeometryRegion {
  GeometryRegion({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.transform,
    List<double> radii = const [0, 0, 0, 0],
  }) : radii = List.unmodifiable(radii) {
    if (![left, top, width, height, ...radii].every((v) => v.isFinite) ||
        width < 0 ||
        height < 0 ||
        radii.length != 4 ||
        radii.any((v) => v < 0)) {
      throw ArgumentError('Invalid region');
    }
  }
  final double left, top, width, height;
  final AffineTransform transform;
  final List<double> radii;
  @override
  bool operator ==(Object other) =>
      other is GeometryRegion &&
      (left, top, width, height, transform) ==
          (other.left, other.top, other.width, other.height, other.transform) &&
      Iterable<int>.generate(4).every((i) => radii[i] == other.radii[i]);
  @override
  int get hashCode =>
      Object.hash(left, top, width, height, transform, Object.hashAll(radii));
}

/// Intersection of rectangles whose transformed edges land exactly on the
/// authored one-CSS-pixel grid. Other edges require native alpha samples;
/// neither a rotated enclosing box nor rounding may stand in for coverage.
GeometryRegion? uniformPixelRectangle(Iterable<GeometryRegion> regions) {
  double? left, top, right, bottom;
  for (final r in regions) {
    final t = r.transform;
    if (r.radii.any((v) => v != 0) ||
        !((t.b == 0 && t.c == 0) || (t.a == 0 && t.d == 0)) ||
        t.inverse() is! InvertedTransform) {
      return null;
    }
    final x0 = t.a * r.left + t.c * r.top + t.e;
    final y0 = t.b * r.left + t.d * r.top + t.f;
    final x1 = t.a * (r.left + r.width) + t.c * (r.top + r.height) + t.e;
    final y1 = t.b * (r.left + r.width) + t.d * (r.top + r.height) + t.f;
    if (![x0, y0, x1, y1].every((v) => v.isFinite && v == v.roundToDouble())) {
      return null;
    }
    final l = x0 < x1 ? x0 : x1, rr = x0 > x1 ? x0 : x1;
    final tt = y0 < y1 ? y0 : y1, bb = y0 > y1 ? y0 : y1;
    left = left == null || l > left ? l : left;
    top = top == null || tt > top ? tt : top;
    right = right == null || rr < right ? rr : right;
    bottom = bottom == null || bb < bottom ? bb : bottom;
  }
  if (left == null) return null;
  return GeometryRegion(
    left: left,
    top: top!,
    width: right! > left ? right - left : 0,
    height: bottom! > top ? bottom - top : 0,
    transform: const AffineTransform.identity(),
  );
}

final class GeometryClip {
  GeometryClip({required this.id, required this.region}) {
    if (id.trim().isEmpty) throw ArgumentError('Empty clip id');
  }
  final String id;
  final GeometryRegion region;
  @override
  bool operator ==(Object other) =>
      other is GeometryClip && id == other.id && region == other.region;
  @override
  int get hashCode => Object.hash(id, region);
}

enum GeometryMaskKind { alpha, luminance }

enum GeometryMaskUnits { userSpaceOnUse, objectBoundingBox }

/// Explicit, resolved mask evidence. [region] and [coverage] are already in
/// reading-unit space; the coverage is the actual mask alpha (luminance is
/// converted to alpha before retention). A fragment whose [maskIds] cannot be
/// resolved to one of these remains incomplete.
final class GeometryMask {
  GeometryMask({
    required this.id,
    required this.sourceNode,
    required this.units,
    required this.contentUnits,
    required this.kind,
    required this.region,
    required this.coverage,
  }) {
    if (id.trim().isEmpty || sourceNode < 0) {
      throw ArgumentError('Invalid mask evidence');
    }
    if (coverage.masks.isNotEmpty) {
      throw ArgumentError('Mask coverage cannot itself carry mask evidence');
    }
  }
  final String id;
  final int sourceNode;

  /// `maskUnits` and `maskContentUnits` as authored/resolved.
  final GeometryMaskUnits units, contentUnits;
  final GeometryMaskKind kind;
  final GeometryRegion region;

  /// Retained mask alpha over the authored page grid.
  final GeometryAlphaFootprint coverage;

  GeometryMask placed(
    AffineTransform placement, {
    String Function(String id)? idPrefix,
  }) => GeometryMask(
    id: idPrefix?.call(id) ?? id,
    sourceNode: sourceNode,
    units: units,
    contentUnits: contentUnits,
    kind: kind,
    region: GeometryRegion(
      left: region.left,
      top: region.top,
      width: region.width,
      height: region.height,
      radii: region.radii,
      transform: placement.compose(region.transform),
    ),
    coverage: coverage.placed(placement),
  );
  @override
  bool operator ==(Object other) =>
      other is GeometryMask &&
      (id, sourceNode, units, contentUnits, kind, region, coverage) ==
          (
            other.id,
            other.sourceNode,
            other.units,
            other.contentUnits,
            other.kind,
            other.region,
            other.coverage,
          );
  @override
  int get hashCode =>
      Object.hash(id, sourceNode, units, contentUnits, kind, region, coverage);
}

enum GeometryPaintKind { solid, border, image, text, decoration }

/// Ordered SVG paint operations; legacy and composited evidence is combined.
enum GeometryPaintRole { combined, fill, stroke }

final class GeometryOpacityGroup {
  GeometryOpacityGroup({
    required this.id,
    required this.parentId,
    required this.opacity,
  }) {
    if (id.trim().isEmpty ||
        parentId == id ||
        parentId == '' ||
        !opacity.isFinite ||
        opacity < 0 ||
        opacity > 1) {
      throw ArgumentError('Invalid opacity group');
    }
  }
  final String id;
  final String? parentId;
  final double opacity;
  @override
  bool operator ==(Object other) =>
      other is GeometryOpacityGroup &&
      id == other.id &&
      parentId == other.parentId &&
      opacity == other.opacity;
  @override
  int get hashCode => Object.hash(id, parentId, opacity);
}

/// Native alpha samples at an explicit authored-coordinate grid. These are
/// actual paint, including clips; never an opaque enclosing-box approximation.
/// Visibility consumers must account for the declared sample resolution.
final class GeometryAlphaFootprint {
  GeometryAlphaFootprint({
    required this.width,
    required this.height,
    required this.pixelSize,
    required this.origin,
    this.transform = const AffineTransform.identity(),
    List<GeometryMask> masks = const [],
    List<int> alpha = const [],
  }) : masks = List.unmodifiable(masks),
       uniformAlpha = null,
       alpha = Uint8List.fromList(alpha).asUnmodifiableView() {
    if (width < 1 ||
        height < 1 ||
        !pixelSize.isFinite ||
        pixelSize <= 0 ||
        alpha.length != width * height ||
        alpha.any((v) => v < 0 || v > 255)) {
      throw ArgumentError('Invalid alpha footprint');
    }
  }

  /// Exact constant samples, with the same grid placement as explicit samples.
  /// The immutable sample view never materializes a grid.
  GeometryAlphaFootprint.uniform({
    required this.width,
    required this.height,
    required this.pixelSize,
    required this.origin,
    required int alpha,
    this.transform = const AffineTransform.identity(),
    List<GeometryMask> masks = const [],
  }) : uniformAlpha = alpha,
       alpha = _UniformAlpha(width * height, alpha),
       masks = List.unmodifiable(masks) {
    if (width < 1 ||
        height < 1 ||
        !pixelSize.isFinite ||
        pixelSize <= 0 ||
        alpha < 0 ||
        alpha > 255) {
      throw ArgumentError('Invalid uniform alpha footprint');
    }
  }
  static const storageOverhead = 128;

  /// Two-pass, row-major tile stream. Tiles are borrowed for each callback;
  /// replay must return the same immutable samples. Only the final trimmed
  /// nonuniform grid is allocated, after retained-payload admission.
  static Future<GeometryAlphaFootprint> fromTiles({
    required int width,
    required int height,
    required GeometryPoint origin,
    required Future<void> Function(
      void Function(int x, int y, int width, int height, List<int> rgba) accept,
    )
    visitTiles,
    required void Function(int bytes) reserve,
  }) async {
    if (width < 1 || height < 1) throw ArgumentError('Invalid tile grid');
    var left = width, top = height, right = 0, bottom = 0;
    int? nonzeroValue;
    var nonzeroCount = 0, sameNonzero = true;
    Future<void> visit(void Function(int x, int y, int value) sample) async {
      var nextX = 0, nextY = 0, bandHeight = 0;
      await visitTiles((x, y, w, h, rgba) {
        if (w < 1 ||
            h < 1 ||
            x != nextX ||
            y != nextY ||
            x + w > width ||
            y + h > height ||
            (nextX != 0 && h != bandHeight) ||
            rgba.length != w * h * 4) {
          throw ArgumentError('Incomplete, overlapping or unordered tiles');
        }
        bandHeight = h;
        for (var yy = 0; yy < h; yy++) {
          for (var xx = 0; xx < w; xx++) {
            final value = rgba[(yy * w + xx) * 4 + 3];
            if (value < 0 || value > 255) throw ArgumentError('Invalid alpha');
            sample(x + xx, y + yy, value);
          }
        }
        nextX += w;
        if (nextX == width) {
          nextX = 0;
          nextY += h;
        }
      });
      if (nextX != 0 || nextY != height) {
        throw ArgumentError('Incomplete tile stream');
      }
    }

    await visit((x, y, value) {
      if (value == 0) return;
      nonzeroCount++;
      nonzeroValue ??= value;
      if (nonzeroValue != value) sameNonzero = false;
      if (x < left) left = x;
      if (y < top) top = y;
      if (x + 1 > right) right = x + 1;
      if (y + 1 > bottom) bottom = y + 1;
    });
    if (nonzeroCount == 0) {
      left = top = 0;
      right = width;
      bottom = height;
    }
    final w = right - left, h = bottom - top;
    final uniform = nonzeroCount == 0 || (sameNonzero && nonzeroCount == w * h);
    reserve(storageOverhead + (uniform ? 0 : w * h));
    final start = GeometryPoint(origin.x + left, origin.y + top);
    if (uniform) {
      return GeometryAlphaFootprint.uniform(
        width: w,
        height: h,
        pixelSize: 1,
        origin: start,
        alpha: nonzeroValue ?? 0,
      );
    }
    final alpha = Uint8List(w * h);
    await visit((x, y, value) {
      if (x >= left && x < right && y >= top && y < bottom) {
        alpha[(y - top) * w + x - left] = value;
      }
    });
    return GeometryAlphaFootprint._samples(
      w,
      h,
      start,
      alpha,
      1,
      const AffineTransform.identity(),
      const [],
    );
  }

  /// Trim transparent margins without changing any native one-pixel sample.
  /// Reserve the retained payload before its allocation. No full alpha copy is
  /// made while classifying the borrowed (already admitted) RGBA readback.
  static GeometryAlphaFootprint fromRgba({
    required int width,
    required int height,
    required List<int> rgba,
    required GeometryPoint origin,
    required void Function(int bytes) reserve,
    bool trim = true,
  }) {
    if (width < 1 || height < 1 || rgba.length != width * height * 4) {
      throw ArgumentError('Invalid RGBA coverage');
    }
    return fromSamples(
      width: width,
      height: height,
      origin: origin,
      sample: (x, y) => rgba[(y * width + x) * 4 + 3],
      reserve: reserve,
      trim: trim,
    );
  }

  /// Classify borrowed samples before allocating retained coverage. Trimming
  /// changes only the grid origin, including through a composed placement.
  static GeometryAlphaFootprint fromSamples({
    required int width,
    required int height,
    required GeometryPoint origin,
    required int Function(int x, int y) sample,
    required void Function(int bytes) reserve,
    double pixelSize = 1,
    AffineTransform transform = const AffineTransform.identity(),
    List<GeometryMask> masks = const [],
    bool trim = true,
  }) {
    if (width < 1 || height < 1 || !pixelSize.isFinite || pixelSize <= 0) {
      throw ArgumentError('Invalid sample grid');
    }
    var left = width, top = height, right = 0, bottom = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final value = sample(x, y);
        if (value < 0 || value > 255) {
          throw ArgumentError('Invalid alpha sample');
        }
        if (value == 0) continue;
        if (x < left) left = x;
        if (y < top) top = y;
        if (x + 1 > right) right = x + 1;
        if (y + 1 > bottom) bottom = y + 1;
      }
    }
    if (!trim || right == 0) {
      left = top = 0;
      right = width;
      bottom = height;
    }
    final w = right - left, h = bottom - top;
    final value = sample(left, top);
    var uniform = true;
    for (var y = top; y < bottom && uniform; y++) {
      for (var x = left; x < right; x++) {
        if (sample(x, y) != value) {
          uniform = false;
          break;
        }
      }
    }
    reserve(storageOverhead + (uniform ? 0 : w * h));
    final start = GeometryPoint(
      origin.x + left * pixelSize,
      origin.y + top * pixelSize,
    );
    if (uniform) {
      return GeometryAlphaFootprint.uniform(
        width: w,
        height: h,
        pixelSize: pixelSize,
        origin: start,
        alpha: value,
        transform: transform,
        masks: masks,
      );
    }
    final alpha = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        alpha[y * w + x] = sample(left + x, top + y);
      }
    }
    return GeometryAlphaFootprint._samples(
      w,
      h,
      start,
      alpha,
      pixelSize,
      transform,
      masks,
    );
  }

  GeometryAlphaFootprint._samples(
    this.width,
    this.height,
    this.origin,
    Uint8List samples,
    this.pixelSize,
    this.transform,
    List<GeometryMask> masks,
  ) : masks = List.unmodifiable(masks),
      uniformAlpha = null,
      alpha = samples.asUnmodifiableView();
  final int? uniformAlpha;
  int get storageBytes =>
      storageOverhead + (uniformAlpha == null ? alpha.length : 0);
  final int width, height;
  final double pixelSize;
  final GeometryPoint origin;

  /// Grid-local coordinates -> reading-unit coordinates. Page placement
  /// changes this matrix without resampling or copying immutable alpha bytes.
  final AffineTransform transform;

  /// Mask applications whose retained coverage is collapsed by this paint.
  /// A paint footprint has exact post-clip paint alpha; masks remain separate
  /// compositing evidence and are applied by visibility consumers.
  final List<GeometryMask> masks;
  final List<int> alpha;

  /// Inverse-map a unit-space point to the unchanged authored sample grid.
  /// Null means placement is not invertible; it must not prove visibility.
  int? alphaAt(GeometryPoint point) {
    final inverse = transform.inverse();
    if (inverse is! InvertedTransform) return null;
    final t = inverse.transform;
    final x = ((t.a * point.x + t.c * point.y + t.e - origin.x) / pixelSize)
        .floor();
    final y = ((t.b * point.x + t.d * point.y + t.f - origin.y) / pixelSize)
        .floor();
    return x < 0 || x >= width || y < 0 || y >= height
        ? 0
        : alpha[y * width + x];
  }

  GeometryAlphaFootprint._placed(
    GeometryAlphaFootprint original,
    AffineTransform placement,
    String Function(String id)? idPrefix,
  ) : width = original.width,
      height = original.height,
      pixelSize = original.pixelSize,
      origin = original.origin,
      uniformAlpha = original.uniformAlpha,
      alpha = original.alpha,
      masks = List.unmodifiable([
        for (final mask in original.masks)
          mask.placed(placement, idPrefix: idPrefix),
      ]),
      transform = placement.compose(original.transform);
  GeometryAlphaFootprint placed(
    AffineTransform placement, {
    String Function(String id)? maskId,
  }) => GeometryAlphaFootprint._placed(this, placement, maskId);

  /// Attach compositing evidence while sharing either immutable sample form.
  GeometryAlphaFootprint withMasks(List<GeometryMask> masks) =>
      GeometryAlphaFootprint._masked(this, masks);
  GeometryAlphaFootprint._masked(
    GeometryAlphaFootprint original,
    List<GeometryMask> masks,
  ) : width = original.width,
      height = original.height,
      pixelSize = original.pixelSize,
      origin = original.origin,
      transform = original.transform,
      uniformAlpha = original.uniformAlpha,
      alpha = original.alpha,
      masks = List.unmodifiable(masks);
  @override
  bool operator ==(Object other) =>
      other is GeometryAlphaFootprint &&
      width == other.width &&
      height == other.height &&
      pixelSize == other.pixelSize &&
      origin == other.origin &&
      transform == other.transform &&
      _equal(alpha, other.alpha) &&
      _equal(masks, other.masks);
  @override
  int get hashCode => Object.hash(
    width,
    height,
    pixelSize,
    origin,
    transform,
    Object.hashAll(alpha),
    Object.hashAll(masks),
  );
}

/// Missing exact alpha footprints remain explicit. The enclosing rectangle
/// must never be used as opaque coverage for text or images.
final class GeometryPaint {
  GeometryPaint({
    required this.nodeIndex,
    required this.paintOrdinal,
    required this.region,
    required this.kind,
    required this.effectiveOpacity,
    required this.exactCoverage,
    this.role = GeometryPaintRole.combined,
    this.argb,
    this.innerRegion,
    this.alphaFootprint,
    List<String> clipIds = const [],
    List<String> groupIds = const [],
    List<Utf16Range> textRanges = const [],
  }) : clipIds = List.unmodifiable(clipIds),
       groupIds = List.unmodifiable(groupIds),
       textRanges = List.unmodifiable(textRanges) {
    if (nodeIndex < 0 ||
        paintOrdinal < 0 ||
        !effectiveOpacity.isFinite ||
        effectiveOpacity < 0 ||
        effectiveOpacity > 1 ||
        clipIds.any((id) => id.trim().isEmpty)) {
      throw ArgumentError('Invalid paint evidence');
    }
  }
  final int nodeIndex, paintOrdinal;
  final GeometryRegion region;
  final GeometryRegion? innerRegion;
  final GeometryPaintKind kind;
  final GeometryPaintRole role;
  final double effectiveOpacity;
  final bool exactCoverage;
  final int? argb;
  final GeometryAlphaFootprint? alphaFootprint;
  final List<String> clipIds;
  final List<String> groupIds;
  final List<Utf16Range> textRanges;

  /// Mask evidence retained on this paint's exact alpha footprint.
  List<GeometryMask> get masks => alphaFootprint?.masks ?? const [];
  @override
  bool operator ==(Object other) =>
      other is GeometryPaint &&
      (
            nodeIndex,
            paintOrdinal,
            region,
            innerRegion,
            kind,
            role,
            effectiveOpacity,
            exactCoverage,
            argb,
            alphaFootprint,
          ) ==
          (
            other.nodeIndex,
            other.paintOrdinal,
            other.region,
            other.innerRegion,
            other.kind,
            other.role,
            other.effectiveOpacity,
            other.exactCoverage,
            other.argb,
            other.alphaFootprint,
          ) &&
      _equal(clipIds, other.clipIds) &&
      _equal(groupIds, other.groupIds) &&
      _equal(textRanges, other.textRanges);
  @override
  int get hashCode => Object.hash(
    nodeIndex,
    paintOrdinal,
    region,
    innerRegion,
    kind,
    role,
    effectiveOpacity,
    exactCoverage,
    argb,
    alphaFootprint,
    Object.hashAll(clipIds),
    Object.hashAll(groupIds),
    Object.hashAll(textRanges),
  );
}

bool _equal<T>(List<T> a, List<T> b) =>
    a.length == b.length &&
    Iterable<int>.generate(a.length).every((i) => a[i] == b[i]);

final class _UniformAlpha extends ListBase<int> {
  _UniformAlpha(this.length, this.value);
  @override
  final int length;
  final int value;
  @override
  set length(int value) => throw UnsupportedError('Immutable alpha');
  @override
  void operator []=(int index, int value) =>
      throw UnsupportedError('Immutable alpha');
  @override
  int operator [](int index) {
    RangeError.checkValidIndex(index, this);
    return value;
  }
}
