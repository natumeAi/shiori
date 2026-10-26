import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';
import 'package:shiori/features/reader/engine/motion/page_turn_engine.dart';
import 'package:shiori/features/reader/engine/layout/layout_model.dart';
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
      expect(pool.pictureBytes, greaterThan(0));
      expect(pool.images.totalBytes, greaterThan(0));
      expect(decoded, isNotEmpty);
      lease.release();
      expect(lease.surface.disposed, isFalse);
      expect(decoded.every((image) => !image.debugDisposed), isTrue);
      retained.release();
      expect(lease.surface.picture.debugDisposed, isTrue);
      expect(decoded.every((image) => image.debugDisposed), isTrue);
      expect(pool.owners, 0);
      expect(pool.pictureBytes, 0);
      expect(pool.images.totalBytes, 0);
      expect(pool.images.entryCount, 0);
      pool.close();
    },
  );

  test(
    'picture byte limit rejects and disposes a recorded candidate',
    () async {
      final pictures = <ui.Picture>[];
      final old = ui.Picture.onCreate;
      ui.Picture.onCreate = pictures.add;
      addTearDown(() => ui.Picture.onCreate = old);
      final pool = PageSurfacePool(maxPictureBytes: 0);
      expect(await pool.prepare(section, page, surfaceTheme), isNull);
      expect(pictures, isNotEmpty);
      expect(pictures.every((picture) => picture.debugDisposed), isTrue);
      expect(pool.owners, 0);
      expect(pool.pictureBytes, 0);
      expect(pool.images.totalBytes, 0);
      pool.close();
    },
  );

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
      pool.close();
      expect(pool.owners, 1);
      expect(await pending, isNull);
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
}
