import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/pagination/section_preparer.dart';
import 'package:shiori/features/reader/engine/style/css_style_resolver.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';
import 'package:shiori/features/reader/engine/surface/page_surface_pool.dart';
import 'package:shiori/features/reader/engine/surface/reflow_section_cache.dart';

import 'publication_mixed_cache_test.dart' show mixedCachePublication;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cache hit protects delivery against an already queued miss', () async {
    final book = EpubBook.open(mixedCachePublication());
    addTearDown(book.archive.close);
    final pool = PageSurfacePool();
    final preparer = SectionPreparer();
    final preparations = <int>[];
    final cache = ReflowSectionCache(
      budget: pool.resourceBudget,
      prepare: (index) {
        preparations.add(index);
        final document = book.loadSection(index);
        return preparer.prepare(
          PrepareRequest(
            book: book,
            sectionIndex: index,
            document: document,
            styled: const CssStyleResolver().resolve(
              book,
              index,
              document,
              const ReaderSettings(),
            ),
            settings: const ReaderSettings(),
            viewportWidth: 400,
            viewportHeight: 600,
            contentId: 'delivery',
          ),
        );
      },
    )..pinned = pool.pinsSection;
    addTearDown(() async {
      await cache.drain();
      cache.dispose();
      pool.close();
      await pool.drained;
      expect(pool.resourceBudget.used.values.every((n) => n == 0), true);
    });
    final pins = [
      for (var i = 1; i <= 3; i++) pool.pinSection((await cache.load(i))!),
    ];
    addTearDown(() {
      for (final pin in pins) {
        pin.release();
      }
    });
    final cached = (await cache.load(4))!;
    await cache.drain();
    final miss = cache
        .load(5)
        .then<Object?>((s) => s, onError: (Object e) => e);
    final first = cache.load(4).then((section) {
      expect(section, same(cached));
      expect(section!.blocks.first.paragraph!.paragraph.debugDisposed, false);
      pins.add(pool.pinSection(section));
    });
    final second = cache.load(4).then((section) {
      expect(section!.blocks.first.paragraph!.paragraph.debugDisposed, false);
      pins.add(pool.pinSection(section));
    });
    await Future.wait([first, second]);
    expect(await miss, isA<SceneAdmissionException>());
    expect(cache.sections, hasLength(4));
    expect(pool.resourceBudget.used[SceneResource.paragraphs], 4);
    for (final pin in pins) {
      pin.release();
    }
    pins.clear();
    final leases = [for (var i = 1; i <= 4; i++) (await cache.borrow(i))!];
    final shared = (await cache.borrow(4))!;
    for (final lease in leases) {
      expect(
        lease.section.blocks.first.paragraph!.paragraph.debugDisposed,
        false,
      );
    }
    await expectLater(cache.load(5), throwsA(isA<SceneAdmissionException>()));
    leases.last.release();
    leases.last.release();
    await expectLater(cache.load(5), throwsA(isA<SceneAdmissionException>()));
    shared.release();
    final incoming = cache.borrow(5);
    final coalesced = cache.borrow(5);
    final firstLease = (await incoming)!;
    final secondLease = (await coalesced)!;
    expect(secondLease.section, same(firstLease.section));
    expect(preparations.where((i) => i == 5), hasLength(1));
    firstLease.release();
    await expectLater(cache.load(6), throwsA(isA<SceneAdmissionException>()));
    secondLease.release();
    expect(await cache.load(6), isNotNull);
    expect(cached.blocks.first.paragraph!.paragraph.debugDisposed, true);
    for (final lease in leases) {
      lease.release();
    }
    for (var i = 1; i <= 3; i++) {
      expect(await cache.load(i), isNotNull);
    }
    expect(cache.sections, hasLength(4));
  });

  test(
    'null, failed and closed deliveries release their request leases',
    () async {
      var preparations = 0;
      var fail = false;
      final cache = ReflowSectionCache(
        budget: SceneResourceBudget(),
        prepare: (_) async {
          preparations++;
          if (fail) throw StateError('preparation');
          return null;
        },
      );
      final first = cache.borrow(1);
      final second = cache.borrow(1);
      expect(await first, isNull);
      expect(await second, isNull);
      expect(preparations, 1);
      fail = true;
      await expectLater(cache.load(1), throwsStateError);
      fail = false;
      expect(await cache.borrow(1), isNull);
      final closing = cache.load(2);
      cache.dispose();
      expect(await closing, isNull);
      expect(await cache.borrow(1), isNull);
      await cache.drain();
      expect(cache.sections, isEmpty);
      expect(cache.budget.used.values.every((n) => n == 0), true);
    },
  );
}
