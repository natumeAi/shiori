import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/geometry/affine_transform.dart';
import 'package:shiori/features/reader/data/geometry/cluster_geometry.dart';
import 'package:shiori/features/reader/data/geometry/paint_geometry.dart';
import 'package:shiori/features/reader/data/geometry/place_source_geometry.dart';
import 'package:shiori/features/reader/data/geometry/source_geometry.dart';

void main() {
  GeometryAlphaFootprint footprint(int value, bool uniform) => uniform
      ? GeometryAlphaFootprint.uniform(
          width: 8,
          height: 6,
          pixelSize: 1,
          origin: GeometryPoint(2, 3),
          alpha: value,
        )
      : GeometryAlphaFootprint(
          width: 8,
          height: 6,
          pixelSize: 1,
          origin: GeometryPoint(2, 3),
          alpha: List.filled(48, value),
        );

  test(
    'uniform samples equal explicit grids, including equality and hashes',
    () {
      for (final value in [0, 1, 32, 128, 254, 255]) {
        final uniform = footprint(value, true), grid = footprint(value, false);
        expect(uniform, grid);
        expect(uniform.hashCode, grid.hashCode);
        expect(uniform.alpha, orderedEquals(grid.alpha));
        expect(uniform.storageBytes, GeometryAlphaFootprint.storageOverhead);
        expect(grid.storageBytes, uniform.storageBytes + 48);
        expect(() => uniform.alpha[0] = 0, throwsUnsupportedError);
        expect(() => uniform.alpha.length = 0, throwsUnsupportedError);
        expect(() => uniform.alpha[-1], throwsRangeError);
        expect(() => uniform.alpha[48], throwsRangeError);
      }
      expect(
        () => GeometryAlphaFootprint.uniform(
          width: 0,
          height: 1,
          pixelSize: 1,
          origin: GeometryPoint(0, 0),
          alpha: 255,
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'placement, mask evidence, clips and opacity groups preserve both forms',
    () {
      final region = GeometryRegion(
        left: 2,
        top: 3,
        width: 8,
        height: 6,
        transform: const AffineTransform.identity(),
      );
      SourceGeometry geometry(bool uniform) {
        final mask = GeometryMask(
          id: 'mask',
          sourceNode: 2,
          units: GeometryMaskUnits.userSpaceOnUse,
          contentUnits: GeometryMaskUnits.objectBoundingBox,
          kind: GeometryMaskKind.alpha,
          region: region,
          coverage: footprint(128, uniform),
        );
        return SourceGeometry(
          version: 1,
          fragments: [],
          clips: [GeometryClip(id: 'clip', region: region)],
          opacityGroups: [
            GeometryOpacityGroup(id: 'outer', parentId: null, opacity: .7),
            GeometryOpacityGroup(id: 'inner', parentId: 'outer', opacity: .5),
          ],
          paint: [
            GeometryPaint(
              nodeIndex: 1,
              paintOrdinal: 1,
              region: region,
              kind: GeometryPaintKind.image,
              effectiveOpacity: .35,
              exactCoverage: true,
              clipIds: ['clip'],
              groupIds: ['outer', 'inner'],
              alphaFootprint: footprint(255, uniform).withMasks([mask]),
            ),
          ],
          completeness: const CompleteGeometry(),
        );
      }

      for (final transform in [
        AffineTransform(1, 0, 0, 1, 7, 9),
        AffineTransform(0, 2, -3, 0, 40, 5),
        AffineTransform(1, .3, -.2, 1, 5, -2),
      ]) {
        final original = geometry(true);
        final uniform = placeSourceGeometry(
          original,
          transform,
          registryPrefix: 'page:',
          paintOrdinalOffset: 4,
        );
        final grid = placeSourceGeometry(
          geometry(false),
          transform,
          registryPrefix: 'page:',
          paintOrdinalOffset: 4,
        );
        expect(uniform, grid);
        final f = uniform.paint.single.alphaFootprint!;
        expect(
          identical(f.alpha, original.paint.single.alphaFootprint!.alpha),
          true,
        );
        expect(f.uniformAlpha, 255);
        expect(f.masks.single.coverage.uniformAlpha, 128);
        expect(f.transform, transform);
        expect(uniform.paint.single.effectiveOpacity, .35);
        expect(uniform.clips.single.region.transform, transform);
        for (var y = 1; y < 12; y++) {
          for (var x = 0; x < 13; x++) {
            final localX = x + .5, localY = y + .5;
            final point = GeometryPoint(
              transform.a * localX + transform.c * localY + transform.e,
              transform.b * localX + transform.d * localY + transform.f,
            );
            final inside = x >= 2 && x < 10 && y >= 3 && y < 9;
            for (final paint in [uniform.paint.single, grid.paint.single]) {
              final coverage = paint.alphaFootprint!;
              final alpha = coverage.alphaAt(point)!;
              final maskAlpha = coverage.masks.single.coverage.alphaAt(point)!;
              expect(alpha, inside ? 255 : 0);
              expect(maskAlpha, inside ? 128 : 0);
              expect(
                alpha / 255 * maskAlpha / 255 * paint.effectiveOpacity,
                inside ? 128 / 255 * .35 : 0,
              );
            }
          }
        }
      }
    },
  );

  test('clipping samples trims both forms without resampling placed grids', () {
    final transform = AffineTransform(1, .3, -.2, 1, 7, 9);
    for (final hole in [false, true]) {
      var reserved = 0;
      int sample(int x, int y) =>
          x >= 2 && x < 6 && y >= 1 && y < 5 && (!hole || x != 3 || y != 2)
          ? 192
          : 0;
      final f = GeometryAlphaFootprint.fromSamples(
        width: 8,
        height: 6,
        origin: GeometryPoint(2, 3),
        pixelSize: .5,
        transform: transform,
        sample: sample,
        reserve: (bytes) => reserved = bytes,
      );
      expect(reserved, f.storageBytes);
      expect(f.width, 4);
      expect(f.height, 4);
      expect(f.uniformAlpha, hole ? isNull : 192);
      for (var y = 0; y < 6; y++) {
        for (var x = 0; x < 8; x++) {
          final gx = 2 + (x + .5) * .5, gy = 3 + (y + .5) * .5;
          expect(
            f.alphaAt(
              GeometryPoint(
                transform.a * gx + transform.c * gy + transform.e,
                transform.b * gx + transform.d * gy + transform.f,
              ),
            ),
            sample(x, y),
          );
        }
      }
    }
    expect(
      footprint(
        255,
        true,
      ).placed(AffineTransform(0, 0, 0, 0, 0, 0)).alphaAt(GeometryPoint(0, 0)),
      isNull,
    );
  });

  test('RGBA classification trims losslessly and reserves before payload allocation', () {
    List<int> rgba(List<int> alpha) => [
      for (final a in alpha) ...[0, 0, 0, a],
    ];
    for (final values in [
      [0, 0, 0, 0, 0, 255, 255, 0, 0, 255, 255, 0],
      [0, 0, 0, 0, 0, 255, 128, 0, 0, 32, 255, 0],
      List.filled(12, 0),
    ]) {
      var admitted = 0;
      final f = GeometryAlphaFootprint.fromRgba(
        width: 4,
        height: 3,
        rgba: rgba(values),
        origin: GeometryPoint(7, 9),
        reserve: (bytes) => admitted = bytes,
      );
      expect(admitted, f.storageBytes);
      for (var y = 0; y < 3; y++) {
        for (var x = 0; x < 4; x++) {
          final xx = x + 7 - f.origin.x.toInt(),
              yy = y + 9 - f.origin.y.toInt();
          final actual = xx >= 0 && xx < f.width && yy >= 0 && yy < f.height
              ? f.alpha[yy * f.width + xx]
              : 0;
          expect(actual, values[y * 4 + x]);
        }
      }
      expect(f.uniformAlpha != null, values[6] != 128);
    }
    expect(
      () => GeometryAlphaFootprint.fromRgba(
        width: 2,
        height: 1,
        rgba: rgba([255, 128]),
        origin: GeometryPoint(0, 0),
        reserve: (_) => throw StateError('refused'),
      ),
      throwsStateError,
    );
  });

  test('analytic eligibility never rounds fractional or rotated coverage', () {
    GeometryRegion region(AffineTransform t, {double left = 0}) =>
        GeometryRegion(left: left, top: 0, width: 8, height: 6, transform: t);
    expect(
      uniformPixelRectangle([region(const AffineTransform.identity())])!.width,
      8,
    );
    expect(
      uniformPixelRectangle([region(AffineTransform(0, 1, -1, 0, 8, 0))])!
          .width,
      6,
    );
    expect(
      uniformPixelRectangle([
        region(const AffineTransform.identity(), left: .5),
      ]),
      isNull,
    );
    expect(
      uniformPixelRectangle([region(AffineTransform(1, .1, 0, 1, 0, 0))]),
      isNull,
    );
    expect(
      uniformPixelRectangle([region(AffineTransform(0, 0, 0, 1, 0, 0))]),
      isNull,
    );
  });
}
