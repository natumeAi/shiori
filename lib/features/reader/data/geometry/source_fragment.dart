import 'package:shiori/features/reader/data/geometry/affine_transform.dart';
import 'package:shiori/features/reader/data/geometry/cluster_geometry.dart';
import 'package:shiori/features/reader/data/layout/source_page_id.dart';

final class SourceElementAnchor {
  SourceElementAnchor({required this.nodeIndex, this.elementId}) {
    if (nodeIndex < 0 || elementId == '') {
      throw ArgumentError('Invalid element anchor');
    }
  }
  final int nodeIndex;
  final String? elementId;
  @override
  bool operator ==(Object other) =>
      other is SourceElementAnchor &&
      nodeIndex == other.nodeIndex &&
      elementId == other.elementId;
  @override
  int get hashCode => Object.hash(nodeIndex, elementId);
}

enum SourceFragmentKind { xhtmlText, svgText, element }

/// Candidate geometry, with no CFI proof or canonical-coverage authority.
/// svgText includes foreignObject descendants, preserving canonical v1 exclusion.
final class SourceFragment {
  SourceFragment({
    required this.page,
    required this.nodeIndex,
    required this.kind,
    required this.textRange,
    required List<ClusterGeometry> clusters,
    required this.elementAnchor,
    required this.sourceToUnit,
    required List<String> clipIds,
    required List<String> maskIds,
    required this.paintOrdinal,
    required this.effectiveOpacity,
    List<GeometryPoint> elementQuad = const [],
  }) : clusters = List.unmodifiable(clusters),
       elementQuad = List.unmodifiable(elementQuad),
       clipIds = List.unmodifiable(clipIds),
       maskIds = List.unmodifiable(maskIds) {
    if (nodeIndex < 0 ||
        paintOrdinal < 0 ||
        !effectiveOpacity.isFinite ||
        effectiveOpacity < 0 ||
        effectiveOpacity > 1 ||
        [...this.clipIds, ...this.maskIds].any((id) => id.trim().isEmpty) ||
        (elementAnchor?.nodeIndex ?? nodeIndex) != nodeIndex) {
      throw ArgumentError('Invalid fragment identity or paint evidence');
    }
    final range = textRange;
    if (kind == SourceFragmentKind.element) {
      if (range != null ||
          this.clusters.isNotEmpty ||
          elementAnchor == null ||
          this.elementQuad.isNotEmpty && this.elementQuad.length != 4) {
        throw ArgumentError('An element needs its anchor and no text coverage');
      }
    } else {
      if (range == null ||
          this.clusters.isEmpty ||
          this.elementQuad.isNotEmpty) {
        throw ArgumentError(
          'Text requires its range and complete cluster partition',
        );
      }
      var cursor = range.start;
      final granularity = kind == SourceFragmentKind.xhtmlText
          ? ClusterGranularity.grapheme
          : ClusterGranularity.shapingCluster;
      for (final cluster in this.clusters) {
        if (cluster.range.start != cursor ||
            cluster.granularity != granularity) {
          throw ArgumentError(
            'Cluster gaps, overlaps or wrong text granularity',
          );
        }
        cursor = cluster.range.end;
      }
      if (cursor != range.end) {
        throw ArgumentError('Cluster coverage differs from source range');
      }
    }
  }

  final SourcePageId page;
  final int nodeIndex;
  final SourceFragmentKind kind;
  final Utf16Range? textRange;
  final List<ClusterGeometry> clusters;
  final SourceElementAnchor? elementAnchor;

  /// Ordered local box corners; apply sourceToUnit once.
  final List<GeometryPoint> elementQuad;

  /// Includes nested element transforms and page placement, mapping fragment
  /// local authored coordinates to unit coordinates. Do not apply slot twice.
  final AffineTransform sourceToUnit;

  /// Outer-to-inner registry keys. A2 must supply corresponding clip/mask
  /// evidence; identifiers alone never establish visible coverage.
  final List<String> clipIds, maskIds;

  /// Paint order is independent of source node/UTF-16 order.
  final int paintOrdinal;
  final double effectiveOpacity;

  @override
  bool operator ==(Object other) =>
      other is SourceFragment &&
      page == other.page &&
      nodeIndex == other.nodeIndex &&
      kind == other.kind &&
      textRange == other.textRange &&
      elementAnchor == other.elementAnchor &&
      sourceToUnit == other.sourceToUnit &&
      paintOrdinal == other.paintOrdinal &&
      effectiveOpacity == other.effectiveOpacity &&
      _same(clusters, other.clusters) &&
      _same(elementQuad, other.elementQuad) &&
      _same(clipIds, other.clipIds) &&
      _same(maskIds, other.maskIds);
  @override
  int get hashCode => Object.hash(
    page,
    nodeIndex,
    kind,
    textRange,
    elementAnchor,
    sourceToUnit,
    paintOrdinal,
    effectiveOpacity,
    Object.hashAll(clusters),
    Object.hashAll(elementQuad),
    Object.hashAll(clipIds),
    Object.hashAll(maskIds),
  );
}

bool _same<T>(List<T> a, List<T> b) =>
    a.length == b.length &&
    Iterable<int>.generate(a.length).every((i) => a[i] == b[i]);
