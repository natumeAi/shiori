import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/layout/reading_unit.dart';
import 'package:shiori/features/reader/data/layout/source_page_slot.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/layout/font_registry.dart';
import 'package:shiori/features/reader/engine/pagination/layout_identity.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';
import 'package:shiori/features/reader/engine/surface/page_surface_pool.dart';

import '../../contract_test_values.dart';
import '../layout/layout_test_support.dart';

ReadingUnit spread(int index, {bool blank = false}) {
  final left = contractPage(section: index * 2, id: 'left-$index');
  final right = contractPage(section: index * 2 + 1, id: 'right-$index');
  return ReadingUnit(
    id: ReadingUnitId(
      content: contractContent(),
      stableId: 'spread-$index-$blank',
    ),
    kind: ReadingUnitKind.fixedSpread,
    slots: [
      if (blank)
        const BlankSourcePageSlot()
      else
        contractSlot(page: left, side: SpreadSide.left),
      contractSlot(page: right, side: SpreadSide.right),
    ],
    activeSource: right,
  );
}

void main() {
  initEngineBinding();
  test('three units plus reserve charge all eight real constituents once', () {
    final pool = PageSurfacePool();
    final units = [for (var i = 0; i < 4; i++) pool.reserveUnit(spread(i))!];
    expect(pool.owners, 4);
    expect(pool.resourceBudget.used[SceneResource.readingUnits], pool.owners);
    expect(pool.resourceBudget.used[SceneResource.sourcePages], 8);
    expect(pool.reserveUnit(spread(4)), isNull);
    units.first.release();
    units.first.release();
    expect(pool.owners, 3);
    expect(pool.resourceBudget.used[SceneResource.sourcePages], 6);
    final replacement = pool.reserveUnit(spread(4))!;
    expect(pool.resourceBudget.used[SceneResource.sourcePages], 8);
    pool.close();
    expect(pool.owners, 4, reason: 'close does not preempt physical owners');
    for (final unit in units) {
      unit.release();
    }
    replacement.release();
    replacement.release();
    expect(pool.owners, 0);
    expect(pool.resourceBudget.used.values, everyElement(0));
    expect(pool.resourceBudget.peaks[SceneResource.sourcePages], 8);
  });

  test(
    'blank slots are uncharged; failed admission does not create a pool owner',
    () {
      final budget = SceneResourceBudget(
        limits: {
          ...SceneResourceBudget.provisionalLimits,
          SceneResource.sourcePages: 2,
        },
      );
      final pool = PageSurfacePool(resourceBudget: budget);
      final padded = pool.reserveUnit(spread(0, blank: true))!;
      expect(budget.used[SceneResource.sourcePages], 1);
      expect(
        () => pool.reserveUnit(spread(1)),
        throwsA(isA<SceneAdmissionException>()),
      );
      expect(pool.owners, 1);
      expect(budget.used[SceneResource.readingUnits], 1);
      expect(budget.used[SceneResource.sourcePages], 1);
      padded.release();
      pool.close();
      expect(budget.used.values, everyElement(0));
    },
  );

  test('two pools share old/new charges until the old reservation drains', () {
    final budget = SceneResourceBudget();
    final old = PageSurfacePool(resourceBudget: budget);
    final next = PageSurfacePool(resourceBudget: budget);
    final retiring = old.reserveUnit(spread(0))!;
    final replacement = next.reserveUnit(spread(1))!;
    old.close();
    expect(budget.used[SceneResource.sourcePages], 4);
    retiring.release();
    expect(budget.used[SceneResource.sourcePages], 2);
    replacement.release();
    next.close();
    expect(budget.used.values, everyElement(0));
  });

  test(
    'invalid fixed identity refuses before source access or picture allocation',
    () async {
      final pictures = <ui.Picture>[];
      final previous = ui.Picture.onCreate;
      ui.Picture.onCreate = pictures.add;
      addTearDown(() => ui.Picture.onCreate = previous);
      final pool = PageSurfacePool();
      final unit = spread(0);
      await expectLater(
        pool.prepareFixedUnit(
          unit,
          layout: const LayoutIdentity(
            contentId: 'wrong',
            sectionIndex: 0,
            viewportWidth: 800,
            viewportHeight: 600,
            devicePixelRatio: 1,
            settings: ReaderSettings(),
            fontSignature: '',
          ),
          fonts: FontRegistry(),
          loadSource: (_) => throw StateError('must not load'),
        ),
        throwsArgumentError,
      );
      expect(pictures, isEmpty);
      expect(pool.owners, 0);
      expect(pool.resourceBudget.used, isEmpty);
      pool.close();
    },
  );
}
