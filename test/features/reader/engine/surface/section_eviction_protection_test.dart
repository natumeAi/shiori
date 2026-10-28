import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/diagnostics/data/reader_preparation_repository.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';
import 'package:shiori/features/reader/engine/surface/page_surface_pool.dart';

import '../../../../helpers/reader_probe_fixtures.dart';
import '../../contract_test_values.dart';
import '../layout/layout_test_support.dart';
import 'surface_test_support.dart';

void main() {
  initEngineBinding();
  test('existing four-section cache honors live and pending pool pins', () async {
    final book = EpubBook.open(
      buildEpub(
        sections: {
          for (var i = 0; i < 6; i++)
            's$i.xhtml': xhtml('<p>Page $i alpha beta.</p>'),
        },
      ),
    );
    final recorder = readerRecorder(capacity: 64);
    final owner = ReaderPreparationRepository(
      book: book,
      digest: contractContent().sha256,
      settings: const ReaderSettings(),
      width: 400,
      height: 600,
      dpr: 1,
      generation: 1,
      recorder: recorder,
    );
    final pool = PageSurfacePool();
    // This uses the real existing cache's supported pin callback. Product
    // wiring belongs to its owner; the pool never edits or disposes its cache.
    owner.pinned = pool.pinsSection;
    final current = (await owner.load(0))!;
    final pending = pool.prepare(current, 0, surfaceTheme);
    expect(pool.pinsSection(current), isTrue);
    final lease = (await pending)!;
    final retained = lease.retain();
    lease.release();
    for (var i = 1; i < 6; i++) {
      await owner.load(i);
      expect(pool.pinsSection(current), isTrue);
      expect(retained.surface.picture.debugDisposed, isFalse);
    }
    // A cache miss would construct another PreparedSection after disposal.
    expect(await owner.load(0), same(current));
    retained.release();
    retained.release();
    expect(pool.pinsSection(current), isFalse);
    pool.close();
    await owner.close();
    recorder.dispose();
  });
}
