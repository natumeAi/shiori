import 'package:shiori/features/reader/data/geometry/affine_transform.dart';
import 'package:shiori/features/reader/data/geometry/paint_geometry.dart';
import 'package:shiori/features/reader/data/geometry/source_fragment.dart';
import 'package:shiori/features/reader/data/geometry/source_geometry.dart';

/// Prepare once when composing a unit, outside motion. Local scene paint is
/// placed by the same matrix; exported fragments already include placement.
/// The prefix makes two pages' clip/group registries disjoint in a spread.
SourceGeometry placeSourceGeometry(
  SourceGeometry geometry,
  AffineTransform placement, {
  required String registryPrefix,
  int paintOrdinalOffset = 0,
}) {
  if (registryPrefix.trim().isEmpty ||
      paintOrdinalOffset < 0 ||
      placement.inverse() is! InvertedTransform) {
    throw ArgumentError(
      'Geometry placement requires an invertible matrix and namespace',
    );
  }
  String id(String value) => '$registryPrefix:$value';
  GeometryRegion region(GeometryRegion r) => GeometryRegion(
    left: r.left,
    top: r.top,
    width: r.width,
    height: r.height,
    radii: r.radii,
    transform: placement.compose(r.transform),
  );
  return SourceGeometry(
    version: geometry.version,
    completeness: geometry.completeness,
    fragments: [
      for (final f in geometry.fragments)
        SourceFragment(
          page: f.page,
          nodeIndex: f.nodeIndex,
          kind: f.kind,
          textRange: f.textRange,
          clusters: f.clusters,
          elementAnchor: f.elementAnchor,
          elementQuad: f.elementQuad,
          sourceToUnit: placement.compose(f.sourceToUnit),
          clipIds: f.clipIds.map(id).toList(),
          maskIds: f.maskIds.map(id).toList(),
          paintOrdinal: f.paintOrdinal + paintOrdinalOffset,
          effectiveOpacity: f.effectiveOpacity,
        ),
    ],
    clips: [
      for (final c in geometry.clips)
        GeometryClip(id: id(c.id), region: region(c.region)),
    ],
    opacityGroups: [
      for (final g in geometry.opacityGroups)
        GeometryOpacityGroup(
          id: id(g.id),
          parentId: g.parentId == null ? null : id(g.parentId!),
          opacity: g.opacity,
        ),
    ],
    paint: [
      for (final p in geometry.paint)
        GeometryPaint(
          nodeIndex: p.nodeIndex,
          paintOrdinal: p.paintOrdinal + paintOrdinalOffset,
          region: region(p.region),
          innerRegion: p.innerRegion == null ? null : region(p.innerRegion!),
          kind: p.kind,
          effectiveOpacity: p.effectiveOpacity,
          exactCoverage: p.exactCoverage,
          argb: p.argb,
          alphaFootprint: p.alphaFootprint?.placed(placement),
          clipIds: p.clipIds.map(id).toList(),
          groupIds: p.groupIds.map(id).toList(),
          textRanges: p.textRanges,
        ),
    ],
  );
}
