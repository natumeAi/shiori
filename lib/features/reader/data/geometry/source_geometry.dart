import 'package:shiori/features/reader/data/geometry/cluster_geometry.dart';
import 'package:shiori/features/reader/data/geometry/source_fragment.dart';
import 'package:shiori/features/reader/data/geometry/paint_geometry.dart';

enum GeometryGapKind { source, clusterMembership, clip, mask, occlusion, paint }

final class GeometryIssue {
  GeometryIssue(this.kind, this.reason) {
    if (reason.trim().isEmpty) {
      throw ArgumentError('A geometry reason is required');
    }
  }
  final GeometryGapKind kind;
  final String reason;
  @override
  bool operator ==(Object other) =>
      other is GeometryIssue && kind == other.kind && reason == other.reason;
  @override
  int get hashCode => Object.hash(kind, reason);
}

sealed class GeometryCompleteness {
  const GeometryCompleteness();
}

/// Producer attestation that required geometry/evidence is exported. Consumers
/// must still resolve evidence and prove visibility against the settled view.
final class CompleteGeometry extends GeometryCompleteness {
  const CompleteGeometry();
  @override
  bool operator ==(Object other) => other is CompleteGeometry;
  @override
  int get hashCode => runtimeType.hashCode;
}

final class IncompleteGeometry extends GeometryCompleteness {
  IncompleteGeometry(List<GeometryIssue> issues)
    : issues = List.unmodifiable(issues) {
    if (this.issues.isEmpty) {
      throw ArgumentError('Incomplete geometry requires issues');
    }
  }
  final List<GeometryIssue> issues;
  @override
  bool operator ==(Object other) =>
      other is IncompleteGeometry &&
      issues.length == other.issues.length &&
      Iterable<int>.generate(issues.length)
          .every((i) => issues[i] == other.issues[i]);
  @override
  int get hashCode => Object.hash(runtimeType, Object.hashAll(issues));
}

final class SourceGeometry {
  SourceGeometry({
    required this.version,
    required List<SourceFragment> fragments,
    required this.completeness,
    List<GeometryClip> clips = const [],
    List<GeometryPaint> paint = const [],
    List<GeometryOpacityGroup> opacityGroups = const [],
  }) : fragments = List.unmodifiable(fragments),
       clips = List.unmodifiable(clips),
       paint = List.unmodifiable(paint),
       opacityGroups = List.unmodifiable(opacityGroups) {
    if (version < 1) throw ArgumentError('Geometry version must be positive');
    if (completeness is CompleteGeometry &&
        this.fragments.any(
          (f) => f.clusters.any(
            (c) => c.provenance == ClusterProvenance.fixtureDeclared,
          ),
        )) {
      throw ArgumentError('Fixture-declared clusters remain provisional');
    }
    final ids = this.clips.map((c) => c.id).toSet();
    if (ids.length != this.clips.length) {
      throw ArgumentError('Duplicate clip registry id');
    }
    final groupIds = <String>{};
    for (final group in this.opacityGroups) {
      if (!groupIds.add(group.id) ||
          group.parentId != null && !groupIds.contains(group.parentId)) {
        throw ArgumentError('Invalid opacity group order');
      }
    }
    if (completeness is CompleteGeometry &&
        (this.fragments.any(
              (f) =>
                  f.clipIds.any((id) => !ids.contains(id)) ||
                  f.maskIds.isNotEmpty,
            ) ||
            this.paint.any(
              (p) =>
                  !p.exactCoverage ||
                  p.clipIds.any((id) => !ids.contains(id)) ||
                  p.groupIds.any((id) => !groupIds.contains(id)) ||
                  const {
                        GeometryPaintKind.text,
                        GeometryPaintKind.image,
                        GeometryPaintKind.decoration,
                      }.contains(p.kind) &&
                      p.alphaFootprint == null,
            ))) {
      throw ArgumentError(
        'Complete geometry requires exact visibility evidence',
      );
    }
  }
  final int version;

  /// Source order; paintOrdinal supplies the independent paint ordering.
  final List<SourceFragment> fragments;
  final GeometryCompleteness completeness;
  final List<GeometryClip> clips;
  final List<GeometryPaint> paint;
  final List<GeometryOpacityGroup> opacityGroups;
  @override
  bool operator ==(Object other) =>
      other is SourceGeometry &&
      version == other.version &&
      completeness == other.completeness &&
      _sameValues(clips, other.clips) &&
      _sameValues(paint, other.paint) &&
      _sameValues(opacityGroups, other.opacityGroups) &&
      fragments.length == other.fragments.length &&
      Iterable<int>.generate(fragments.length)
          .every((i) => fragments[i] == other.fragments[i]);
  @override
  int get hashCode => Object.hash(
    version,
    completeness,
    Object.hashAll(fragments),
    Object.hashAll(clips),
    Object.hashAll(paint),
    Object.hashAll(opacityGroups),
  );
}

bool _sameValues<T>(List<T> a, List<T> b) =>
    a.length == b.length &&
    Iterable<int>.generate(a.length).every((i) => a[i] == b[i]);
