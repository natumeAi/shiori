import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';
import 'package:shiori/features/reader/engine/motion/page_turn_engine.dart';
import 'package:shiori/features/reader/engine/layout/layout_model.dart';
import 'package:shiori/features/reader/engine/layout/image_cache.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/pagination/prepared_section.dart';
import 'package:shiori/features/reader/engine/pagination/section_preparer.dart';
import 'package:shiori/features/reader/engine/surface/page_surface_pool.dart';

import '../layout/layout_test_support.dart';
import 'surface_test_support.dart';

void main() {
  initEngineBinding();
  late PreparedSection section;
  late int page;
  setUpAll(() async {
    section = await prepareSection(
      openFixture('images'),
      0,
      preparer: SectionPreparer(),
      resolver: fixtureResolver(),
    );
    final block = section.blocks.firstWhere(
      (laid) =>
          laid.block is ImageBlock &&
          (laid.block as ImageBlock).resourcePath != null,
    );
    page = block.linePage.first;
  });
  tearDownAll(() => section.dispose());

  test(
    'last lease release disposes picture and decoded image handles',
    () async {
      final decoded = <ui.Image>[];
      final old = ui.Image.onCreate;
      ui.Image.onCreate = decoded.add;
      addTearDown(() => ui.Image.onCreate = old);
      final pool = PageSurfacePool();
      final lease = (await pool.prepare(section, page, surfaceTheme))!;
      final retained = lease.retain();
      expect(pool.resourceBudget.used[SceneResource.readingUnits], 1);
      expect(pool.resourceBudget.used[SceneResource.sourcePages], 1);
      expect(pool.pictureBytes, greaterThan(0));
      expect(pool.images.totalBytes, greaterThan(0));
      expect(decoded, isNotEmpty);
      lease.release();
      lease.release();
      expect(pool.resourceBudget.used[SceneResource.sourcePages], 1);
      expect(lease.surface.disposed, isFalse);
      expect(decoded.every((image) => !image.debugDisposed), isTrue);
      retained.release();
      retained.release();
      expect(pool.resourceBudget.used.values, everyElement(0));
      expect(lease.surface.picture.debugDisposed, isTrue);
      expect(decoded.every((image) => image.debugDisposed), isTrue);
      expect(pool.owners, 0);
      expect(pool.pictureBytes, 0);
      expect(pool.images.totalBytes, 0);
      expect(pool.images.entryCount, 0);
      pool.close();
    },
  );

  test('picture byte limit refuses before recording or decoding', () async {
    final pictures = <ui.Picture>[];
    final old = ui.Picture.onCreate;
    ui.Picture.onCreate = pictures.add;
    addTearDown(() => ui.Picture.onCreate = old);
    final pool = PageSurfacePool(maxPictureBytes: 0);
    expect(await pool.prepare(section, page, surfaceTheme), isNull);
    expect(pictures, isEmpty);
    expect(pool.resourceBudget.used.values, everyElement(0));
    expect(pool.owners, 0);
    expect(pool.pictureBytes, 0);
    expect(pool.images.totalBytes, 0);
    pool.close();
  });

  test(
    'image byte limit rejects a candidate without retaining decoded bytes',
    () async {
      final pool = PageSurfacePool(maxImageBytes: 1);
      expect(await pool.prepare(section, page, surfaceTheme), isNull);
      expect(pool.owners, 0);
      expect(pool.pictureBytes, 0);
      expect(pool.images.totalBytes, 0);
      pool.close();
    },
  );

  test(
    'pending decode owns capacity through close and cannot publish late',
    () async {
      final pool = PageSurfacePool();
      final pending = pool.prepare(section, page, surfaceTheme);
      expect(pool.owners, 1);
      expect(pool.resourceBudget.used[SceneResource.sourcePages], 1);
      pool.close();
      expect(pool.owners, 1);
      expect(pool.resourceBudget.used[SceneResource.sourcePages], 1);
      expect(await pending, isNull);
      expect(pool.resourceBudget.used.values, everyElement(0));
      expect(pool.owners, 0);
      expect(pool.pictureBytes, 0);
      expect(pool.images.totalBytes, 0);
      expect(await pool.prepare(section, page, surfaceTheme), isNull);
    },
  );

  test(
    'surface preparation and last release assert inside motion callbacks',
    () async {
      final pool = PageSurfacePool();
      await expectLater(
        ReaderWorkGuard.callback(
          () => pool.prepare(section, page, surfaceTheme),
        ),
        throwsAssertionError,
      );
      final lease = (await pool.prepare(section, page, surfaceTheme))!;
      expect(
        () => ReaderWorkGuard.callback(lease.release),
        throwsAssertionError,
      );
      expect(lease.released, isFalse);
      lease.release();
      expect(pool.owners, 0);
      expect(lease.surface.picture.debugDisposed, isTrue);
      pool.close();
    },
  );

  test('concurrent warming of one neighbor keeps only one owner', () async {
    final h = await SurfaceHarness.open();
    addTearDown(h.close);
    await Future.wait([
      h.session.warm(TurnDirection.next),
      h.session.warm(TurnDirection.next),
    ]);
    expect(h.pool.owners, 2);
  });

  test(
    'picture plan is charged before record and reconciles actual bytes',
    () async {
      final pool = PageSurfacePool();
      final bound = PageSurfacePool.pictureReservationBytes(section, page);
      final old = ui.Picture.onCreate;
      var recorded = 0;
      ui.Picture.onCreate = (_) {
        recorded++;
        expect(pool.pictureBytes, bound);
        expect(pool.pinsSection(section), isTrue);
      };
      addTearDown(() => ui.Picture.onCreate = old);
      final lease = (await pool.prepare(section, page, surfaceTheme))!;
      expect(recorded, 1);
      expect(pool.pictureBytes, lease.surface.pictureBytes);
      expect(pool.pictureBytes, lessThanOrEqualTo(bound));
      lease.release();
      expect(pool.pinsSection(section), isFalse);
      expect(pool.pictureBytes, 0);
      pool.close();
    },
  );

  test(
    'old and replacement pools share admission until the old release',
    () async {
      final measure = PageSurfacePool();
      final measured = (await measure.prepare(section, page, surfaceTheme))!;
      final actual = measured.surface.pictureBytes;
      measured.release();
      measure.close();
      final bound = PageSurfacePool.pictureReservationBytes(section, page);
      final allocations = SurfaceAllocationBudget(
        maxPictureBytes: bound + actual - 1,
      );
      final first = PageSurfacePool(allocations: allocations);
      final second = PageSurfacePool(allocations: allocations);
      final old = (await first.prepare(section, page, surfaceTheme))!;
      expect(await second.prepare(section, page, surfaceTheme), isNull);
      expect(old.surface.picture.debugDisposed, isFalse);
      first.close();
      expect(second.pinsSection(section), isTrue);
      expect(second.pictureBytes, actual);
      old.release();
      expect(second.pinsSection(section), isFalse);
      final replacement = (await second.prepare(section, page, surfaceTheme))!;
      replacement.release();
      second.close();
      expect(first.pictureBytes, 0);
    },
  );

  test(
    'decode peak refuses before image allocation and keeps old leases',
    () async {
      final block = section.blocks
          .map((laid) => laid.block)
          .whereType<ImageBlock>()
          .firstWhere((block) => block.resourcePath != null);
      final bytes = section.resources.bytes(block.resourcePath!)!;
      final sizes = ReaderImageCache();
      final intrinsic = (await sizes.intrinsicSize('image', bytes))!;
      final peak =
          (intrinsic.width * intrinsic.height * 4).toInt() + 64 * 64 * 4;
      final images = <ui.Image>[];
      final oldCallback = ui.Image.onCreate;
      ui.Image.onCreate = images.add;
      addTearDown(() => ui.Image.onCreate = oldCallback);
      final tooSmall = ReaderImageCache(maxBytes: peak - 1);
      await expectLater(
        tooSmall.lease('image', bytes, targetWidth: 64, targetHeight: 64),
        throwsA(isA<ImageAdmissionException>()),
      );
      expect(images, isEmpty);
      expect(tooSmall.totalBytes, 0);
      final cache = ReaderImageCache(maxBytes: peak);
      final first = (await cache.lease(
        'image',
        bytes,
        targetWidth: 64,
        targetHeight: 64,
      ))!;
      final count = images.length;
      expect(cache.pendingBytes, 0);
      await expectLater(
        cache.lease('replacement', bytes, targetWidth: 64, targetHeight: 64),
        throwsA(isA<ImageAdmissionException>()),
      );
      expect(images.length, count);
      expect(first.image.debugDisposed, isFalse);
      expect(cache.totalBytes, first.bytes);
      first.release();
      final replacement = (await cache.lease(
        'replacement',
        bytes,
        targetWidth: 64,
        targetHeight: 64,
      ))!;
      expect(first.image.debugDisposed, isTrue);
      replacement.release();
      cache.clearUnleased();
      expect(cache.totalBytes, 0);
      expect(images.every((image) => image.debugDisposed), isTrue);
    },
  );
}
