import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/core/config/content_identity.dart';
import 'package:shiori/core/config/server_endpoint.dart';
import 'package:shiori/core/config/server_key.dart';
import 'package:shiori/features/reader/data/geometry/affine_transform.dart';
import 'package:shiori/features/reader/data/geometry/cluster_geometry.dart';
import 'package:shiori/features/reader/data/geometry/source_fragment.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/layout/reading_unit.dart';
import 'package:shiori/features/reader/data/layout/source_page_id.dart';
import 'package:shiori/features/reader/data/layout/source_page_slot.dart';

ContentIdentity contractContent({int bookId = 1, String digest = 'a'}) =>
    ContentIdentity(
      BookKey(
        ServerKey(ServerEndpoint.parse('https://example.test/').endpoint!),
        bookId,
      ),
      digest * 64,
    );

SourcePageId contractPage({
  int section = 0,
  int? spine,
  String id = 'page',
  ContentIdentity? content,
}) => SourcePageId(
  content: content ?? contractContent(),
  sectionIndex: section,
  spineIndex: spine ?? section,
  stableId: id,
);

RealSourcePageSlot contractSlot({
  SourcePageId? page,
  SpreadSide side = SpreadSide.center,
}) => RealSourcePageSlot.fixed(
  page: page ?? contractPage(),
  authoredSize: AuthoredPageSize(320, 240),
  sourceToUnit: const AffineTransform.identity(),
  side: side,
);

ReadingUnitId contractUnitId() =>
    ReadingUnitId(content: contractContent(), stableId: 'composition-1');

ClusterGeometry contractCluster({
  int start = 0,
  int end = 2,
  ClusterGranularity granularity = ClusterGranularity.shapingCluster,
  ClusterProvenance provenance = ClusterProvenance.shaped,
  List<GeometryPoint>? quad,
}) => ClusterGeometry(
  range: Utf16Range(start, end),
  granularity: granularity,
  provenance: provenance,
  quad:
      quad ??
      [
        GeometryPoint(0, 0),
        GeometryPoint(12, 0),
        GeometryPoint(12, 10),
        GeometryPoint(0, 10),
      ],
  baselineStart: GeometryPoint(0, 8),
  baselineEnd: GeometryPoint(12, 8),
  rotationRadians: 0,
);

SourceFragment contractFragment({
  SourceFragmentKind kind = SourceFragmentKind.svgText,
  List<ClusterGeometry>? clusters,
  List<String> clipIds = const [],
  List<String> maskIds = const [],
  double opacity = 1,
  Utf16Range? range,
  int nodeIndex = 3,
  int paintOrdinal = 2,
  SourceElementAnchor? element,
}) => SourceFragment(
  page: contractPage(),
  nodeIndex: nodeIndex,
  kind: kind,
  textRange: kind == SourceFragmentKind.element
      ? null
      : range ?? Utf16Range(0, 2),
  clusters:
      clusters ??
      (kind == SourceFragmentKind.element ? [] : [contractCluster()]),
  elementAnchor: element,
  sourceToUnit: const AffineTransform.identity(),
  clipIds: clipIds,
  maskIds: maskIds,
  paintOrdinal: paintOrdinal,
  effectiveOpacity: opacity,
);
