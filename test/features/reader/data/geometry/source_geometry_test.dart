import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/geometry/affine_transform.dart';
import 'package:shiori/features/reader/data/geometry/cluster_geometry.dart';
import 'package:shiori/features/reader/data/geometry/paint_geometry.dart';
import 'package:shiori/features/reader/data/geometry/place_source_geometry.dart';
import 'package:shiori/features/reader/data/geometry/source_fragment.dart';
import 'package:shiori/features/reader/data/geometry/source_geometry.dart';

import '../../contract_test_values.dart';

void main() {
  test('SVG shaping clusters retain ligature/combining UTF-16 membership', () {
    final fragment = contractFragment(
      clusters: [
        contractCluster(start: 0, end: 2),
        contractCluster(start: 2, end: 4),
      ],
      range: Utf16Range(0, 4),
    );
    expect(fragment.clusters.map((c) => c.range), [
      Utf16Range(0, 2),
      Utf16Range(2, 4),
    ]);
    expect(
      fragment.clusters.every(
        (c) => c.granularity == ClusterGranularity.shapingCluster,
      ),
      isTrue,
    );
    expect(
      () => contractFragment(
        clusters: [contractCluster(end: 1), contractCluster(start: 0)],
      ),
      throwsArgumentError,
    );
    expect(
      () => contractFragment(clusters: [contractCluster(end: 1)]),
      throwsArgumentError,
    );
    expect(
      () => contractFragment(clusters: [contractCluster(start: 1)]),
      throwsArgumentError,
    );
    expect(() => contractFragment(clusters: []), throwsArgumentError);
  });

  test('XHTML requires graphemes and SVG cannot claim paragraph shaping', () {
    final grapheme = contractCluster(
      granularity: ClusterGranularity.grapheme,
      provenance: ClusterProvenance.paragraph,
    );
    expect(
      contractFragment(
        kind: SourceFragmentKind.xhtmlText,
        clusters: [grapheme],
      ).clusters.single,
      grapheme,
    );
    expect(() => contractFragment(clusters: [grapheme]), throwsArgumentError);
    expect(
      () => contractFragment(kind: SourceFragmentKind.xhtmlText),
      throwsArgumentError,
    );
    expect(
      () => contractCluster(provenance: ClusterProvenance.paragraph),
      throwsArgumentError,
    );
    expect(() => Utf16Range(-1, 1), throwsArgumentError);
    expect(() => Utf16Range(1, 1), throwsArgumentError);
    expect(() => GeometryPoint(double.nan, 0), throwsArgumentError);
    expect(() => contractCluster(quad: []), throwsArgumentError);
  });

  test('image/element geometry requires an element anchor and no text', () {
    final anchor = SourceElementAnchor(nodeIndex: 3, elementId: 'image');
    final image = contractFragment(
      kind: SourceFragmentKind.element,
      element: anchor,
    );
    expect(image.textRange, isNull);
    expect(image.clusters, isEmpty);
    expect(
      image.elementAnchor,
      SourceElementAnchor(nodeIndex: 3, elementId: 'image'),
    );
    expect(
      () => contractFragment(kind: SourceFragmentKind.element),
      throwsArgumentError,
    );
    expect(
      () => contractFragment(
        kind: SourceFragmentKind.element,
        element: anchor,
        clusters: [contractCluster()],
      ),
      throwsArgumentError,
    );
    expect(
      () => contractFragment(element: SourceElementAnchor(nodeIndex: 7)),
      throwsArgumentError,
    );
    expect(() => SourceElementAnchor(nodeIndex: -1), throwsArgumentError);
  });

  test(
    'paint evidence validates opacity, ordinals and evidence identifiers',
    () {
      for (final opacity in [-0.1, 1.1, double.nan, double.infinity]) {
        expect(() => contractFragment(opacity: opacity), throwsArgumentError);
      }
      expect(contractFragment(opacity: 0).effectiveOpacity, 0);
      expect(() => contractFragment(nodeIndex: -1), throwsArgumentError);
      expect(() => contractFragment(paintOrdinal: -1), throwsArgumentError);
      expect(() => contractFragment(clipIds: [' ']), throwsArgumentError);
      expect(() => contractFragment(maskIds: ['']), throwsArgumentError);
    },
  );

  test('nested geometry is copied, immutable and equal by value', () {
    final quad = [
      GeometryPoint(0, 0),
      GeometryPoint(12, 0),
      GeometryPoint(12, 10),
      GeometryPoint(0, 10),
    ];
    final cluster = contractCluster(quad: quad);
    final clusters = [cluster];
    final clips = ['outer', 'inner'];
    final masks = ['mask'];
    final fragment = contractFragment(
      clusters: clusters,
      clipIds: clips,
      maskIds: masks,
    );
    final fragments = [fragment];
    final missingEvidence = IncompleteGeometry([
      GeometryIssue(GeometryGapKind.mask, 'Registry not supplied'),
    ]);
    final geometry = SourceGeometry(
      version: 1,
      fragments: fragments,
      completeness: missingEvidence,
    );
    final equal = SourceGeometry(
      version: 1,
      fragments: [
        contractFragment(clipIds: ['outer', 'inner'], maskIds: ['mask']),
      ],
      completeness: missingEvidence,
    );
    quad.clear();
    clusters.clear();
    clips.clear();
    masks.clear();
    fragments.clear();
    expect(geometry, equal);
    expect(geometry.hashCode, equal.hashCode);
    expect(() => cluster.quad.clear(), throwsUnsupportedError);
    expect(() => fragment.clusters.clear(), throwsUnsupportedError);
    expect(() => fragment.clipIds.clear(), throwsUnsupportedError);
    expect(() => fragment.maskIds.clear(), throwsUnsupportedError);
    expect(() => geometry.fragments.clear(), throwsUnsupportedError);
    expect(fragment, isNot(contractFragment(paintOrdinal: 3)));
  });

  test(
    'mask evidence composes through geometry placement with namespaced ids',
    () {
      GeometryRegion region(AffineTransform transform) => GeometryRegion(
        left: 0,
        top: 0,
        width: 10,
        height: 8,
        transform: transform,
      );
      final footprint = GeometryAlphaFootprint(
        width: 2,
        height: 1,
        pixelSize: 1,
        origin: GeometryPoint(0, 0),
        alpha: [0, 96],
      );
      final mask = GeometryMask(
        id: 'mask',
        sourceNode: 3,
        units: GeometryMaskUnits.userSpaceOnUse,
        contentUnits: GeometryMaskUnits.userSpaceOnUse,
        kind: GeometryMaskKind.alpha,
        region: region(const AffineTransform.identity()),
        coverage: footprint,
      );
      final paint = GeometryPaint(
        nodeIndex: 2,
        paintOrdinal: 1,
        region: region(const AffineTransform.identity()),
        kind: GeometryPaintKind.solid,
        effectiveOpacity: 1,
        exactCoverage: true,
        alphaFootprint: GeometryAlphaFootprint(
          width: 2,
          height: 1,
          pixelSize: 1,
          origin: GeometryPoint(0, 0),
          alpha: [255, 0],
          masks: [mask],
        ),
      );
      final geometry = SourceGeometry(
        version: 1,
        fragments: [
          contractFragment(maskIds: ['mask']),
        ],
        paint: [paint],
        completeness: const CompleteGeometry(),
      );
      final placed = placeSourceGeometry(
        geometry,
        AffineTransform(1, 0, 0, 1, 7, 9),
        registryPrefix: 'page',
      );
      expect(placed.fragments.single.maskIds, ['page:mask']);
      expect(placed.masks.single.id, 'page:mask');
      expect(placed.masks.single.region.transform.e, 7);
      expect(placed.masks.single.coverage.transform.e, 7);
      expect(
        () => SourceGeometry(
          version: 1,
          fragments: [
            contractFragment(maskIds: ['mask']),
          ],
          completeness: const CompleteGeometry(),
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'completeness is explicit; fixture maps cannot satisfy complete export',
    () {
      final issues = [
        GeometryIssue(GeometryGapKind.clusterMembership, 'fixture-declared'),
      ];
      final incomplete = IncompleteGeometry(issues);
      issues.clear();
      expect(
        incomplete,
        IncompleteGeometry([
          GeometryIssue(GeometryGapKind.clusterMembership, 'fixture-declared'),
        ]),
      );
      expect(() => incomplete.issues.clear(), throwsUnsupportedError);
      final provisional = contractFragment(
        clusters: [
          contractCluster(provenance: ClusterProvenance.fixtureDeclared),
        ],
      );
      expect(
        SourceGeometry(
          version: 1,
          fragments: [provisional],
          completeness: incomplete,
        ).completeness,
        incomplete,
      );
      expect(
        () => SourceGeometry(
          version: 1,
          fragments: [provisional],
          completeness: const CompleteGeometry(),
        ),
        throwsArgumentError,
      );
      expect(
        () => SourceGeometry(
          version: 0,
          fragments: [],
          completeness: const CompleteGeometry(),
        ),
        throwsArgumentError,
      );
      expect(() => IncompleteGeometry([]), throwsArgumentError);
      expect(
        () => GeometryIssue(GeometryGapKind.mask, ''),
        throwsArgumentError,
      );
    },
  );
}
