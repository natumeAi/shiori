import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/geometry/source_geometry.dart';
import 'package:shiori/features/reader/engine/surface/page_surface_pool.dart';

import '../style/style_test_support.dart' as input;
import 'publication_fixed_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'SVG wrapper uses its SVG alpha reservation once at large page size',
    () async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(
        const ui.Rect.fromLTWH(0, 0, 1810, 2560),
        ui.Paint()..color = const ui.Color(0xff112233),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(1810, 2560);
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!
          .buffer
          .asUint8List();
      image.dispose();
      picture.dispose();
      final h = await PublicationFixedHarness.open(
        input.buildEpub(
          sections: {
            'p0.xhtml':
                '<html xmlns="http://www.w3.org/1999/xhtml"><head>'
                '<title>Generated</title>'
                '<meta name="viewport" content="width=1400,height=1400"/>'
                '<style>html,body{margin:0;width:100%;height:100%}</style>'
                '</head><body>'
                '<svg xmlns="http://www.w3.org/2000/svg" width="100%" '
                'height="100%" viewBox="0 0 1400 1400">'
                '<image width="1400" height="1400" href="page.png"/>'
                '</svg></body></html>',
          },
          files: {'page.png': png},
          metadata:
              '<meta property="rendition:layout">pre-paginated</meta>'
              '<meta property="rendition:spread">none</meta>',
        ),
      );
      final unit = h.composition.navigator.units.single;
      final lease = await h.pool.prepareFixedUnit(
        unit,
        layout: h.fixedLayout(0),
        loadSource: h.sources.unitSources.loadSource,
        fonts: h.fonts,
      );
      expect(lease, isNotNull);
      final scene = lease!.surface.fixedScenes.single;
      expect(scene.geometry.completeness, isA<CompleteGeometry>());
      expect(scene.scene.svgScenes.single.geometry.paint, hasLength(1));
      expect(
        scene.scene.svgScenes.single.geometry.paint.single.alphaFootprint,
        isNotNull,
      );
      expect(h.pool.resourceBudget.used.values.any((n) => n > 0), isTrue);
      expect(h.sources.retainedSourceOwners, 1);
      lease.release();
      lease.release();
      expect(scene.scene.picture.debugDisposed, isTrue);
      expect(scene.plan.source.isDisposed, isTrue);
      expect(h.pool.pictureBytes, 0);
      expect(h.pool.images.totalBytes, 0);
      expect(h.pool.resourceBudget.used.values.every((n) => n == 0), isTrue);
      expect(h.sources.retainedSourceOwners, 0);
    },
  );
}
