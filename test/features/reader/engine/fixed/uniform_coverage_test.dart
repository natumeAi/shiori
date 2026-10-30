import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/geometry/paint_geometry.dart';
import 'package:shiori/features/reader/data/geometry/source_geometry.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/source/source_parser.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_scene.dart';
import 'package:shiori/features/reader/engine/fixed/svg/svg_graphics.dart';
import 'package:shiori/features/reader/engine/layout/paragraph_factory.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/style/css_style_resolver.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';

import '../../contract_test_values.dart';
import '../style/style_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SvgGraphicsPlan plan(String body) {
    final document = const SourceParser().parse(
      '<svg xmlns="http://www.w3.org/2000/svg" width="80" height="80">$body</svg>',
      mediaType: 'image/svg+xml',
    );
    return SvgGraphicsPlan.inspect(
      document: document,
      rootIndex: document.documentElementIndex,
      page: contractPage(),
      size: AuthoredPageSize(80, 80),
    );
  }

  int at(GeometryAlphaFootprint f, int x, int y) {
    final xx = x - f.origin.x.toInt(), yy = y - f.origin.y.toInt();
    return xx < 0 || xx >= f.width || yy < 0 || yy >= f.height
        ? 0
        : f.alpha[yy * f.width + xx];
  }

  Future<void> compare(SvgGraphicsScene scene) async {
    final native = await scene.picture!.toImage(80, 80);
    try {
      final rgba = (await native.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      final f = scene.geometry.paint.single.alphaFootprint!;
      for (var y = 0; y < 80; y++) {
        for (var x = 0; x < 80; x++) {
          expect(at(f, x, y), rgba[(y * 80 + x) * 4 + 3], reason: '$x,$y');
        }
      }
    } finally {
      native.dispose();
    }
  }

  test(
    'SVG rectangles retain exact native alpha for uniform and AA edges',
    () async {
      for (final (transform, uniform) in [
        ('', true),
        ('translate(5 6)', true),
        ('rotate(15 30 30)', false),
        ('translate(.5 .25)', false),
      ]) {
        final budget = SceneResourceBudget();
        final scene = await plan(
          '<rect x="10" y="11" width="40" height="30" '
          'transform="$transform" fill="red" fill-opacity=".5"/>',
        ).prepare(budget: budget);
        try {
          expect(scene.geometry.completeness, isA<CompleteGeometry>());
          final f = scene.geometry.paint.single.alphaFootprint!;
          expect(f.uniformAlpha != null, uniform);
          expect(f.width * f.height, lessThan(80 * 80));
          await compare(scene);
        } finally {
          scene.dispose();
          scene.dispose();
        }
        expect(budget.used.values.every((v) => v == 0), true);
      }
    },
  );

  test(
    'opaque color-varying images compress; transparent holes stay exact',
    () async {
      for (final hole in [false, true]) {
        final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
        canvas.drawRect(
          const ui.Rect.fromLTWH(0, 0, 8, 8),
          ui.Paint()..color = const ui.Color(0xff112233),
        );
        canvas.drawRect(
          const ui.Rect.fromLTWH(4, 0, 4, 8),
          ui.Paint()..color = const ui.Color(0xffabcdef),
        );
        if (hole) {
          canvas.drawRect(
            const ui.Rect.fromLTWH(2, 2, 4, 4),
            ui.Paint()..blendMode = ui.BlendMode.clear,
          );
        }
        final picture = recorder.endRecording();
        final image = await picture.toImage(8, 8);
        final budget = SceneResourceBudget();
        final scene =
            await plan(
              '<image x="10" y="11" width="40" height="40" href="p.png"/>',
            ).prepare(
              budget: budget,
              images: SvgGraphicsImages(rasters: {'p.png': image}),
            );
        try {
          final f = scene.geometry.paint.single.alphaFootprint!;
          expect(f.uniformAlpha != null, !hole);
          expect(f.width, 40);
          expect(f.height, 40);
          if (hole) expect(at(f, 30, 31), 0);
          await compare(scene);
        } finally {
          scene.dispose();
          image.dispose();
          picture.dispose();
        }
        expect(budget.used.values.every((v) => v == 0), true);
      }
    },
  );

  test(
    'clips and masks preserve uniform sample views and group opacity',
    () async {
      final control = await plan(
        '<rect width="80" height="80" fill="white" '
        'fill-opacity=".5"/>',
      ).prepare(budget: SceneResourceBudget());
      final scene = await plan(
        '<defs>'
        '<clipPath id="c"><rect width="80" height="80"/></clipPath>'
        '<mask id="m" maskUnits="userSpaceOnUse" x="0" y="0" width="80" height="80" mask-type="alpha">'
        '<rect width="80" height="80" fill="white" fill-opacity=".5"/></mask></defs>'
        '<g opacity=".5"><rect x="10" y="11" width="40" height="30" fill="red" '
        'clip-path="url(#c)" mask="url(#m)"/></g>',
      ).prepare(budget: SceneResourceBudget());
      try {
        expect(scene.geometry.completeness, isA<CompleteGeometry>());
        final p = scene.geometry.paint.single, f = p.alphaFootprint!;
        expect(f.uniformAlpha, 255);
        expect(p.effectiveOpacity, .5);
        final mask = p.masks.single.coverage;
        expect(
          mask.uniformAlpha,
          control.geometry.paint.single.alphaFootprint!.uniformAlpha,
        );
        expect(mask.uniformAlpha, isNotNull);
        final explicit = GeometryAlphaFootprint(
          width: f.width,
          height: f.height,
          pixelSize: f.pixelSize,
          origin: f.origin,
          transform: f.transform,
          alpha: List.filled(f.width * f.height, 255),
          masks: f.masks,
        );
        expect(f, explicit);
        expect(scene.geometry.opacityGroups.single.opacity, .5);
        final native = await scene.picture!.toImage(80, 80);
        final groupedControl = await plan(
          '<g opacity=".5">'
          '<rect width="80" height="80" fill="white" fill-opacity=".5"/></g>',
        ).prepare(budget: SceneResourceBudget());
        final groupedImage = await groupedControl.picture!.toImage(80, 80);
        try {
          final rgba = (await native.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          final expected = (await groupedImage.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          for (var y = 0; y < 80; y++) {
            for (var x = 0; x < 80; x++) {
              final alpha = at(f, x, y), gridAlpha = at(explicit, x, y);
              expect(alpha, gridAlpha);
              final offset = (y * 80 + x) * 4 + 3;
              expect(rgba[offset], alpha == 0 ? 0 : expected[offset]);
            }
          }
        } finally {
          native.dispose();
          groupedImage.dispose();
          groupedControl.dispose();
        }
      } finally {
        scene.dispose();
        control.dispose();
      }
    },
  );

  test(
    'rectangle clips keep analytic evidence and preallocation refusal',
    () async {
      final small = plan('<rect width="10" height="10" fill="red"/>');
      final budget = SceneResourceBudget();
      final scene = await plan(
        '<defs><clipPath id="c">'
        '<rect x="20" y="10" width="30" height="40"/></clipPath></defs>'
        '<rect width="80" height="80" fill="red" clip-path="url(#c)"/>',
      ).prepare(budget: budget);
      try {
        final f = scene.geometry.paint.single.alphaFootprint!;
        expect(f.uniformAlpha, 255);
        expect(f.width, 30);
        expect(f.height, 40);
        expect(f.storageBytes, GeometryAlphaFootprint.storageOverhead);
        await compare(scene);
      } finally {
        scene.dispose();
        scene.dispose();
      }
      expect(budget.used.values.every((v) => v == 0), true);
      var allocations = 0;
      final previous = ui.Image.onCreate;
      ui.Image.onCreate = (_) => allocations++;
      final refusedBudget = SceneResourceBudget(
        limits: {
          ...SceneResourceBudget.provisionalLimits,
          SceneResource.vectorBytes:
              small.reservation()[SceneResource.vectorBytes]! - 1,
        },
      );
      try {
        final refused = await small.prepare(budget: refusedBudget);
        expect(refused.capability.isComplete, false);
        expect(allocations, 0);
        refused.dispose();
      } finally {
        ui.Image.onCreate = previous;
      }
      expect(refusedBudget.used.values.every((v) => v == 0), true);
    },
  );

  test(
    'XHTML solid backgrounds use constant evidence with no alpha raster',
    () async {
      final sample = StyleSample.html(
        '<div id="r"></div>',
        css: 'body{margin:0}#r{width:40px;height:30px;background:rgba(255,0,0,.5)}',
        metadata: '<meta property="rendition:layout">pre-paginated</meta>',
      );
      final styles = const CssStyleResolver().resolve(
        sample.book,
        0,
        sample.document,
        const ReaderSettings(),
        authoredViewport: AuthoredPageSize(80, 80),
      );
      final budget = SceneResourceBudget();
      var allocations = 0;
      final old = ui.Image.onCreate;
      ui.Image.onCreate = (_) => allocations++;
      late FixedScene scene;
      try {
        scene = await FixedSceneBuilder(
          document: sample.document,
          styles: styles,
          page: contractPage(),
          size: AuthoredPageSize(80, 80),
          fonts: ParagraphFonts(),
          budget: budget,
        ).build();
      } finally {
        ui.Image.onCreate = old;
      }
      try {
        final f = scene.geometry.paint.single.alphaFootprint!;
        expect(f.uniformAlpha, 128);
        expect(allocations, 0);
        expect(budget.used[SceneResource.vectorBytes], f.storageBytes);
        expect(f.width, 40);
        expect(f.height, 30);
      } finally {
        scene.dispose();
        scene.dispose();
      }
      expect(budget.used.values.every((v) => v == 0), true);
    },
  );
}
