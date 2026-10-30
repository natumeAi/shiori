import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/geometry/cluster_geometry.dart';
import 'package:shiori/features/reader/data/geometry/source_geometry.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_section_preparer.dart';
import 'package:shiori/features/reader/engine/surface/page_surface_pool.dart';

import '../style/style_test_support.dart' as input;
import 'publication_fixed_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List png;
  late Uint8List bluePng;
  setUpAll(() async {
    Future<Uint8List> solid(ui.Color color) async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(
        recorder,
      ).drawRect(const ui.Rect.fromLTWH(0, 0, 2, 2), ui.Paint()..color = color);
      final picture = recorder.endRecording();
      final image = await picture.toImage(2, 2);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
          .buffer
          .asUint8List();
      image.dispose();
      picture.dispose();
      return bytes;
    }

    png = await solid(const ui.Color(0xffff0000));
    bluePng = await solid(const ui.Color(0xff0000ff));
  });

  Future<PublicationFixedHarness> open(
    String body, {
    Map<String, Object> files = const {},
    String css = '',
  }) => PublicationFixedHarness.open(
    input.buildEpub(
      sections: {
        'pages/p0.xhtml': input.xhtml(
          head:
              '<meta name="viewport" content="width=100,height=100"/>'
              '<style>html,body{margin:0}img{width:20px;height:20px}$css</style>',
          body: body,
        ),
      },
      files: {'pages/page.png': png, 'images/page.png': png, ...files},
      metadata:
          '<meta property="rendition:layout">pre-paginated</meta>'
          '<meta property="rendition:spread">none</meta>',
    ),
  );

  void expectDrained(PublicationFixedHarness h) {
    expect(h.sources.retainedSourceOwners, 0);
    expect(h.pool.owners, 0);
    expect(h.pool.pictureBytes, 0);
    expect(h.pool.images.totalBytes, 0);
    expect(h.pool.resourceBudget.used.values.every((n) => n == 0), isTrue);
  }

  for (final tag in ['img', 'image']) {
    for (final available in [true, false]) {
      test('$tag document URL collision: relative resource available=$available', () async {
        final body = tag == 'img'
            ? '<img style="display:block;position:absolute;left:20px;top:30px" src="OEBPS/page.png"/>'
            : '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">'
                  '<image href="OEBPS/page.png" x="20" y="30" width="20" height="20"/></svg>';
        final h = await open(
          '$body<div class="preload-only" style="position:absolute;left:60px;top:0;width:20px;height:20px"/>',
          css: '.preload-only{background-image:url(../page.png)}',
          files: {
            'page.png': bluePng,
            if (available) 'pages/OEBPS/page.png': png,
          },
        );
        final unit = h.composition.navigator.units.single;
        final source = await h.sources.unitSources.loadSource(
          unit.activeSource,
        );
        try {
          expect(source.images.containsKey('OEBPS/page.png'), available);
        } finally {
          source.dispose();
        }
        final operation = h.pool.prepareFixedUnit(
          unit,
          layout: h.fixedLayout(0),
          loadSource: h.sources.unitSources.loadSource,
          fonts: h.fonts,
        );
        if (!available) {
          await expectLater(operation, throwsA(isA<FixedPreparationFailure>()));
        } else {
          final lease = await operation;
          expect(lease, isNotNull);
          try {
            final prepared = lease!.surface.fixedScenes.single;
            final node = prepared.plan.source.document.nodes.singleWhere(
              (n) => n.localName == tag,
            );
            final paint = prepared.geometry.paint.singleWhere(
              (p) => p.nodeIndex == node.index,
            );
            expect(
              paint.alphaFootprint!.alphaAt(GeometryPoint(25.5, 35.5)),
              255,
            );
            final raster = await prepared.scene.picture.toImage(100, 100);
            try {
              final rgba = (await raster.toByteData())!.buffer.asUint8List();
              const offset = (35 * 100 + 25) * 4;
              expect(rgba.sublist(offset, offset + 4), [255, 0, 0, 255]);
              const backgroundOffset = (5 * 100 + 65) * 4;
              expect(rgba.sublist(backgroundOffset, backgroundOffset + 4), [
                0,
                0,
                255,
                255,
              ]);
            } finally {
              raster.dispose();
            }
            expect(prepared.scene.capability.isComplete, true);
            expect(prepared.geometry.completeness, isA<CompleteGeometry>());
          } finally {
            lease?.release();
          }
        }
        expectDrained(h);
      });
    }
  }

  for (final sample in [
    ('block', '<img style="display:block" src="page.png"/>', 'page.png', 1),
    ('inline span', '<p><span><img src="page.png"/></span></p>', 'page.png', 1),
    (
      'parent relative',
      '<img src="../images/page.png"/>',
      '../images/page.png',
      1,
    ),
    ('duplicate', '<img src="page.png"/><img src="page.png"/>', 'page.png', 2),
  ]) {
    test('fixed publication admits and paints ${sample.$1} img', () async {
      final h = await open(sample.$2);
      final unit = h.composition.navigator.units.single;
      final source = await h.sources.unitSources.loadSource(unit.activeSource);
      try {
        expect(source.images.keys, [sample.$3]);
        expect(source.images[sample.$3]!.width, 2);
        expect(source.images[sample.$3]!.height, 2);
      } finally {
        source.dispose();
      }
      final lease = await h.pool.prepareFixedUnit(
        unit,
        layout: h.fixedLayout(0),
        loadSource: h.sources.unitSources.loadSource,
        fonts: h.fonts,
      );
      expect(lease, isNotNull);
      try {
        final prepared = lease!.surface.fixedScenes.single;
        expect(prepared.geometry.completeness, isA<CompleteGeometry>());
        final imageNodes = prepared.plan.source.document.nodes
            .where((node) => node.localName == 'img')
            .map((node) => node.index);
        final paints = prepared.geometry.paint
            .where((paint) => imageNodes.contains(paint.nodeIndex))
            .toList();
        expect(paints, hasLength(sample.$4));
        final boxes = prepared.scene.boxes
            .where((box) => imageNodes.contains(box.nodeIndex))
            .toList();
        expect(boxes, hasLength(sample.$4));
        final raster = await prepared.scene.picture.toImage(100, 100);
        try {
          final pixels = (await raster.toByteData())!;
          for (final box in boxes) {
            final center = box.contentBox.center;
            final offset = (center.dy.floor() * 100 + center.dx.floor()) * 4;
            expect(pixels.getUint8(offset), 255);
            expect(pixels.getUint8(offset + 1), 0);
            expect(pixels.getUint8(offset + 2), 0);
            expect(pixels.getUint8(offset + 3), 255);
          }
        } finally {
          raster.dispose();
        }
      } finally {
        lease?.release();
      }
      expectDrained(h);
    });
  }

  for (final sample in [
    ('external', 'src="https://example.invalid/page.png"'),
    ('protocol relative', 'src="//example.invalid/page.png"'),
    ('data', 'src="data:image/png;base64,AA=="'),
    ('missing attribute', ''),
    ('empty', 'src=""'),
    ('fragment', 'src="#image"'),
    ('missing resource', 'src="missing.png"'),
  ]) {
    test(
      'fixed publication refuses ${sample.$1} img without partial paint',
      () async {
        final h = await open('<img ${sample.$2}/>');
        final unit = h.composition.navigator.units.single;
        final source = await h.sources.unitSources.loadSource(
          unit.activeSource,
        );
        try {
          expect(source.images, isEmpty);
        } finally {
          source.dispose();
        }
        await expectLater(
          h.pool.prepareFixedUnit(
            unit,
            layout: h.fixedLayout(0),
            loadSource: h.sources.unitSources.loadSource,
            fonts: h.fonts,
          ),
          throwsA(
            isA<FixedPreparationFailure>().having(
              (failure) => failure.capability.constructs.map(
                (construct) => construct.identifier,
              ),
              'missing image refusal',
              contains('missing-admitted-image'),
            ),
          ),
        );
        expectDrained(h);
      },
    );
  }
}
