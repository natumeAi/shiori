import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/geometry/affine_transform.dart';
import 'package:shiori/features/reader/data/geometry/cluster_geometry.dart';
import 'package:shiori/features/reader/data/geometry/paint_geometry.dart';
import 'package:shiori/features/reader/data/geometry/place_source_geometry.dart';
import 'package:shiori/features/reader/data/geometry/source_geometry.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/source/source_parser.dart';
import 'package:shiori/features/reader/data/worker/publication_cancellation.dart';
import 'package:shiori/features/reader/engine/fixed/svg/svg_graphics.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/pagination/preparation.dart';
import 'package:shiori/features/reader/engine/support/section_capability.dart';

import '../../../../../../tool/reader/fixed_layout_scene_input.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final corpus = jsonDecode(
    File('test/fixtures/reader/fixed_layout/corpus.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final fixture = (corpus['cases'] as List).cast<Map<String, Object?>>().first;
  final input = SceneHarnessInput(
    fixture,
    corpus,
    File((corpus['font'] as Map)['path'] as String).readAsBytesSync(),
  );
  tearDownAll(input.book.archive.close);

  SvgGraphicsPlan plan(
    String markup, {
    Map<String, String> css = const {},
    int width = 100,
    int height = 100,
  }) {
    final document = const SourceParser().parse(
      '<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$height">$markup</svg>',
      mediaType: 'image/svg+xml',
    );
    final presentation = <int, Map<String, String>>{};
    for (final node in document.nodes) {
      if (node.attribute('style') != null) {
        presentation[node.index] = node.id == 'r' ? css : const {};
      }
    }
    return SvgGraphicsPlan.inspect(
      document: document,
      rootIndex: document.documentElementIndex,
      page: input.page,
      size: AuthoredPageSize(width.toDouble(), height.toDouble()),
      resolvedPresentation: presentation,
    );
  }

  Future<ui.Image> image(SvgGraphicsScene scene) =>
      scene.picture!.toImage(100, 100);

  Future<List<int>> pixel(ui.Image image, int x, int y) async {
    final bytes = (await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    ))!.buffer.asUint8List();
    final offset = (y * 100 + x) * 4;
    return bytes.sublist(offset, offset + 4);
  }

  for (final kind in [
    'integer',
    'fractional',
    'rotated',
    'path',
    'nested',
    'use',
    'group',
    'roles',
    'coincident',
    'ancestors',
  ]) {
    test('exact clipped native alpha: $kind', () async {
      final rect = ui.Path()
        ..addRect(const ui.Rect.fromLTWH(10.25, 8.5, 60, 70));
      final paths = <ui.Path>[rect];
      var definition = '<rect x="10.25" y="8.5" width="60" height="70"/>';
      var nested = '';
      if (kind == 'integer') {
        paths[0] = ui.Path()..addRect(const ui.Rect.fromLTWH(10, 8, 60, 70));
        definition = '<rect x="10" y="8" width="60" height="70"/>';
      } else if (kind == 'rotated') {
        final angle = 17 * math.pi / 180;
        final c = math.cos(angle), s = math.sin(angle);
        paths[0] = rect.transform(
          Float64List.fromList([
            c,
            s,
            0,
            0,
            -s,
            c,
            0,
            0,
            0,
            0,
            1,
            0,
            20,
            0,
            0,
            1,
          ]),
        );
        definition =
            '<rect x="10.25" y="8.5" width="60" height="70" '
            'transform="translate(20 0) rotate(17)"/>';
      } else if (kind == 'path') {
        paths[0] = ui.Path()
          ..moveTo(10.25, 8.5)
          ..cubicTo(85, 2, 95, 90, 20, 80)
          ..close();
        definition = '<path d="M10.25 8.5 C85 2 95 90 20 80 Z"/>';
      } else if (kind == 'nested' || kind == 'ancestors') {
        paths.insert(
          0,
          ui.Path()..addOval(const ui.Rect.fromLTWH(5.5, 4.25, 78, 80)),
        );
        if (kind == 'nested') nested = ' clip-path="url(#outer)"';
      }
      var leaf =
          '<rect id="target" x="5" y="5" width="80" height="80" '
          'fill="red"${kind == 'roles' ? ' stroke="blue" stroke-width="12"' : ''}/>';
      if (kind == 'coincident') {
        leaf = '<rect x="10.25" y="8.5" width="60" height="70" fill="red"/>';
      }
      final owner = kind == 'use'
          ? '<use href="#target" clip-path="url(#c)"/>'
          : kind == 'ancestors'
          ? '<g clip-path="url(#outer)"><g clip-path="url(#c)">$leaf</g></g>'
          : kind == 'group'
          ? '<g clip-path="url(#c)">$leaf</g>'
          : leaf.replaceFirst('/>', ' clip-path="url(#c)"/>');
      final p = plan(
        '<defs><clipPath id="outer"><ellipse cx="44.5" cy="44.25" '
        'rx="39" ry="40"/></clipPath><clipPath id="c"$nested>$definition</clipPath>'
        '${kind == 'use' ? leaf : ''}</defs>$owner',
      );
      final budget = SceneResourceBudget();
      final scene = await p.prepare(budget: budget);
      try {
        expect(scene.capability, isA<CompleteSectionCapability>());
        expect(scene.geometry.completeness, isA<CompleteGeometry>());
        expect(scene.geometry.paint, hasLength(kind == 'roles' ? 2 : 1));
        for (final paint in scene.geometry.paint) {
          expect(paint.exactCoverage, true);
          final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
          for (final path in paths) {
            canvas.clipPath(path);
          }
          canvas.drawRect(
            kind == 'coincident'
                ? const ui.Rect.fromLTWH(10.25, 8.5, 60, 70)
                : const ui.Rect.fromLTWH(5, 5, 80, 80),
            ui.Paint()
              ..color = const ui.Color(0xffff0000)
              ..style = paint.role == GeometryPaintRole.stroke
                  ? ui.PaintingStyle.stroke
                  : ui.PaintingStyle.fill
              ..strokeWidth = 12,
          );
          final picture = recorder.endRecording();
          final native = await picture.toImage(100, 100);
          try {
            final rgba = (await native.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!.buffer.asUint8List();
            final footprint = paint.alphaFootprint!;
            var partial = false;
            for (var y = 0; y < 100; y++) {
              for (var x = 0; x < 100; x++) {
                final alpha = rgba[(y * 100 + x) * 4 + 3];
                partial |= alpha > 0 && alpha < 255;
                expect(
                  footprint.alphaAt(GeometryPoint(x + .5, y + .5)),
                  alpha,
                  reason: '$kind ${paint.role} ($x,$y)',
                );
              }
            }
            if (kind != 'integer') {
              expect(partial, true);
              expect(footprint.uniformAlpha, isNull);
            }
            if (kind == 'fractional') {
              expect(rgba[(20 * 100 + 10) * 4 + 3], 191);
            }
            if (footprint.uniformAlpha != null) {
              expect(
                footprint.alpha.every((a) => a == footprint.uniformAlpha),
                true,
              );
            }
            if (kind == 'integer') expect(footprint.uniformAlpha, 255);
          } finally {
            native.dispose();
            picture.dispose();
          }
        }
      } finally {
        scene.dispose();
      }
      expect(budget.used.values.every((v) => v == 0), true);
    });
  }

  test('clipped whole raster equals independent AA across exact tile seams', () async {
    const width = 1103, height = 769;
    final p = plan(
      '<clipPath id="c"><rect x="-300" y="-220" width="600" '
      'height="440" transform="translate(530.25 390.5) rotate(13)"/></clipPath>'
      '<rect width="1103" height="769" clip-path="url(#c)"/>',
      width: width,
      height: height,
    );
    var authored = 0, live = 0, peak = 0;
    final created = <ui.Image, int>{};
    final previousCreate = ui.Image.onCreate,
        previousDispose = ui.Image.onDispose;
    ui.Image.onCreate = (image) {
      previousCreate?.call(image);
      if (image.width == width && image.height == height) authored++;
      created[image] = image.width * image.height;
      live += created[image]!;
      peak = math.max(peak, live);
    };
    ui.Image.onDispose = (image) {
      previousDispose?.call(image);
      live -= created.remove(image)!;
    };
    final budget = SceneResourceBudget();
    late SvgGraphicsScene scene;
    try {
      scene = await p.prepare(budget: budget);
      expect(authored, 1);
      expect(live, 0);
      expect(peak, width * height + 512 * 512);
      expect(
        budget.peaks[SceneResource.layerPixels],
        p.reservation()[SceneResource.layerPixels],
      );
    } finally {
      ui.Image.onCreate = previousCreate;
      ui.Image.onDispose = previousDispose;
    }
    final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
    final angle = 13 * math.pi / 180, c = math.cos(angle), s = math.sin(angle);
    final path =
        (ui.Path()..addRect(const ui.Rect.fromLTWH(-300, -220, 600, 440)))
            .transform(
              Float64List.fromList([
                c,
                s,
                0,
                0,
                -s,
                c,
                0,
                0,
                0,
                0,
                1,
                0,
                530.25,
                390.5,
                0,
                1,
              ]),
            );
    canvas.clipPath(path);
    canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 1103, 769), ui.Paint());
    final picture = recorder.endRecording();
    final native = await picture.toImage(width, height);
    try {
      final rgba = (await native.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      expect(scene.geometry.completeness, isA<CompleteGeometry>());
      final expected = GeometryAlphaFootprint.fromRgba(
        width: width,
        height: height,
        rgba: rgba,
        origin: GeometryPoint(0, 0),
        reserve: (_) {},
      );
      expect(scene.geometry.paint.single.alphaFootprint, expected);
    } finally {
      native.dispose();
      picture.dispose();
      scene.dispose();
    }
    expect(budget.used.values.every((v) => v == 0), true);
  });

  test('clipped peak refuses before native allocation', () async {
    final p = plan(
      '<clipPath id="c"><rect x="10.25" width="60" height="100"/></clipPath>'
      '<rect width="100" height="100" clip-path="url(#c)"/>',
    );
    var allocated = 0;
    final previous = ui.Image.onCreate;
    ui.Image.onCreate = (_) => allocated++;
    try {
      for (final resource in [
        SceneResource.layerPixels,
        SceneResource.layerBytes,
        SceneResource.vectorBytes,
      ]) {
        final budget = SceneResourceBudget(
          limits: {
            ...SceneResourceBudget.provisionalLimits,
            resource: p.reservation()[resource]! - 1,
          },
        );
        final scene = await p.prepare(budget: budget);
        expect(scene.capability, isA<ResourceSectionCapability>());
        expect(scene.picture, isNull);
        scene.dispose();
        expect(allocated, 0);
        expect(budget.used.values.every((v) => v == 0), true);
      }
    } finally {
      ui.Image.onCreate = previous;
    }
  });

  test(
    'clipped raster and exact tiles release on cancellation and late failure',
    () async {
      for (final cancelAt in [1, 2, 4, 0]) {
        final p = plan(
          '<clipPath id="c"><rect x="10.25" width="1000" height="769"/></clipPath>'
          '<rect width="1103" height="769" clip-path="url(#c)"/>',
          width: 1103,
          height: 769,
        );
        final budget = SceneResourceBudget(), token = PublicationCancellation();
        final created = <ui.Image>[], disposed = <ui.Image>[];
        var clipping = false, clippedCount = 0, livePixels = 0, peakPixels = 0;
        final previousCreate = ui.Image.onCreate,
            previousDispose = ui.Image.onDispose;
        final sizes = <ui.Image, int>{};
        ui.Image.onCreate = (image) {
          previousCreate?.call(image);
          created.add(image);
          final pixels = image.width * image.height;
          sizes[image] = pixels;
          livePixels += pixels;
          peakPixels = math.max(peakPixels, livePixels);
          if (image.width == 1103 && image.height == 769) clipping = true;
          if (clipping && ++clippedCount == cancelAt) token.cancel();
        };
        ui.Image.onDispose = (image) {
          previousDispose?.call(image);
          disposed.add(image);
          livePixels -= sizes.remove(image)!;
        };
        try {
          final future = p.prepare(
            budget: budget,
            cancellation: token,
            features: SvgFeatureRegistry([
              const SvgClipMaskFeature(),
              if (cancelAt == 0) const _FailAfterClipFeature(),
            ]),
          );
          if (cancelAt > 0) {
            await expectLater(future, throwsA(isA<PreparationCancelled>()));
            expect(clippedCount, cancelAt);
          } else {
            final scene = await future;
            expect(scene.capability, isA<UnsupportedSectionCapability>());
            expect(
              scene.capability.constructs.single.identifier,
              'test-clip-late',
            );
            expect(scene.picture, isNull);
            scene.dispose();
            scene.dispose();
            expect(
              clippedCount,
              13,
            ); // One raster, six exact tiles, two visits.
          }
          expect(peakPixels, lessThanOrEqualTo(1103 * 769 + 512 * 512));
          expect(livePixels, 0);
          expect(disposed, hasLength(created.length));
          for (final image in created) {
            expect(
              disposed.where((other) => identical(image, other)),
              hasLength(1),
            );
          }
          expect(budget.used.values.every((v) => v == 0), true);
        } finally {
          ui.Image.onCreate = previousCreate;
          ui.Image.onDispose = previousDispose;
        }
      }
    },
  );

  for (final effect in ['clip', 'mask']) {
    for (final (chain, definition, owner) in [
      (
        'group',
        '',
        '<g EFFECT><circle cx="50" cy="50" r="20" '
            'transform="rotate(45 50 50)"/></g>',
      ),
      (
        'use',
        '<circle id="target" r="20" transform="rotate(45)"/>',
        '<use href="#target" x="50" y="50" EFFECT/>',
      ),
      (
        'nested use',
        '<circle id="leaf" r="20"/><use id="target" href="#leaf" '
            'transform="rotate(45)"/>',
        '<use href="#target" x="50" y="50" EFFECT/>',
      ),
      (
        'symbol',
        '<symbol id="target" viewBox="0 0 100 100">'
            '<circle cx="50" cy="50" r="20" '
            'transform="rotate(45 50 50)"/></symbol>',
        '<use href="#target" width="100" height="100" EFFECT/>',
      ),
    ]) {
      test('$effect rotated-circle $chain uses transformed path bounds', () async {
        final p = plan(
          '<defs>$definition'
          '<clipPath id="c" clipPathUnits="objectBoundingBox">'
          '<rect width=".25" height="1"/></clipPath>'
          '<mask id="m" maskUnits="objectBoundingBox" '
          'maskContentUnits="objectBoundingBox" mask-type="alpha" '
          'x="0" y="0" width=".25" height="1">'
          '<rect width=".25" height="1" fill="white"/></mask></defs>'
          '${owner.replaceFirst('EFFECT', effect == 'clip' ? 'clip-path="url(#c)"' : 'mask="url(#m)"')}',
        );
        final budget = SceneResourceBudget();
        final scene = await p.prepare(budget: budget);
        try {
          expect(scene.capability, isA<CompleteSectionCapability>());
          expect(scene.geometry.completeness, isA<CompleteGeometry>());
          final region = effect == 'clip'
              ? scene.geometry.clips.last.region
              : scene.geometry.masks.single.region;
          // Quarter of the transformed diameter must be 10, not 14.142.
          expect(region.left, closeTo(30, .001));
          expect(region.top, closeTo(30, .001));
          expect(region.width, closeTo(10, .001));
          expect(region.height, closeTo(40, .001));
          final native = await image(scene);
          try {
            expect((await pixel(native, 38, 50))[3], 255);
            expect((await pixel(native, 42, 50))[3], 0);
          } finally {
            native.dispose();
          }
          final footprint = effect == 'clip'
              ? scene.geometry.paint.single.alphaFootprint!
              : scene.geometry.masks.single.coverage;
          expect(footprint.alphaAt(GeometryPoint(38.5, 50.5)), 255);
          expect(footprint.alphaAt(GeometryPoint(42.5, 50.5)), 0);
        } finally {
          scene.dispose();
        }
        expect(budget.used.values.every((v) => v == 0), true);
      });
    }
  }

  test(
    'owner bounds solve transformed cubic, ellipse and rounded-rect extrema',
    () async {
      for (final (shape, expected) in [
        (
          '<path d="M0 0 C0 40 40 40 40 0 Z" '
              'transform="matrix(1 0 1 1 10 20)"/>',
          ui.Rect.fromLTWH(10, 20, 40 * math.sqrt2, 30),
        ),
        (
          '<ellipse rx="20" ry="10" transform="matrix(1 .5 .75 1 50 50)"/>',
          ui.Rect.fromCenter(
            center: const ui.Offset(50, 50),
            width: 2 * math.sqrt(456.25),
            height: 2 * math.sqrt(200),
          ),
        ),
        (
          '<rect x="-30" y="-20" width="60" height="40" rx="10" ry="5" '
              'transform="matrix(1 .5 .75 1 50 50)"/>',
          ui.Rect.fromCenter(
            center: const ui.Offset(50, 50),
            width: 2 * (31.25 + math.sqrt(114.0625)),
            height: 2 * (25 + math.sqrt(50)),
          ),
        ),
      ]) {
        for (final effect in ['clip', 'mask']) {
          final p = plan(
            '<defs>'
            '<clipPath id="c" clipPathUnits="objectBoundingBox">'
            '<rect width="1" height="1"/></clipPath>'
            '<mask id="m" maskUnits="objectBoundingBox" mask-type="alpha" '
            'maskContentUnits="objectBoundingBox" x="0" y="0" width="1" height="1">'
            '<rect width="1" height="1" fill="white"/></mask></defs>'
            '<g ${effect == 'clip' ? 'clip-path="url(#c)"' : 'mask="url(#m)"'}>'
            '$shape</g>',
          );
          final budget = SceneResourceBudget();
          final scene = await p.prepare(budget: budget);
          try {
            expect(scene.capability, isA<CompleteSectionCapability>());
            final actual = effect == 'clip'
                ? scene.geometry.clips.last.region
                : scene.geometry.masks.single.region;
            expect(actual.left, closeTo(expected.left, .001));
            expect(actual.top, closeTo(expected.top, .001));
            expect(actual.width, closeTo(expected.width, .001));
            expect(actual.height, closeTo(expected.height, .001));
          } finally {
            scene.dispose();
          }
          expect(budget.used.values.every((v) => v == 0), true);
        }
      }
    },
  );

  for (final kind in ['alpha', 'luminance']) {
    test('$kind mask tiled readback equals whole rotated-edge alpha bytes', () async {
      const width = 1103, height = 769;
      final p = plan(
        '<defs><mask id="m" maskUnits="userSpaceOnUse" mask-type="$kind" '
        'x="0" y="0" width="$width" height="$height">'
        '<rect x="-450.5" y="-305.25" width="900.75" height="610.5" '
        'transform="translate(530.25 390.5) rotate(13)" fill="#80a060"/>'
        '</mask></defs><rect width="$width" height="$height" mask="url(#m)"/>',
        width: width,
        height: height,
      );
      final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
      canvas.clipRect(const ui.Rect.fromLTWH(0, 0, 1103, 769));
      if (kind == 'luminance') {
        canvas.saveLayer(
          null,
          ui.Paint()
            ..colorFilter = const ui.ColorFilter.matrix([
              0,
              0,
              0,
              0,
              0,
              0,
              0,
              0,
              0,
              0,
              0,
              0,
              0,
              0,
              0,
              .2126,
              .7152,
              .0722,
              0,
              0,
            ]),
        );
      }
      canvas.translate(530.25, 390.5);
      canvas.rotate(13 * 3.141592653589793 / 180);
      canvas.drawRect(
        const ui.Rect.fromLTWH(-450.5, -305.25, 900.75, 610.5),
        ui.Paint()..color = const ui.Color(0xff80a060),
      );
      if (kind == 'luminance') canvas.restore();
      final picture = recorder.endRecording();
      final whole = await picture.toImage(width, height);
      late GeometryAlphaFootprint expected;
      try {
        final rgba = (await whole.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        ))!.buffer.asUint8List();
        expected = GeometryAlphaFootprint.fromRgba(
          width: width,
          height: height,
          origin: GeometryPoint(0, 0),
          rgba: rgba,
          reserve: (_) {},
        );
      } finally {
        whole.dispose();
        picture.dispose();
      }
      final previousCreate = ui.Image.onCreate,
          previousDispose = ui.Image.onDispose;
      var livePixels = 0, peakPixels = 0, wholeImages = 0, largeTiles = 0;
      ui.Image.onCreate = (image) {
        previousCreate?.call(image);
        livePixels += image.width * image.height;
        if (livePixels > peakPixels) peakPixels = livePixels;
        if (image.width == width && image.height == height) wholeImages++;
        if (image.width == 512 && image.height == 512) largeTiles++;
      };
      ui.Image.onDispose = (image) {
        previousDispose?.call(image);
        livePixels -= image.width * image.height;
      };
      final budget = SceneResourceBudget();
      try {
        final scene = await p.prepare(budget: budget);
        try {
          expect(scene.capability, isA<CompleteSectionCapability>());
          final actual = scene.geometry.masks.single.coverage;
          expect(actual, expected);
          expect(actual.alpha, orderedEquals(expected.alpha));
          expect(wholeImages, 1);
          expect(largeTiles, 4); // Two complete passes across two full tiles.
          expect(peakPixels, width * height + 512 * 512);
          expect(livePixels, 0);
          expect(
            budget.peaks[SceneResource.layerPixels],
            p.reservation()[SceneResource.layerPixels],
          );
        } finally {
          scene.dispose();
          scene.dispose();
        }
        expect(budget.used.values.every((v) => v == 0), true);
      } finally {
        ui.Image.onCreate = previousCreate;
        ui.Image.onDispose = previousDispose;
      }
    });
  }

  test(
    'mask complete peak refuses before any native image allocation',
    () async {
      final p = plan(
        '<mask id="m"><rect width="100" height="100"/></mask>'
        '<rect width="100" height="100" mask="url(#m)"/>',
      );
      var images = 0;
      final previousCreate = ui.Image.onCreate;
      ui.Image.onCreate = (_) => images++;
      try {
        for (final resource in [
          SceneResource.layerPixels,
          SceneResource.layerBytes,
        ]) {
          final budget = SceneResourceBudget(
            limits: {
              ...SceneResourceBudget.provisionalLimits,
              resource: p.reservation()[resource]! - 1,
            },
          );
          final scene = await p.prepare(budget: budget);
          expect(scene.capability, isA<ResourceSectionCapability>());
          expect(scene.picture, isNull);
          scene.dispose();
          expect(images, 0);
          expect(budget.used.values.every((v) => v == 0), true);
        }
      } finally {
        ui.Image.onCreate = previousCreate;
      }
    },
  );

  test(
    'mask raster and tiles drain on cancellation and late failure',
    () async {
      for (final cancelAt in [1, 2, 4, 0]) {
        final p = plan(
          '<defs><mask id="m" maskUnits="userSpaceOnUse" mask-type="alpha" '
          'x="0" y="0" width="1103" height="769">'
          '<rect width="1103" height="769" fill="white"/></mask></defs>'
          '<rect width="1103" height="769" mask="url(#m)"/>',
          width: 1103,
          height: 769,
        );
        final budget = SceneResourceBudget(), token = PublicationCancellation();
        final created = <ui.Image>[], disposed = <ui.Image>[];
        final sizes = <ui.Size>[];
        final previousCreate = ui.Image.onCreate,
            previousDispose = ui.Image.onDispose;
        ui.Image.onCreate = (image) {
          previousCreate?.call(image);
          created.add(image);
          sizes.add(ui.Size(image.width.toDouble(), image.height.toDouble()));
          if (created.length == cancelAt) token.cancel();
        };
        ui.Image.onDispose = (image) {
          previousDispose?.call(image);
          disposed.add(image);
        };
        try {
          final future = p.prepare(
            budget: budget,
            cancellation: token,
            features: SvgFeatureRegistry([
              const SvgClipMaskFeature(),
              if (cancelAt == 0) const _FailAfterMaskFeature(),
            ]),
          );
          if (cancelAt > 0) {
            await expectLater(future, throwsA(isA<PreparationCancelled>()));
            expect(created, hasLength(cancelAt));
          } else {
            final scene = await future;
            expect(scene.capability, isA<UnsupportedSectionCapability>());
            expect(
              scene.capability.constructs.single.identifier,
              'test-mask-late',
            );
            expect(scene.picture, isNull);
            scene.dispose();
            scene.dispose();
            expect(
              created,
              hasLength(7),
            ); // Raster plus six tiles, uniform pass.
          }
          if (cancelAt != 1) expect(sizes[1], const ui.Size(512, 512));
          expect(disposed, hasLength(created.length));
          for (final image in created) {
            expect(
              disposed.where((other) => identical(image, other)),
              hasLength(1),
            );
          }
          expect(budget.used.values.every((v) => v == 0), true);
        } finally {
          ui.Image.onCreate = previousCreate;
          ui.Image.onDispose = previousDispose;
        }
      }
    },
  );

  test('clipPathUnits userSpaceOnUse and objectBoundingBox clip paths', () async {
    for (final (units, markup) in [
      (
        'userSpaceOnUse',
        '<clipPath id="c"><circle cx="50" cy="50" r="30"/></clipPath>',
      ),
      (
        'objectBoundingBox',
        '<clipPath id="c" clipPathUnits="objectBoundingBox"><rect width=".5" height="1"/></clipPath>',
      ),
    ]) {
      final p = plan(
        '$markup<rect id="r" width="100" height="100" fill="red" clip-path="url(#c)"/>',
      );
      final budget = SceneResourceBudget();
      final scene = await p.prepare(budget: budget);
      try {
        expect(
          scene.capability,
          isA<CompleteSectionCapability>(),
          reason: units,
        );
        expect(scene.geometry.completeness, isA<CompleteGeometry>());
        // The SVG viewport clip plus the authored path clip.
        expect(scene.geometry.clips, hasLength(2), reason: units);
        final fragment = scene.geometry.fragments.singleWhere(
          (f) => f.elementAnchor?.elementId == 'r',
        );
        expect(fragment.clipIds, hasLength(2));
        final authored = scene.geometry.clips.firstWhere(
          (c) => c.id == fragment.clipIds.last,
        );
        if (units == 'objectBoundingBox') {
          expect(authored.region.width, 50, reason: units);
        }
        final native = await image(scene);
        try {
          expect(
            (await pixel(
              native,
              units == 'objectBoundingBox' ? 25 : 50,
              50,
            ))[3],
            greaterThan(0),
            reason: units,
          );
          if (units == 'userSpaceOnUse') {
            expect((await pixel(native, 2, 2))[3], 0, reason: units);
          } else {
            expect((await pixel(native, 80, 50))[3], 0, reason: units);
          }
        } finally {
          native.dispose();
        }
      } finally {
        scene.dispose();
      }
      expect(budget.used.values.every((v) => v == 0), true);
    }
  });

  for (final effect in ['clip', 'mask']) {
    for (final (target, definition) in [
      ('use', '<rect id="target" width="30" height="30"/>'),
      (
        'nested use',
        '<rect id="leaf" width="15" height="30"/>'
            '<use id="target" href="#leaf" transform="scale(2 1)"/>',
      ),
      (
        'symbol',
        '<symbol id="target" viewBox="0 0 10 10">'
            '<rect width="10" height="10"/></symbol>',
      ),
    ]) {
      test('$effect bbox follows expanded $target transforms', () async {
        final p = plan(
          '<defs>$definition'
          '<clipPath id="c" clipPathUnits="objectBoundingBox">'
          '<rect width=".5" height="1"/></clipPath>'
          '<mask id="m" maskUnits="objectBoundingBox" '
          'maskContentUnits="objectBoundingBox" mask-type="alpha" '
          'x="0" y="0" width=".5" height="1">'
          '<rect width=".5" height="1" fill="white"/></mask></defs>'
          '<g transform="translate(10 10)"><use href="#target" '
          'x="5" y="5" width="30" height="30" transform="scale(2)" '
          'fill="red" ${effect == 'clip' ? 'clip-path="url(#c)"' : 'mask="url(#m)"'}/></g>',
        );
        final budget = SceneResourceBudget();
        final scene = await p.prepare(budget: budget);
        try {
          expect(scene.capability, isA<CompleteSectionCapability>());
          expect(scene.geometry.completeness, isA<CompleteGeometry>());
          final region = effect == 'clip'
              ? scene.geometry.clips.last.region
              : scene.geometry.masks.single.region;
          expect(
            [region.left, region.top, region.width, region.height],
            [20, 20, 30, 60],
          );
          final native = await image(scene);
          try {
            expect((await pixel(native, 30, 50))[3], 255);
            expect((await pixel(native, 60, 50))[3], 0);
          } finally {
            native.dispose();
          }
          if (effect == 'mask') {
            final coverage = scene.geometry.masks.single.coverage;
            expect(coverage.alphaAt(GeometryPoint(30.5, 50.5)), 255);
            expect(coverage.alphaAt(GeometryPoint(60.5, 50.5)), 0);
          } else {
            expect(
              scene.geometry.paint.single.alphaFootprint!.alphaAt(
                GeometryPoint(30.5, 50.5),
              ),
              255,
            );
          }
        } finally {
          scene.dispose();
        }
        expect(budget.used.values.every((value) => value == 0), true);
      });
    }
  }

  test('nested clip-path on a clipPath and clip-rule intersect', () async {
    final p = plan(
      '<defs><clipPath id="a" clip-path="url(#b)"><path clip-rule="evenodd" d="M10 10H90V90H10Z M30 30H70V70H30Z"/></clipPath><clipPath id="b"><circle cx="50" cy="50" r="35"/></clipPath></defs><rect id="r" width="100" height="100" fill="red" clip-path="url(#a)"/>',
    );
    final scene = await p.prepare(budget: SceneResourceBudget());
    try {
      expect(scene.capability, isA<CompleteSectionCapability>());
      // Viewport clip plus the outer and nested clipPath evidence.
      expect(scene.geometry.clips, hasLength(3));
      final fragment = scene.geometry.fragments.singleWhere(
        (f) => f.elementAnchor?.elementId == 'r',
      );
      expect(fragment.clipIds, hasLength(3));
      final native = await image(scene);
      try {
        expect((await pixel(native, 20, 50))[3], greaterThan(0));
        // Even-odd hole is transparent even though the nested circle covers it.
        expect((await pixel(native, 50, 50))[3], 0);
        // Outside the nested circle: transparent.
        expect((await pixel(native, 10, 50))[3], 0);
      } finally {
        native.dispose();
      }
    } finally {
      scene.dispose();
    }
  });

  test(
    'clip children union and normalized percentage units retain coverage',
    () async {
      final p = plan(
        '<defs><clipPath id="c" clipPathUnits="objectBoundingBox">'
        '<rect width="25%" height="100%"/>'
        '<rect x="75%" width="25%" height="100%"/>'
        '</clipPath></defs><rect id="r" width="100" height="100" '
        'fill="red" clip-path="url(#c)"/>',
      );
      final scene = await p.prepare(budget: SceneResourceBudget());
      try {
        expect(scene.geometry.completeness, isA<CompleteGeometry>());
        final native = await image(scene);
        try {
          expect((await pixel(native, 10, 50))[3], 255);
          expect((await pixel(native, 90, 50))[3], 255);
          expect((await pixel(native, 50, 50))[3], 0);
        } finally {
          native.dispose();
        }
        final alpha = scene.geometry.paint.single.alphaFootprint!;
        expect(alpha.alphaAt(GeometryPoint(10.5, 50.5)), 255);
        expect(alpha.alphaAt(GeometryPoint(50.5, 50.5)), 0);
      } finally {
        scene.dispose();
      }
    },
  );

  test('resolved CSS clip-path and mask use the same evidence path', () async {
    final p = plan(
      '<defs><clipPath id="c"><rect width="30" height="100"/></clipPath>'
      '<mask id="m" mask-type="alpha"><rect width="100" height="100" fill="white"/></mask>'
      '</defs><rect id="r" style="clip-path:url(#c);mask:url(#m)" '
      'width="100" height="100" fill="red"/>',
      css: {'clip-path': 'url(#c)', 'mask': 'url(#m)'},
    );
    final scene = await p.prepare(budget: SceneResourceBudget());
    try {
      expect(scene.geometry.completeness, isA<CompleteGeometry>());
      expect(scene.geometry.masks, hasLength(1));
      final native = await image(scene);
      try {
        expect((await pixel(native, 10, 50))[3], 255);
        expect((await pixel(native, 50, 50))[3], 0);
      } finally {
        native.dispose();
      }
    } finally {
      scene.dispose();
    }
  });

  test(
    'empty masked nodes remain incomplete without retained coverage',
    () async {
      final p = plan(
        '<defs><mask id="m" maskUnits="userSpaceOnUse" x="0" y="0" '
        'width="100" height="100"><rect width="100" height="100" fill="white"/></mask>'
        '</defs><g mask="url(#m)"/>',
      );
      final scene = await p.prepare(budget: SceneResourceBudget());
      try {
        expect(scene.geometry.completeness, isA<IncompleteGeometry>());
        final issues =
            (scene.geometry.completeness as IncompleteGeometry).issues;
        expect(
          issues.any(
            (issue) =>
                issue.kind == GeometryGapKind.mask &&
                issue.reason.contains('no retained paint footprint'),
          ),
          true,
        );
        expect(
          issues.any(
            (issue) => issue.reason.contains('did not report completion'),
          ),
          false,
        );
      } finally {
        scene.dispose();
      }
    },
  );

  test(
    'mask applications reserve luminance layers before allocation',
    () async {
      final p = plan(
        '<defs><mask id="m"><rect width="100" height="100" fill="white"/></mask></defs>'
        '<rect width="100" height="100" mask="url(#m)"/>'
        '<rect width="100" height="100" mask="url(#m)"/>',
      );
      expect(
        p.reservation()[SceneResource.layerPixels],
        greaterThanOrEqualTo(60000),
      );
      final budget = SceneResourceBudget(
        limits: {
          ...SceneResourceBudget.provisionalLimits,
          SceneResource.layerPixels: 1,
        },
      );
      final scene = await p.prepare(budget: budget);
      try {
        expect(scene.picture, isNull);
        expect(scene.capability, isA<ResourceSectionCapability>());
      } finally {
        scene.dispose();
      }
      expect(budget.used.values.every((v) => v == 0), true);
    },
  );

  test('transformed group clips use each descendant matrix once', () async {
    final p = plan(
      '<defs><clipPath id="c" clipPathUnits="objectBoundingBox">'
      '<rect width=".5" height="1"/></clipPath></defs>'
      '<g transform="translate(10 0)" clip-path="url(#c)">'
      '<g transform="translate(10 0)"><rect width="60" height="100" fill="red"/></g></g>',
    );
    final scene = await p.prepare(budget: SceneResourceBudget());
    try {
      expect(scene.geometry.completeness, isA<CompleteGeometry>());
      final clip = scene.geometry.clips.last.region;
      expect(clip.left, 20);
      expect(clip.width, 30);
      final native = await image(scene);
      try {
        expect((await pixel(native, 25, 50))[3], 255);
        expect((await pixel(native, 55, 50))[3], 0);
      } finally {
        native.dispose();
      }
    } finally {
      scene.dispose();
    }
  });

  test('rotated mask region clips its actual quadrilateral', () async {
    final p = plan(
      '<defs><mask id="m" mask-type="alpha" maskUnits="userSpaceOnUse" '
      'x="0" y="0" width="20" height="20">'
      '<rect x="-100" y="-100" width="200" height="200" fill="white"/></mask></defs>'
      '<rect x="-50" y="-50" width="100" height="100" fill="red" '
      'transform="translate(50 30) rotate(45)" mask="url(#m)"/>',
    );
    final scene = await p.prepare(budget: SceneResourceBudget());
    try {
      expect(scene.geometry.completeness, isA<CompleteGeometry>());
      final native = await image(scene);
      try {
        expect((await pixel(native, 50, 44))[3], 255);
        expect((await pixel(native, 37, 31))[3], 0);
      } finally {
        native.dispose();
      }
      final coverage = scene.geometry.masks.single.coverage;
      expect(coverage.alphaAt(GeometryPoint(37.5, 31.5)), 0);
    } finally {
      scene.dispose();
    }
  });

  test('alpha and luminance masks retain kind, region and coverage', () async {
    for (final (type, alpha) in [('alpha', 255), ('luminance', 128)]) {
      final p = plan(
        '<defs><mask id="m" maskUnits="userSpaceOnUse" x="0" y="0" width="50" height="100" style="mask-type:$type"><rect width="50" height="100" fill="#808080"/></mask></defs><rect id="r" width="100" height="100" fill="red" mask="url(#m)"/>',
      );
      final budget = SceneResourceBudget();
      final scene = await p.prepare(budget: budget);
      try {
        expect(
          scene.capability,
          isA<CompleteSectionCapability>(),
          reason: type,
        );
        expect(scene.geometry.completeness, isA<CompleteGeometry>());
        final evidence = scene.geometry.masks.single;
        expect(
          evidence.kind,
          type == 'alpha' ? GeometryMaskKind.alpha : GeometryMaskKind.luminance,
        );
        expect(evidence.region.left, 0);
        expect(evidence.region.width, 50);
        expect(evidence.coverage.alphaAt(GeometryPoint(25.5, 50.5)), alpha);
        expect(evidence.coverage.alphaAt(GeometryPoint(75.5, 50.5)), 0);
        final fragment = scene.geometry.fragments.singleWhere(
          (f) => f.elementAnchor?.elementId == 'r',
        );
        expect(fragment.maskIds, [evidence.id]);
        final native = await image(scene);
        try {
          expect((await pixel(native, 25, 50))[3], alpha, reason: type);
          expect((await pixel(native, 75, 50))[3], 0, reason: type);
        } finally {
          native.dispose();
        }
      } finally {
        scene.dispose();
      }
      expect(budget.used.values.every((v) => v == 0), true);
    }
  });

  test(
    'maskContentUnits and objectBoundingBox regions resolve explicitly',
    () async {
      final p = plan(
        '<defs><mask id="m" maskUnits="objectBoundingBox" maskContentUnits="objectBoundingBox" x="0" y="0" width=".5" height="1" mask-type="alpha"><rect width=".5" height="1" fill="black"/></mask></defs><rect id="r" x="20" y="20" width="60" height="60" fill="red" mask="url(#m)"/>',
      );
      final scene = await p.prepare(budget: SceneResourceBudget());
      try {
        expect(scene.capability, isA<CompleteSectionCapability>());
        final evidence = scene.geometry.masks.single;
        expect(evidence.units, GeometryMaskUnits.objectBoundingBox);
        expect(evidence.contentUnits, GeometryMaskUnits.objectBoundingBox);
        expect(evidence.region.left, 20);
        expect(evidence.region.top, 20);
        expect(evidence.region.width, 30);
        expect(evidence.region.height, 60);
        expect(evidence.coverage.alphaAt(GeometryPoint(30.5, 50.5)), 255);
        expect(evidence.coverage.alphaAt(GeometryPoint(55.5, 50.5)), 0);
      } finally {
        scene.dispose();
      }
    },
  );

  test('mask evidence composes through the slot transform', () async {
    final p = plan(
      '<defs><mask id="m" maskUnits="userSpaceOnUse" x="0" y="0" width="50" height="100" mask-type="alpha"><rect width="50" height="100" fill="white"/></mask></defs><rect id="r" width="100" height="100" fill="red" mask="url(#m)"/>',
    );
    final scene = await p.prepare(budget: SceneResourceBudget());
    try {
      final placed = placeSourceGeometry(
        scene.geometry,
        AffineTransform(1, 0, 0, 1, 7, 9),
        registryPrefix: 'page',
      );
      final evidence = placed.masks.single;
      expect(evidence.id, startsWith('page:'));
      expect(evidence.region.transform.e, 7);
      expect(evidence.region.transform.f, 9);
      expect(evidence.coverage.transform.e, 7);
      final fragment = placed.fragments.singleWhere(
        (f) => f.elementAnchor?.elementId == 'r',
      );
      expect(fragment.maskIds, [evidence.id]);
    } finally {
      scene.dispose();
    }
  });

  test('unsupported mask content and units refuse before allocation', () async {
    for (final (markup, identifier) in [
      (
        '<defs><mask id="m"><text>bad</text></mask></defs><rect width="10" height="10" mask="url(#m)"/>',
        'svg-mask-content',
      ),
      (
        '<defs><mask id="m" maskUnits="bogus"><rect width="10" height="10"/></mask></defs><rect width="10" height="10" mask="url(#m)"/>',
        'svg-mask-units',
      ),
      (
        '<defs><clipPath id="c"><text>bad</text></clipPath></defs><rect width="10" height="10" clip-path="url(#c)"/>',
        'svg-clipPath-content',
      ),
    ]) {
      final p = plan(markup);
      expect(
        p.capability,
        isA<UnsupportedSectionCapability>(),
        reason: identifier,
      );
      expect(
        (p.capability as UnsupportedSectionCapability)
            .constructs
            .single
            .identifier,
        identifier,
      );
      final budget = SceneResourceBudget();
      final scene = await p.prepare(budget: budget);
      try {
        expect(scene.picture, isNull);
        expect(scene.geometry.fragments, isEmpty);
      } finally {
        scene.dispose();
      }
      expect(budget.used.values.every((v) => v == 0), true);
    }
  });

  test(
    'scene disposal is exactly once and releases the mask layer lease',
    () async {
      final p = plan(
        '<defs><mask id="m" maskUnits="userSpaceOnUse" x="0" y="0" width="50" height="100"><rect width="50" height="100" fill="#808080"/></mask></defs><rect width="100" height="100" fill="red" mask="url(#m)"/>',
      );
      final budget = SceneResourceBudget();
      final scene = await p.prepare(budget: budget);
      expect(scene.capability, isA<CompleteSectionCapability>());
      scene.dispose();
      scene.dispose();
      expect(budget.used.values.every((v) => v == 0), true);
    },
  );
}

final class _FailAfterClipFeature extends SvgFeature {
  const _FailAfterClipFeature();
  @override
  String get key => 'test-clip-late';
  @override
  Future<void> postPaint(SvgFeaturePostPaintContext post) async {
    throw SvgFeatureRefusal(post.geometry.plan.rootIndex, key);
  }
}

final class _FailAfterMaskFeature extends SvgFeature {
  const _FailAfterMaskFeature();
  @override
  String get key => 'test-mask-late';
  @override
  Future<void> prepare(SvgFeaturePreparation preparation) async {
    throw SvgFeatureRefusal(preparation.plan.rootIndex, key);
  }
}
