import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/geometry/affine_transform.dart';
import 'package:shiori/features/reader/data/geometry/cluster_geometry.dart';
import 'package:shiori/features/reader/data/geometry/paint_geometry.dart';
import 'package:shiori/features/reader/data/geometry/source_geometry.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/source/source_parser.dart';
import 'package:shiori/features/reader/engine/fixed/svg/svg_graphics.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/support/section_capability.dart';

import '../../../contract_test_values.dart';

SvgGraphicsPlan _plan(
  String leaf,
  AffineTransform placement, {
  AuthoredPageSize? evidenceSize,
  GeometryPoint? evidenceOrigin,
}) {
  final document = const SourceParser().parse(
    '<html xmlns="http://www.w3.org/1999/xhtml"><body>'
    '<svg xmlns="http://www.w3.org/2000/svg" width="80" height="80">'
    '$leaf</svg></body></html>',
    mediaType: 'application/xhtml+xml',
  );
  return SvgGraphicsPlan.inspect(
    document: document,
    rootIndex: document.nodes.singleWhere((n) => n.localName == 'svg').index,
    page: contractPage(),
    size: AuthoredPageSize(80, 80),
    placement: placement,
    evidenceSize: evidenceSize,
    evidenceOrigin: evidenceOrigin,
  );
}

Future<void> _expectNative(
  GeometryAlphaFootprint footprint,
  SvgGraphicsScene control,
) async {
  final image = await control.picture!.toImage(240, 180);
  try {
    final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
        .buffer
        .asUint8List();
    var painted = 0;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final alpha = rgba[(y * image.width + x) * 4 + 3];
        expect(
          footprint.alphaAt(GeometryPoint(x + .5, y + .5)),
          alpha,
          reason: 'native alpha at ($x,$y)',
        );
        if (alpha > 0) painted++;
      }
    }
    expect(painted, greaterThan(0));
  } finally {
    image.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final placements = {
    'integer': AffineTransform(1, 0, 0, 1, 100, 12),
    'fractional': AffineTransform(1, 0, 0, 1, 100.25, 12.75),
    'transformed host': AffineTransform(1.2, .2, -.3, .9, 100.25, 12.75),
  };
  for (final entry in placements.entries) {
    test(
      '${entry.key} reservation matches the native evidence raster',
      () async {
        final plan = _plan('<path d="M0 0H80V80H0Z"/>', entry.value);
        final dimensions = <ui.Size>[];
        final oldOnCreate = ui.Image.onCreate;
        ui.Image.onCreate = (image) {
          dimensions.add(
            ui.Size(image.width.toDouble(), image.height.toDouble()),
          );
          oldOnCreate?.call(image);
        };
        final budget = SceneResourceBudget();
        SvgGraphicsScene? scene;
        try {
          final request = plan.reservation();
          scene = await plan.prepare(budget: budget);
          expect(scene.capability.isComplete, true);
          final raster = dimensions.first;
          expect(
            plan.evidencePixels,
            AuthoredEvidenceRaster.scratchPixels(
              raster.width.toInt(),
              raster.height.toInt(),
            ),
          );
          expect(request[SceneResource.layerPixels], plan.evidencePixels);
          expect(request[SceneResource.layerBytes], plan.evidencePixels * 4);
          expect(
            request[SceneResource.vectorBytes]! -
                plan.resources[SceneResource.vectorBytes]! -
                2 * 1024 * 1024,
            raster.width.toInt() * raster.height.toInt() +
                GeometryAlphaFootprint.storageOverhead,
          );
          expect(
            budget.used[SceneResource.layerPixels],
            request[SceneResource.layerPixels],
          );
          await _expectNative(
            scene.geometry.paint.single.alphaFootprint!,
            scene,
          );
        } finally {
          scene?.dispose();
          ui.Image.onCreate = oldOnCreate;
        }
        expect(budget.used.values.every((v) => v == 0), true);
      },
    );
    for (final leaf in [
      '<rect width="80" height="80" fill="red"/>',
      '<path d="M0 0H80V80H0Z" fill="red"/>',
      '<rect x="4" y="4" width="72" height="72" fill="none" '
          'stroke="blue" stroke-width="10"/>',
      '<image href="test.png" width="80" height="80"/>',
    ]) {
      test(
        '${entry.key} ${leaf.split(' ').first} evidence equals native',
        () async {
          final recorder = ui.PictureRecorder();
          ui.Canvas(recorder).drawRect(
            const ui.Rect.fromLTWH(0, 0, 8, 8),
            ui.Paint()..color = const ui.Color(0x99ff0000),
          );
          final picture = recorder.endRecording();
          final raster = await picture.toImage(8, 8);
          picture.dispose();
          final budget = SceneResourceBudget();
          final scene = await _plan(leaf, entry.value).prepare(
            budget: budget,
            images: SvgGraphicsImages(rasters: {'test.png': raster}),
          );
          try {
            expect(scene.capability.isComplete, true);
            expect(scene.geometry.completeness, isA<CompleteGeometry>());
            final paint = scene.geometry.paint.single;
            expect(paint.exactCoverage, true);
            await _expectNative(paint.alphaFootprint!, scene);
            if (entry.key == 'integer' && leaf.startsWith('<rect width')) {
              expect(paint.alphaFootprint!.uniformAlpha, 255);
              expect(
                paint.alphaFootprint!.alphaAt(GeometryPoint(110.5, 20.5)),
                255,
              );
            }
          } finally {
            scene.dispose();
            raster.dispose();
          }
          expect(budget.used.values.every((v) => v == 0), true);
        },
      );
    }
    test('${entry.key} each placed role equals its native control', () async {
      String leaf(String fill, String stroke) =>
          '<rect x="10" y="10" width="60" height="60" fill="$fill" '
          'stroke="$stroke" stroke-width="9" stroke-dasharray="10 14"/>';
      final budget = SceneResourceBudget();
      final scene = await _plan(
        leaf('red', 'blue'),
        entry.value,
      ).prepare(budget: budget);
      try {
        expect(scene.capability.isComplete, true);
        expect(scene.geometry.paint.map((p) => p.role), [
          GeometryPaintRole.fill,
          GeometryPaintRole.stroke,
        ]);
        for (final paint in scene.geometry.paint) {
          final fill = paint.role == GeometryPaintRole.fill;
          final controlBudget = SceneResourceBudget();
          final control = await _plan(
            leaf(fill ? 'red' : 'none', fill ? 'none' : 'blue'),
            entry.value,
          ).prepare(budget: controlBudget);
          try {
            expect(control.capability.isComplete, true);
            await _expectNative(paint.alphaFootprint!, control);
          } finally {
            control.dispose();
          }
          expect(controlBudget.used.values.every((v) => v == 0), true);
        }
      } finally {
        scene.dispose();
      }
      expect(budget.used.values.every((v) => v == 0), true);
    });
  }
  test(
    'inline host placement supplied at preparation retains native alpha',
    () async {
      final budget = SceneResourceBudget();
      final scene = await _plan(
        '<path d="M0 0H80V80H0Z"/>',
        const AffineTransform.identity(),
      ).prepare(budget: budget, placement: placements['transformed host']);
      try {
        expect(scene.capability.isComplete, true);
        await _expectNative(scene.geometry.paint.single.alphaFootprint!, scene);
      } finally {
        scene.dispose();
      }
      expect(budget.used.values.every((v) => v == 0), true);
    },
  );
  test(
    'effective placement refuses one pixel short before native allocation',
    () async {
      final plan = _plan(
        '<path d="M0 0H80V80H0Z"/>',
        const AffineTransform.identity(),
      );
      final placement = placements['transformed host']!;
      final request = plan.reservation(placement: placement);
      expect(
        request[SceneResource.layerPixels],
        greaterThan(plan.evidencePixels),
      );
      final budget = SceneResourceBudget(
        limits: {
          ...SceneResourceBudget.provisionalLimits,
          SceneResource.layerPixels: request[SceneResource.layerPixels]! - 1,
        },
      );
      final oldOnCreate = ui.Image.onCreate;
      var images = 0;
      ui.Image.onCreate = (image) {
        images++;
        oldOnCreate?.call(image);
      };
      try {
        final scene = await plan.prepare(budget: budget, placement: placement);
        try {
          expect(scene.capability, isA<ResourceSectionCapability>());
          expect(scene.picture, isNull);
          expect(scene.geometry.paint, isEmpty);
          expect(images, 0);
        } finally {
          scene.dispose();
        }
      } finally {
        ui.Image.onCreate = oldOnCreate;
      }
      expect(budget.used.values.every((v) => v == 0), true);
    },
  );
  test(
    'explicit enclosing origin preserves the root-coordinate pixel grid',
    () async {
      final plan = _plan(
        '<path d="M0 0H80V80H0Z"/>',
        placements['transformed host']!,
        evidenceSize: AuthoredPageSize(200, 150),
        evidenceOrigin: GeometryPoint(20, 10),
      );
      final budget = SceneResourceBudget();
      final scene = await plan.prepare(budget: budget);
      try {
        expect(scene.capability.isComplete, true);
        expect(
          plan.evidencePixels,
          AuthoredEvidenceRaster.scratchPixels(200, 150),
        );
        await _expectNative(scene.geometry.paint.single.alphaFootprint!, scene);
      } finally {
        scene.dispose();
      }
      expect(budget.used.values.every((v) => v == 0), true);
    },
  );
}
