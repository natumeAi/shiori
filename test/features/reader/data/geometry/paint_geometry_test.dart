import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/geometry/affine_transform.dart';
import 'package:shiori/features/reader/data/geometry/cluster_geometry.dart';
import 'package:shiori/features/reader/data/geometry/paint_geometry.dart';
import 'package:shiori/features/reader/data/geometry/source_geometry.dart';

import '../../contract_test_values.dart';

void main() {
  GeometryRegion region() => GeometryRegion(
    left: 0,
    top: 0,
    width: 10,
    height: 8,
    transform: const AffineTransform.identity(),
  );
  test('alpha evidence is copied, immutable and equal by value', () {
    final samples = [0, 128, 255, 0];
    final alpha = GeometryAlphaFootprint(
      width: 2,
      height: 2,
      pixelSize: 1,
      origin: GeometryPoint(0, 0),
      alpha: samples,
    );
    samples[0] = 255;
    final same = GeometryAlphaFootprint(
      width: 2,
      height: 2,
      pixelSize: 1,
      origin: GeometryPoint(0, 0),
      alpha: [0, 128, 255, 0],
    );
    expect(alpha, same);
    expect(alpha.hashCode, same.hashCode);
    expect(() => alpha.alpha[0] = 1, throwsUnsupportedError);
    expect(
      () => GeometryAlphaFootprint(
        width: 2,
        height: 2,
        pixelSize: 1,
        origin: GeometryPoint(0, 0),
        alpha: [0],
      ),
      throwsArgumentError,
    );
  });
  test(
    'complete geometry refuses missing clips, masks and alpha footprints',
    () {
      for (final fragment in [
        contractFragment(clipIds: ['missing']),
        contractFragment(maskIds: ['missing']),
      ]) {
        expect(
          () => SourceGeometry(
            version: 1,
            fragments: [fragment],
            completeness: const CompleteGeometry(),
          ),
          throwsArgumentError,
        );
      }
      final paint = GeometryPaint(
        nodeIndex: 1,
        paintOrdinal: 1,
        region: region(),
        kind: GeometryPaintKind.text,
        effectiveOpacity: 1,
        exactCoverage: true,
      );
      expect(
        () => SourceGeometry(
          version: 1,
          fragments: [],
          paint: [paint],
          completeness: const CompleteGeometry(),
        ),
        throwsArgumentError,
      );
    },
  );
  test(
    'clip registry, alpha and group hierarchy permit complete candidates',
    () {
      final alpha = GeometryAlphaFootprint(
        width: 1,
        height: 1,
        pixelSize: 1,
        origin: GeometryPoint(0, 0),
        alpha: [128],
      );
      final groups = [
        GeometryOpacityGroup(id: 'outer', parentId: null, opacity: .8),
        GeometryOpacityGroup(id: 'inner', parentId: 'outer', opacity: .5),
      ];
      final paint = GeometryPaint(
        nodeIndex: 1,
        paintOrdinal: 2,
        region: region(),
        kind: GeometryPaintKind.text,
        effectiveOpacity: .4,
        exactCoverage: true,
        clipIds: ['clip'],
        groupIds: ['outer', 'inner'],
        alphaFootprint: alpha,
      );
      final geometry = SourceGeometry(
        version: 1,
        fragments: [
          contractFragment(clipIds: ['clip']),
        ],
        clips: [GeometryClip(id: 'clip', region: region())],
        paint: [paint],
        opacityGroups: groups,
        completeness: const CompleteGeometry(),
      );
      expect(geometry.completeness, isA<CompleteGeometry>());
      expect(() => geometry.paint.clear(), throwsUnsupportedError);
      expect(() => geometry.opacityGroups.clear(), throwsUnsupportedError);
      expect(
        () => SourceGeometry(
          version: 1,
          fragments: [],
          opacityGroups: groups.reversed.toList(),
          completeness: const CompleteGeometry(),
        ),
        throwsArgumentError,
      );
    },
  );
}
