import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/geometry/cluster_geometry.dart';
import 'package:shiori/features/reader/data/geometry/paint_geometry.dart';
import 'package:shiori/features/reader/engine/fixed/svg/svg_graphics.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/pagination/preparation.dart';

ui.Picture _picture(int kind) {
  final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
  if (kind == 0) {
    canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 1357, 1259), ui.Paint());
  } else {
    canvas.translate(1023.25, 1023.5);
    canvas.rotate(.19);
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        const ui.Rect.fromLTWH(-900.5, -870.25, 1200.75, 1100.5),
        const ui.Radius.circular(17.25),
      ),
      ui.Paint()..color = const ui.Color(0x80334455),
    );
    if (kind == 2) {
      canvas.drawCircle(
        const ui.Offset(0, 0),
        71.75,
        ui.Paint()..blendMode = ui.BlendMode.clear,
      );
    }
  }
  return recorder.endRecording();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const width = 1357, height = 1259;
  test(
    'exact tile RGBA and footprints equal whole-raster rotated seam evidence',
    () async {
      for (final kind in [0, 1, 2]) {
        final picture = _picture(kind), budget = SceneResourceBudget();
        final whole = await picture.toImage(width, height);
        try {
          final rgba = (await whole.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          await AuthoredEvidenceRaster.visitTiles(
            whole,
            budget: budget,
            accept: (x, y, w, h, bytes) {
              for (var yy = 0; yy < h; yy++) {
                final offset = ((y + yy) * width + x) * 4;
                expect(
                  bytes.sublist(yy * w * 4, (yy + 1) * w * 4),
                  orderedEquals(rgba.sublist(offset, offset + w * 4)),
                );
              }
            },
          );
          final expected = GeometryAlphaFootprint.fromRgba(
            width: width,
            height: height,
            rgba: rgba,
            origin: GeometryPoint(0, 0),
            reserve: (_) {},
          );
          final previousCreate = ui.Image.onCreate,
              previousDispose = ui.Image.onDispose;
          var livePixels = 0, peakPixels = 0, largeImages = 0;
          ui.Image.onCreate = (image) {
            livePixels += image.width * image.height;
            if (livePixels > peakPixels) peakPixels = livePixels;
            if (image.width == width && image.height == height) largeImages++;
          };
          ui.Image.onDispose = (image) =>
              livePixels -= image.width * image.height;
          late GeometryAlphaFootprint actual;
          var reserved = 0;
          try {
            actual = await AuthoredEvidenceRaster.rasterize(
              picture,
              width: width,
              height: height,
              budget: budget,
              reserve: (bytes) => reserved += bytes,
            );
            expect(livePixels, 0);
            expect(largeImages, 1);
            expect(
              peakPixels,
              width * height + AuthoredEvidenceRaster.maxTilePixels,
            );
          } finally {
            ui.Image.onCreate = previousCreate;
            ui.Image.onDispose = previousDispose;
          }
          expect(actual, expected);
          expect(actual.hashCode, expected.hashCode);
          expect(actual.alpha, orderedEquals(expected.alpha));
          expect(reserved, expected.storageBytes);
          expect(
            budget.peaks[SceneResource.layerPixels],
            AuthoredEvidenceRaster.scratchPixels(width, height),
          );
          expect(budget.used.values.every((v) => v == 0), true);
        } finally {
          whole.dispose();
          picture.dispose();
        }
      }
    },
  );

  test(
    'complete peak refuses before allocation; cancel and payload refusal drain',
    () async {
      final picture = _picture(1);
      final previousCreate = ui.Image.onCreate,
          previousDispose = ui.Image.onDispose;
      var creates = 0, live = 0;
      ui.Image.onCreate = (_) {
        creates++;
        live++;
      };
      ui.Image.onDispose = (_) => live--;
      try {
        final refused = SceneResourceBudget(
          limits: {
            ...SceneResourceBudget.provisionalLimits,
            SceneResource.layerPixels:
                AuthoredEvidenceRaster.scratchPixels(width, height) - 1,
          },
        );
        await expectLater(
          AuthoredEvidenceRaster.rasterize(
            picture,
            width: width,
            height: height,
            budget: refused,
            reserve: (_) {},
          ),
          throwsA(isA<SceneAdmissionException>()),
        );
        expect(creates, 0);
        expect(refused.used.values.every((v) => v == 0), true);
        for (final cancel in [false, true]) {
          final budget = SceneResourceBudget();
          var checks = 0;
          await expectLater(
            AuthoredEvidenceRaster.rasterize(
              picture,
              width: width,
              height: height,
              budget: budget,
              reserve: (_) => throw StateError('retained payload refused'),
              checkCancellation: () {
                if (cancel && ++checks == 4) throw const PreparationCancelled();
              },
            ),
            cancel ? throwsA(isA<PreparationCancelled>()) : throwsStateError,
          );
          expect(live, 0);
          expect(budget.used.values.every((v) => v == 0), true);
        }
      } finally {
        ui.Image.onCreate = previousCreate;
        ui.Image.onDispose = previousDispose;
        picture.dispose();
      }
    },
  );

  test(
    'opacity is proven across decoded tiles including one nonopaque sample',
    () async {
      for (final alpha in [0, 1, 32, 128, 254, 255]) {
        final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
        canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 1025, 7), ui.Paint());
        canvas.drawRect(
          const ui.Rect.fromLTWH(512, 3, 1, 1),
          ui.Paint()
            ..color = ui.Color.fromARGB(alpha, 0, 0, 0)
            ..blendMode = ui.BlendMode.src,
        );
        final picture = recorder.endRecording(), budget = SceneResourceBudget();
        final image = await picture.toImage(1025, 7);
        try {
          expect(
            await AuthoredEvidenceRaster.isOpaque(image, budget: budget),
            alpha == 255,
          );
          expect(budget.used.values.every((v) => v == 0), true);
          expect(
            budget.peaks[SceneResource.layerPixels],
            AuthoredEvidenceRaster.tileSide * 7 * 2,
          );
        } finally {
          image.dispose();
          picture.dispose();
        }
      }
    },
  );
}
