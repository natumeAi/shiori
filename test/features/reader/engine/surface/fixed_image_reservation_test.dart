import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/worker/publication_cancellation.dart';
import 'package:shiori/features/reader/engine/layout/image_cache.dart';
import 'package:shiori/features/reader/engine/style/css_style_resolver.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';
import 'package:shiori/features/reader/engine/surface/page_surface_pool.dart';

import '../layout/layout_test_support.dart' show openFixture;
import '../style/style_test_support.dart';
import 'fixed_session_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'fixed output reservation exchanges into intrinsic peak and retained image',
    () async {
      final imageBook = openFixture('images');
      final png = imageBook.archive.bytes('EPUB/images/generated.png')!;
      imageBook.archive.close();
      final sample = StyleSample.html(
        '<div id="source" style="width:64px;height:96px;background-image:url(tile.png)"></div>',
        css: 'html,body{margin:0;width:320px;height:240px}',
        head: '<meta name="viewport" content="width=320,height=240"/>',
        metadata: '<meta property="rendition:layout">pre-paginated</meta>',
        files: {'tile.png': png},
      );
      final f = FixedSessionFixture(caseId: 'metadata-boundary');
      f.documents[0] = sample.document;
      f.styles[0] = const CssStyleResolver().resolve(
        sample.book,
        0,
        sample.document,
        const ReaderSettings(),
      );
      await f.prepareNavigation();
      const output = 64 * 96 * 4;
      final pool = PageSurfacePool(maxImageBytes: output * 2);
      final created = <ui.Image>[];
      final samples = <(int, int)>[];
      final oldCreate = ui.Image.onCreate;
      ui.Image.onCreate = (image) {
        created.add(image);
        samples.add((pool.images.totalBytes, pool.images.pendingBytes));
      };
      addTearDown(() => ui.Image.onCreate = oldCreate);
      final imagePath = f.styles[0]!
          .styleOf(sample.byId('source'))!
          .authored
          .backgroundImage!;
      f.images[0] = {
        imagePath: pool.fixedImageRequest(
          'tile',
          png,
          page: f.page(0),
          width: 64,
          height: 96,
        ),
      };
      final sources = f.sources();
      final lease = (await pool.prepareFixedUnit(
        f.navigator.units.single,
        layout: f.layout(0),
        loadSource: sources.loadSource,
        fonts: sources.fonts,
      ))!;
      expect(created.length, greaterThanOrEqualTo(1));
      expect(samples.first, (output * 2, output * 2));
      expect(created.first.debugDisposed, false);
      expect(pool.images.totalBytes, output);
      expect(pool.images.pendingBytes, 0);
      expect(
        lease.surface.geometry.single.paint.any(
          (p) => p.alphaFootprint != null,
        ),
        true,
      );
      lease.release();
      lease.release();
      pool.close();
      await pool.drained;
      expect(created.every((image) => image.debugDisposed), true);
      expect(pool.images.totalBytes, 0);
      expect(pool.pictureBytes, 0);
      f.dispose();
      sample.book.archive.close();
    },
  );

  test('expired decode credit cannot underflow pending accounting', () async {
    final imageBook = openFixture('images');
    final png = imageBook.archive.bytes('EPUB/images/generated.png')!;
    imageBook.archive.close();
    final cache = ReaderImageCache();
    final credit = cache.reserveOutput(64 * 96 * 4)..release();
    await expectLater(
      cache.lease(
        'expired',
        png,
        targetWidth: 64,
        targetHeight: 96,
        reservation: credit,
      ),
      throwsA(isA<ImageAdmissionException>()),
    );
    expect(cache.totalBytes, 0);
    expect(cache.pendingBytes, 0);
    final token = PublicationCancellation()..cancel();
    final pool = PageSurfacePool();
    final f = FixedSessionFixture(caseId: 'metadata-boundary');
    final request = pool.fixedImageRequest(
      'canceled',
      png,
      page: f.page(0),
      width: 64,
      height: 96,
    );
    await expectLater(request.acquire(token), throwsA(isA<Exception>()));
    expect(pool.images.totalBytes, 0);
    pool.close();
    f.dispose();
  });

  test('discarding evidence releases only that unleased cache entry', () async {
    final book = openFixture('images');
    final png = book.archive.bytes('EPUB/images/generated.png')!;
    book.archive.close();
    final cache = ReaderImageCache();
    final retained = (await cache.lease(
      'other',
      png,
      targetWidth: 64,
      targetHeight: 96,
    ))!;
    retained.release();
    final evidence = (await cache.lease(
      'evidence',
      png,
      targetWidth: 64,
      targetHeight: 96,
    ))!;
    evidence.release(discard: true);
    evidence.release(discard: true);
    expect(evidence.image.debugDisposed, true);
    expect(retained.image.debugDisposed, false);
    expect(cache.totalBytes, 64 * 96 * 4);
    expect(cache.entryCount, 1);
    cache.clearUnleased();
    expect(cache.totalBytes, 0);
  });

  test('rejected cache-hit credit preserves the live entry', () async {
    final book = openFixture('images');
    final png = book.archive.bytes('EPUB/images/generated.png')!;
    book.archive.close();
    final cache = ReaderImageCache();
    final live = (await cache.lease(
      'shared',
      png,
      targetWidth: 64,
      targetHeight: 96,
    ))!;
    final credit = cache.reserveOutput(live.bytes)..release();
    await expectLater(
      cache.lease(
        'shared',
        png,
        targetWidth: 64,
        targetHeight: 96,
        reservation: credit,
      ),
      throwsA(isA<ImageAdmissionException>()),
    );
    expect(cache.entryCount, 1);
    expect(cache.totalBytes, live.bytes);
    live.release(discard: true);
    live.release(discard: true);
    expect(live.image.debugDisposed, true);
    expect(cache.totalBytes, 0);
  });

  test(
    'discard waits for the final shared lease in either release order',
    () async {
      final book = openFixture('images');
      final png = book.archive.bytes('EPUB/images/generated.png')!;
      book.archive.close();
      for (final discardFirst in [true, false]) {
        final cache = ReaderImageCache();
        final first = (await cache.lease(
          'shared',
          png,
          targetWidth: 64,
          targetHeight: 96,
        ))!;
        final last = (await cache.lease(
          'shared',
          png,
          targetWidth: 64,
          targetHeight: 96,
        ))!;
        expect(last.image, same(first.image));
        first.release(discard: discardFirst);
        first.release(discard: true);
        expect(last.image.debugDisposed, false);
        expect(cache.totalBytes, last.bytes);
        last.release(discard: !discardFirst);
        last.release();
        expect(last.image.debugDisposed, true);
        expect(cache.entryCount, 0);
        expect(cache.totalBytes, 0);
      }
    },
  );
}
