import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/engine/motion/page_turn_engine.dart';
import 'package:shiori/features/reader/engine/motion/turn_session.dart';
import 'package:shiori/features/reader/engine/motion/reader_preparation_failure.dart';
import 'package:shiori/features/reader/engine/pagination/section_preparer.dart';
import 'package:shiori/features/reader/engine/surface/page_surface_pool.dart';
import 'package:shiori/features/reader/engine/surface/prepared_reader_session.dart';

import '../../contract_test_values.dart';
import '../layout/layout_test_support.dart';
import 'surface_test_support.dart';

void main() {
  initEngineBinding();
  test(
    'image refusal retains accepted page without publishing partial surface',
    () async {
      final fixture = openFixture('images');
      final png = fixture.archive.bytes('EPUB/images/generated.png')!;
      fixture.archive.close();
      final book = EpubBook.open(
        buildEpub(
          sections: {
            's.xhtml': xhtml(
              '<p>Accepted page</p><img src="a.png" width="16" height="24"/>'
              '<p style="break-before:page">Incoming page</p>'
              '<img src="b.png" width="16" height="24"/>'
              '<img src="c.png" width="16" height="24"/>',
            ),
          },
          files: {'a.png': png, 'b.png': png, 'c.png': png},
        ),
      );
      addTearDown(book.archive.close);
      final section = await prepareSection(
        book,
        0,
        preparer: SectionPreparer(),
        resolver: fixtureResolver(),
        contentId: contractContent().sha256,
      );
      addTearDown(section.dispose);
      expect(section.pageCount, 2);
      const intrinsicBytes = 64 * 96 * 4;
      final dpr = section.identity.devicePixelRatio;
      final outputBytes = (16 * dpr).ceil() * (24 * dpr).ceil() * 4;
      final pool = PageSurfacePool(
        maxImageBytes: intrinsicBytes + outputBytes * 2,
      );
      addTearDown(pool.close);
      final images = <ui.Image>[];
      final pictures = <ui.Picture>[];
      final oldImageCallback = ui.Image.onCreate;
      final oldPictureCallback = ui.Picture.onCreate;
      ui.Image.onCreate = images.add;
      ui.Picture.onCreate = pictures.add;
      addTearDown(() {
        ui.Image.onCreate = oldImageCallback;
        ui.Picture.onCreate = oldPictureCallback;
      });
      final session = (await PreparedReaderSession.open(
        pool: pool,
        section: section,
        pageIndex: 0,
        sectionCount: 1,
        loadSection: (_) async => section,
        theme: surfaceTheme,
        navigator: surfaceNavigator([section]),
        activation: surfaceActivation(1),
        isActivationCurrent: (_) => true,
      ))!;
      addTearDown(session.close);
      final accepted = session.position;
      final frame = session.frames.value;
      expect(images, hasLength(1));
      expect(pictures, hasLength(1));
      var publications = 0;
      session.frames.addListener(() => publications++);

      final result = await session.navigate(accepted, TurnDirection.next, null);
      expect(result.kind, TurnNavigationKind.failed);
      expect(result.failure!.kind, ReaderPreparationFailureKind.imageAdmission);
      expect(session.position.sameOrigin(accepted), isTrue);
      expect(await session.prove(accepted), isTrue);
      expect(session.frames.value, same(frame));
      expect(publications, 0);
      expect(frame.current.disposed, isFalse);
      expect(pictures, hasLength(1), reason: 'no partial page was recorded');
      expect(
        images,
        hasLength(2),
        reason: 'second incoming decode was refused',
      );
      expect(images.first.debugDisposed, isFalse);
      expect(
        images.last.debugDisposed,
        isTrue,
        reason: 'partial lease released',
      );
      expect(pool.images.pendingBytes, 0);
      expect(pool.images.totalBytes, outputBytes);
      expect(pool.owners, 1);
      expect(pool.liveSurfaces, 1);
      session.close();
      await session.closed;
      expect(images.every((image) => image.debugDisposed), isTrue);
      expect(pictures.every((picture) => picture.debugDisposed), isTrue);
      expect(pool.owners, 0);
      expect(pool.images.totalBytes, 0);
    },
  );
}
