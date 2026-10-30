import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/layout/reading_unit.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/pagination/layout_identity.dart';
import 'package:shiori/features/reader/engine/surface/page_surface_pool.dart';

import '../layout/layout_test_support.dart' show openFixture;
import '../style/style_test_support.dart';
import 'fixed_session_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final dpr in [1.0, 2.0, 3.0]) {
    test(
      'frozen view/DPR $dpr reaches decode, plan, admission and layers',
      () async {
        final images = openFixture('images');
        final png = images.archive.bytes('EPUB/images/generated.png')!;
        images.archive.close();
        final sample = StyleSample.html(
          '<div id="bg" style="opacity:.5;width:64px;height:96px;background-image:url(tile.png)"></div>',
          css: 'html,body{margin:0;width:800px;height:1200px}',
          head: '<meta name="viewport" content="width=800,height=1200"/>',
          metadata: '<meta property="rendition:layout">pre-paginated</meta>',
          files: {'tile.png': png},
        );
        final f = FixedSessionFixture(
          caseId: 'metadata-boundary',
          width: 400,
          height: 600,
        );
        f.documents[0] = sample.document;
        f.styles[0] = sample.styled;
        await f.prepareNavigation();
        final pool = PageSurfacePool();
        final path = sample.styled
            .styleOf(sample.byId('bg'))!
            .authored
            .backgroundImage!;
        f.images[0] = {
          path: pool.fixedImageRequest(
            'tile',
            png,
            page: f.page(0),
            width: 64,
            height: 96,
          ),
        };
        final sources = f.sources(), original = f.layout(0);
        final layout = LayoutIdentity(
          contentId: original.contentId,
          sectionIndex: 0,
          viewportWidth: 400,
          viewportHeight: 600,
          devicePixelRatio: dpr,
          settings: original.settings,
          fontSignature: original.fontSignature,
        );
        final lease = (await pool.prepareFixedUnit(
          f.navigator.units.single,
          layout: layout,
          loadSource: sources.loadSource,
          fonts: sources.fonts,
        ))!;
        final scene = lease.surface.fixedScenes.single;
        final expectedWidth = dpr == 1 ? 32 : 64,
            expectedHeight = dpr == 1 ? 48 : 96;
        expect(scene.plan.scale.value, .5 * dpr);
        expect(scene.plan.imageTarget(path), (
          width: expectedWidth,
          height: expectedHeight,
        ));
        const evidence = 800 * 1200 + 2 * 512 * 512;
        expect(scene.plan.evidencePixels, evidence);
        expect(
          scene.plan.resources[SceneResource.layerPixels],
          evidence + (400 * dpr) * (600 * dpr),
        );
        expect(
          pool.resourceBudget.used[SceneResource.layerPixels],
          scene.plan.resources[SceneResource.layerPixels],
        );
        expect(pool.images.totalBytes, expectedWidth * expectedHeight * 4);
        expect(
          pool.images.peakBytes,
          64 * 96 * 8 + (dpr == 1 ? 32 * 48 * 4 : 0),
        );
        lease.release();
        pool.close();
        await pool.drained;
        expect(pool.images.totalBytes, 0);
        expect(pool.pictureBytes, 0);
        expect(pool.resourceBudget.used.values.every((v) => v == 0), true);
        f.dispose();
        sample.book.archive.close();
      },
    );
  }

  test('spread uses one fit for both source plans', () async {
    final f = FixedSessionFixture(caseId: 'metadata-boundary', spreads: 1);
    await f.prepareNavigation();
    final unit = f.navigator.units.single;
    expect(unit.kind, ReadingUnitKind.fixedSpread);
    final pool = PageSurfacePool(), sources = f.sources();
    final lease = (await pool.prepareFixedUnit(
      unit,
      layout: f.layout(0),
      loadSource: sources.loadSource,
      fonts: sources.fonts,
    ))!;
    expect(lease.surface.fixedScenes.length, 2);
    expect(lease.surface.fixedScenes.map((s) => s.plan.scale.value), [
      1.25,
      1.25,
    ]);
    lease.release();
    pool.close();
    await pool.drained;
    expect(pool.resourceBudget.used.values.every((v) => v == 0), true);
    f.dispose();
  });
}
