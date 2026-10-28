import 'package:shiori/features/reader/data/geometry/affine_transform.dart';
import 'package:shiori/features/reader/data/geometry/cluster_geometry.dart';

import 'dart:typed_data';

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

enum GeometryPaintKind { solid, border, image, text, decoration }

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
    List<int> alpha = const [],
  }) : alpha = Uint8List.fromList(alpha).asUnmodifiableView() {
    if (width < 1 ||
        height < 1 ||
        !pixelSize.isFinite ||
        pixelSize <= 0 ||
        alpha.length != width * height ||
        alpha.any((v) => v < 0 || v > 255)) {
      throw ArgumentError('Invalid alpha footprint');
    }
  }
  final int width, height;
  final double pixelSize;
  final GeometryPoint origin;

  /// Grid-local coordinates -> reading-unit coordinates. Page placement
  /// changes this matrix without resampling or copying immutable alpha bytes.
  final AffineTransform transform;
  final Uint8List alpha;
  GeometryAlphaFootprint._placed(
    GeometryAlphaFootprint original,
    AffineTransform placement,
  ) : width = original.width,
      height = original.height,
      pixelSize = original.pixelSize,
      origin = original.origin,
      alpha = original.alpha,
      transform = placement.compose(original.transform);
  GeometryAlphaFootprint placed(AffineTransform placement) =>
      GeometryAlphaFootprint._placed(this, placement);
  @override
  bool operator ==(Object other) =>
      other is GeometryAlphaFootprint &&
      width == other.width &&
      height == other.height &&
      pixelSize == other.pixelSize &&
      origin == other.origin &&
      transform == other.transform &&
      _equal(alpha, other.alpha);
  @override
  int get hashCode => Object.hash(
    width,
    height,
    pixelSize,
    origin,
    transform,
    Object.hashAll(alpha),
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
  final double effectiveOpacity;
  final bool exactCoverage;
  final int? argb;
  final GeometryAlphaFootprint? alphaFootprint;
  final List<String> clipIds;
  final List<String> groupIds;
  final List<Utf16Range> textRanges;
  @override
  bool operator ==(Object other) =>
      other is GeometryPaint &&
      (
            nodeIndex,
            paintOrdinal,
            region,
            innerRegion,
            kind,
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
