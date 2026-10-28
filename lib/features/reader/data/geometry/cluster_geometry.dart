/// Half-open source UTF-16 offsets; never canonical code-point offsets.
final class Utf16Range {
  Utf16Range(this.start, this.end) {
    if (start < 0 || end <= start) throw ArgumentError('Invalid UTF-16 range');
  }
  final int start, end;
  @override
  bool operator ==(Object other) =>
      other is Utf16Range && start == other.start && end == other.end;
  @override
  int get hashCode => Object.hash(start, end);
}

/// Local authored-coordinate point. Rotation is radians, positive clockwise
/// in the usual CSS coordinate system (positive y down).
final class GeometryPoint {
  GeometryPoint(this.x, this.y) {
    if (!x.isFinite || !y.isFinite) {
      throw ArgumentError('Invalid geometry point');
    }
  }
  final double x, y;
  @override
  bool operator ==(Object other) =>
      other is GeometryPoint && x == other.x && y == other.y;
  @override
  int get hashCode => Object.hash(x, y);
}

enum ClusterGranularity { grapheme, shapingCluster }

enum ClusterProvenance { fixtureDeclared, paragraph, shaped }

/// One grapheme (XHTML) or one shaping cluster (SVG/foreignObject). Quad corners
/// are ordered top-left, top-right, bottom-right, bottom-left in local space;
/// baseline endpoints and rotation retain the separate text fidelity channels.
final class ClusterGeometry {
  ClusterGeometry({
    required this.range,
    required this.granularity,
    required this.provenance,
    required List<GeometryPoint> quad,
    required this.baselineStart,
    required this.baselineEnd,
    required this.rotationRadians,
  }) : quad = List.unmodifiable(quad) {
    if (this.quad.length != 4 ||
        !rotationRadians.isFinite ||
        (granularity == ClusterGranularity.shapingCluster &&
            provenance == ClusterProvenance.paragraph)) {
      throw ArgumentError(
        'Invalid cluster geometry or unproved shaping provenance',
      );
    }
  }
  final Utf16Range range;
  final ClusterGranularity granularity;
  final ClusterProvenance provenance;
  final List<GeometryPoint> quad;
  final GeometryPoint baselineStart, baselineEnd;
  final double rotationRadians;
  @override
  bool operator ==(Object other) =>
      other is ClusterGeometry &&
      range == other.range &&
      granularity == other.granularity &&
      provenance == other.provenance &&
      baselineStart == other.baselineStart &&
      baselineEnd == other.baselineEnd &&
      rotationRadians == other.rotationRadians &&
      Iterable<int>.generate(4).every((i) => quad[i] == other.quad[i]);
  @override
  int get hashCode => Object.hash(
    range,
    granularity,
    provenance,
    baselineStart,
    baselineEnd,
    rotationRadians,
    Object.hashAll(quad),
  );
}
