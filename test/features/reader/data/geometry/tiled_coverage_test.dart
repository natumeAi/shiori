import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/geometry/cluster_geometry.dart';
import 'package:shiori/features/reader/data/geometry/paint_geometry.dart';

void main() {
  test('tile stream equals whole grids for every storage form', () async {
    for (final value in [0, 1, 32, 128, 254, 255]) {
      for (final kind in ['uniform', 'trimmed', 'hole', 'varying']) {
        int sample(int x, int y) {
          if (kind != 'uniform' && (x == 0 || y == 0 || x == 6 || y == 4)) {
            return 0;
          }
          if (kind == 'hole' && x == 3 && y == 2) return 0;
          return kind == 'varying' ? (value + x * 13 + y * 29) % 256 : value;
        }

        final expected = GeometryAlphaFootprint.fromSamples(
          width: 7,
          height: 5,
          origin: GeometryPoint(10, 20),
          sample: sample,
          reserve: (_) {},
        );
        var passes = 0, reserved = 0;
        final actual = await GeometryAlphaFootprint.fromTiles(
          width: 7,
          height: 5,
          origin: GeometryPoint(10, 20),
          reserve: (bytes) => reserved += bytes,
          visitTiles: (accept) async {
            passes++;
            for (var y = 0; y < 5; y += 3) {
              for (var x = 0; x < 7; x += 3) {
                final w = math.min(3, 7 - x), h = math.min(3, 5 - y);
                final rgba = Uint8List(w * h * 4);
                for (var yy = 0; yy < h; yy++) {
                  for (var xx = 0; xx < w; xx++) {
                    rgba[(yy * w + xx) * 4 + 3] = sample(x + xx, y + yy);
                  }
                }
                accept(x, y, w, h, rgba);
              }
            }
          },
        );
        expect(actual, expected, reason: '$kind/$value');
        expect(actual.hashCode, expected.hashCode);
        expect(actual.alpha, orderedEquals(expected.alpha));
        expect(actual.uniformAlpha, expected.uniformAlpha);
        expect(reserved, expected.storageBytes);
        expect(passes, actual.uniformAlpha == null ? 2 : 1);
        expect(() => actual.alpha[0] = 9, throwsUnsupportedError);
      }
    }
  });

  test('payload refusal precedes allocation and second raster pass', () async {
    var passes = 0;
    await expectLater(
      GeometryAlphaFootprint.fromTiles(
        width: 2,
        height: 1,
        origin: GeometryPoint(0, 0),
        reserve: (_) => throw StateError('refused'),
        visitTiles: (accept) async {
          passes++;
          accept(0, 0, 2, 1, [0, 0, 0, 1, 0, 0, 0, 255]);
        },
      ),
      throwsStateError,
    );
    expect(passes, 1);
  });

  test(
    'missing, unordered and malformed tiles refuse before admission',
    () async {
      for (final (x, y, w, h, length) in [
        (1, 0, 1, 1, 4),
        (0, 1, 1, 1, 4),
        (0, 0, 3, 1, 12),
        (0, 0, 2, 1, 7),
        (0, 0, 1, 1, 4),
      ]) {
        await expectLater(
          GeometryAlphaFootprint.fromTiles(
            width: 2,
            height: 1,
            origin: GeometryPoint(0, 0),
            reserve: (_) => fail('invalid stream must not reserve'),
            visitTiles: (accept) async =>
                accept(x, y, w, h, List.filled(length, 0)),
          ),
          throwsArgumentError,
        );
      }
    },
  );
}
