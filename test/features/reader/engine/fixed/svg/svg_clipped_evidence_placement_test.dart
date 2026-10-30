import 'dart:math' as math;
import 'dart:typed_data';
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

Float64List _matrix(AffineTransform t) => Float64List.fromList([
  t.a,
  t.b,
  0,
  0,
  t.c,
  t.d,
  0,
  0,
  0,
  0,
  1,
  0,
  t.e,
  t.f,
  0,
  1,
]);

SvgGraphicsPlan _plan(
  String definition,
  String leaf,
  AffineTransform placement, {
  AuthoredPageSize? evidenceSize,
  GeometryPoint? evidenceOrigin,
}) {
  final document = const SourceParser().parse(
    '<html xmlns="http://www.w3.org/1999/xhtml"><body>'
    '<svg xmlns="http://www.w3.org/2000/svg" width="80" height="80">'
    '<defs>$definition</defs>$leaf</svg></body></html>',
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

String _leaf(String role, String effect) => role == 'image'
    ? '<image href="evidence.png" x="8" y="8" width="64" height="64" $effect/>'
    : '<rect x="8" y="8" width="64" height="64" '
          'fill="${role == 'stroke' ? 'none' : 'red'}" '
          'stroke="${role == 'fill' ? 'none' : 'blue'}" stroke-width="10" $effect/>';

Future<ui.Image> _sourceImage() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder)
    ..drawRect(
      const ui.Rect.fromLTWH(0, 0, 8, 8),
      ui.Paint()..color = const ui.Color(0x99ff0000),
    )
    ..drawRect(
      const ui.Rect.fromLTWH(2, 2, 4, 4),
      ui.Paint()..color = const ui.Color(0xffffffff),
    );
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(8, 8);
  } finally {
    picture.dispose();
  }
}

Future<void> _expectNative(
  GeometryAlphaFootprint footprint,
  AffineTransform placement,
  ui.Path clip,
  AffineTransform clipTransform,
  String role,
  ui.Image source, {
  ui.Rect extent = const ui.Rect.fromLTWH(0, 0, 240, 180),
}) async {
  final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
  canvas.translate(-extent.left, -extent.top);
  // One composed matrix, as the native clip tree composes host and clip.
  canvas.clipPath(clip.transform(_matrix(placement.compose(clipTransform))));
  // The native SVG root also clips to its 80x80 replaced viewport.
  canvas.clipPath(
    (ui.Path()..addRect(const ui.Rect.fromLTWH(0, 0, 80, 80))).transform(
      _matrix(placement),
    ),
  );
  canvas.transform(_matrix(placement));
  if (role == 'image') {
    // The native SVG image picture clips to its viewport rectangle first.
    canvas.clipRect(const ui.Rect.fromLTWH(8, 8, 64, 64));
    canvas.drawImageRect(
      source,
      const ui.Rect.fromLTWH(0, 0, 8, 8),
      const ui.Rect.fromLTWH(8, 8, 64, 64),
      ui.Paint(),
    );
  } else {
    canvas.drawRect(
      const ui.Rect.fromLTWH(8, 8, 64, 64),
      ui.Paint()
        ..color = const ui.Color(0xffff0000)
        ..style = role == 'stroke'
            ? ui.PaintingStyle.stroke
            : ui.PaintingStyle.fill
        ..strokeWidth = 10,
    );
  }
  final picture = recorder.endRecording();
  final native = await picture.toImage(
    extent.width.toInt(),
    extent.height.toInt(),
  );
  try {
    final rgba = (await native.toByteData(format: ui.ImageByteFormat.rawRgba))!
        .buffer
        .asUint8List();
    var painted = 0;
    for (var y = 0; y < native.height; y++) {
      for (var x = 0; x < native.width; x++) {
        final alpha = rgba[(y * native.width + x) * 4 + 3];
        if (alpha > 0) painted++;
        expect(
          footprint.alphaAt(
            GeometryPoint(extent.left + x + .5, extent.top + y + .5),
          ),
          alpha,
          reason:
              '$role native alpha at (${extent.left + x},${extent.top + y})',
        );
      }
    }
    expect(painted, greaterThan(0));
  } finally {
    native.dispose();
    picture.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final integer = AffineTransform(1, 0, 0, 1, 100, 12);
  final fractional = AffineTransform(1, 0, 0, 1, 100.25, 12.75);
  final transformed = AffineTransform(1.2, .2, -.3, .9, 100.25, 12.75);
  final rectangle = ui.Path()
    ..addRect(const ui.Rect.fromLTWH(10.25, 8.5, 60, 65));
  final angle = 17 * math.pi / 180;
  final rotation = AffineTransform(
    math.cos(angle),
    math.sin(angle),
    -math.sin(angle),
    math.cos(angle),
    20,
    0,
  );
  final clips = [
    (
      'rectangle',
      '<rect x="10.25" y="8.5" width="60" height="65"/>',
      rectangle,
      const AffineTransform.identity(),
    ),
    (
      'rotated',
      '<rect x="10.25" y="8.5" width="60" height="65" transform="translate(20 0) rotate(17)"/>',
      rectangle,
      rotation,
    ),
    (
      'path',
      '<path d="M10.25 8.5 C85 2 95 70 20 73 Z"/>',
      ui.Path()
        ..moveTo(10.25, 8.5)
        ..cubicTo(85, 2, 95, 70, 20, 73)
        ..close(),
      const AffineTransform.identity(),
    ),
  ];
  for (final (host, placement, extent) in [
    (
      'origin',
      const AffineTransform.identity(),
      const ui.Rect.fromLTWH(0, 0, 80, 80),
    ),
    ('integer', integer, const ui.Rect.fromLTWH(0, 0, 180, 92)),
    ('fractional', fractional, const ui.Rect.fromLTWH(0, 0, 181, 93)),
    ('transformed', transformed, const ui.Rect.fromLTWH(0, 0, 197, 101)),
  ]) {
    for (final (kind, definition, path, clipTransform) in clips) {
      for (final role in ['fill', 'stroke', 'image']) {
        test('placed clipped $kind $role under $host host', () async {
          final source = await _sourceImage(), budget = SceneResourceBudget();
          final plan = _plan(
            '<clipPath id="c">$definition</clipPath>',
            _leaf(role, 'clip-path="url(#c)"'),
            placement,
          );
          final scene = await plan.prepare(
            budget: budget,
            images: SvgGraphicsImages(rasters: {'evidence.png': source}),
          );
          try {
            expect(scene.capability, isA<CompleteSectionCapability>());
            expect(scene.geometry.completeness, isA<CompleteGeometry>());
            final paint = scene.geometry.paint.single;
            expect(paint.exactCoverage, true);
            await _expectNative(
              paint.alphaFootprint!,
              placement,
              path,
              clipTransform,
              role,
              source,
              extent: extent,
            );
          } finally {
            scene.dispose();
            source.dispose();
          }
          expect(budget.used.values.every((v) => v == 0), true);
        });
      }
    }
  }
  final mixed =
      '<rect x="8" y="8" width="64" height="64" fill="red" stroke="blue" '
      'stroke-width="10" clip-path="url(#c)"/>';
  const rotatedClip =
      '<clipPath id="c"><rect x="10.25" y="8.5" width="60" height="65" '
      'transform="translate(20 0) rotate(17)"/></clipPath>';
  for (final (host, placement, width, height) in [
    ('integer', integer, 180, 92),
    ('fractional', fractional, 181, 93),
    ('transformed', transformed, 197, 101),
  ]) {
    test(
      'clipped $host evidence reserves, allocates and releases the placed raster',
      () async {
        final plan = _plan(rotatedClip, mixed, placement);
        final request = plan.reservation(), budget = SceneResourceBudget();
        var created = 0, disposed = 0, live = 0, peak = 0;
        final sizes = <ui.Image, int>{};
        final authored = <ui.Size>[], others = <int>[];
        final previousCreate = ui.Image.onCreate,
            previousDispose = ui.Image.onDispose;
        ui.Image.onCreate = (image) {
          previousCreate?.call(image);
          created++;
          sizes[image] = image.width * image.height;
          live += sizes[image]!;
          peak = math.max(peak, live);
          if (image.width == width && image.height == height) {
            authored.add(
              ui.Size(image.width.toDouble(), image.height.toDouble()),
            );
          } else {
            others.add(image.width * image.height);
          }
        };
        ui.Image.onDispose = (image) {
          previousDispose?.call(image);
          disposed++;
          live -= sizes.remove(image)!;
        };
        SvgGraphicsScene? scene;
        try {
          scene = await plan.prepare(budget: budget);
          expect(scene.capability, isA<CompleteSectionCapability>());
          expect(
            plan.evidencePixels,
            AuthoredEvidenceRaster.scratchPixels(width, height),
          );
          // Evidence is the placed raster plus tile and readback; the rest is
          // the two 80x80 display layers, independent of the host placement.
          final display = 2 * plan.displayPixels;
          expect(
            request[SceneResource.layerPixels],
            plan.evidencePixels + display,
          );
          expect(
            request[SceneResource.layerBytes],
            (plan.evidencePixels + display) * 4,
          );
          expect(
            budget.used[SceneResource.layerPixels],
            request[SceneResource.layerPixels],
          );
          // Unclipped and clipped fill/stroke replays each rasterize the whole
          // placed extent (never the local SVG viewport) with one tile copy.
          expect(authored.length, greaterThanOrEqualTo(8));
          expect(others.every((s) => s == 1), true);
          expect(created, disposed);
          expect(live, 0);
          expect(peak, 2 * width * height);
          expect(
            budget.peaks[SceneResource.layerPixels]!,
            lessThanOrEqualTo(request[SceneResource.layerPixels]!),
          );
        } finally {
          ui.Image.onCreate = previousCreate;
          ui.Image.onDispose = previousDispose;
          scene?.dispose();
        }
        expect(budget.used.values.every((v) => v == 0), true);
      },
    );
    test(
      'clipped $host evidence refuses one pixel short before allocation',
      () async {
        final plan = _plan(rotatedClip, mixed, placement);
        final request = plan.reservation();
        final budget = SceneResourceBudget(
          limits: {
            ...SceneResourceBudget.provisionalLimits,
            SceneResource.layerPixels: request[SceneResource.layerPixels]! - 1,
          },
        );
        var images = 0;
        final previous = ui.Image.onCreate;
        ui.Image.onCreate = (image) {
          previous?.call(image);
          images++;
        };
        try {
          final scene = await plan.prepare(budget: budget);
          expect(scene.capability, isA<ResourceSectionCapability>());
          expect(scene.picture, isNull);
          expect(scene.geometry.paint, isEmpty);
          scene.dispose();
          expect(images, 0);
        } finally {
          ui.Image.onCreate = previous;
        }
        expect(budget.used.values.every((v) => v == 0), true);
      },
    );
    test('masked $host evidence keeps the placed mask coverage', () async {
      final plan = _plan(
        '<mask id="m" mask-type="alpha" maskUnits="userSpaceOnUse" '
            'x="10.25" y="8.5" width="60" height="65">'
            '<rect width="80" height="80" fill="black"/></mask>',
        '<rect x="8" y="8" width="64" height="64" fill="red" mask="url(#m)"/>',
        placement,
      );
      final budget = SceneResourceBudget();
      final scene = await plan.prepare(budget: budget);
      try {
        expect(scene.capability, isA<CompleteSectionCapability>());
        final coverage =
            scene.geometry.paint.single.alphaFootprint!.masks.single.coverage;
        final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
        canvas.clipPath(
          (ui.Path()..addRect(const ui.Rect.fromLTWH(10.25, 8.5, 60, 65)))
              .transform(_matrix(placement)),
        );
        canvas.transform(_matrix(placement));
        canvas.drawRect(
          const ui.Rect.fromLTWH(0, 0, 80, 80),
          ui.Paint()..color = const ui.Color(0xff000000),
        );
        final picture = recorder.endRecording();
        final native = await picture.toImage(width, height);
        try {
          final rgba = (await native.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          var painted = 0;
          for (var y = 0; y < height; y++) {
            for (var x = 0; x < width; x++) {
              final alpha = rgba[(y * width + x) * 4 + 3];
              if (alpha > 0) painted++;
              expect(
                coverage.alphaAt(GeometryPoint(x + .5, y + .5)),
                alpha,
                reason: 'mask alpha at ($x,$y)',
              );
            }
          }
          expect(painted, greaterThan(0));
        } finally {
          native.dispose();
          picture.dispose();
        }
      } finally {
        scene.dispose();
      }
      expect(budget.used.values.every((v) => v == 0), true);
    });
  }
  test('prepare-time placement uses its admitted effective extent', () async {
    final source = await _sourceImage(), budget = SceneResourceBudget();
    final plan = _plan(rotatedClip, mixed, const AffineTransform.identity());
    final scene = await plan.prepare(budget: budget, placement: transformed);
    try {
      expect(scene.geometry.completeness, isA<CompleteGeometry>());
    } finally {
      scene.dispose();
      source.dispose();
    }
    expect(budget.used.values.every((v) => v == 0), true);
  });
  for (final mask in [false, true]) {
    test(
      '${mask ? 'mask' : 'clip'} equal-area override retains the new origin',
      () async {
        final source = await _sourceImage(), budget = SceneResourceBudget();
        final planned = AffineTransform(1, 0, 0, 1, 100, 0);
        final effective = AffineTransform(1, 0, 0, 1, -100, 0);
        final plan = _plan(
          mask
              ? '<mask id="m" mask-type="alpha" maskUnits="userSpaceOnUse" '
                    'x="10" y="10" width="60" height="60">'
                    '<rect width="80" height="80" fill="white"/></mask>'
              : '<clipPath id="c"><rect x="10" y="10" width="60" height="60"/></clipPath>',
          _leaf('fill', mask ? 'mask="url(#m)"' : 'clip-path="url(#c)"'),
          planned,
        );
        expect(
          plan.reservation()[SceneResource.layerPixels],
          plan.reservation(placement: effective)[SceneResource.layerPixels],
        );
        final scene = await plan.prepare(budget: budget, placement: effective);
        try {
          expect(scene.capability, isA<CompleteSectionCapability>());
          expect(scene.geometry.completeness, isA<CompleteGeometry>());
          final footprint = scene.geometry.paint.single.alphaFootprint!;
          if (mask) {
            final coverage = footprint.masks.single.coverage;
            expect(coverage.alphaAt(GeometryPoint(-80, 20)), 255);
            expect(coverage.alphaAt(GeometryPoint(20, 20)), 0);
            expect(footprint.alphaAt(GeometryPoint(-80, 20)), 255);
            expect(footprint.alphaAt(GeometryPoint(-95, 20)), 0);
          } else {
            await _expectNative(
              footprint,
              effective,
              ui.Path()..addRect(const ui.Rect.fromLTWH(10, 10, 60, 60)),
              const AffineTransform.identity(),
              'fill',
              source,
              extent: const ui.Rect.fromLTWH(-100, 0, 180, 80),
            );
          }
        } finally {
          scene.dispose();
          source.dispose();
        }
        expect(budget.used.values.every((v) => v == 0), true);
      },
    );
  }
}
