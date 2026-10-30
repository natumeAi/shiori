import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/layout/reading_unit_navigator.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';

import 'publication_fixed_test_support.dart';

Uint8List mixedCachePublication() {
  final original = ZipDecoder().decodeBytes(
    fixedSidesPublication(List.filled(7, 'center')),
  );
  final archive = Archive();
  for (final file in original.files) {
    var bytes = file.content;
    if (file.name.endsWith('package.opf')) {
      var package = utf8.decode(bytes);
      for (var i = 1; i < 7; i++) {
        package = package.replaceFirst(
          'idref="p$i" linear="yes" properties="rendition:layout-pre-paginated',
          'idref="p$i" linear="yes" properties="rendition:layout-reflowable',
        );
      }
      bytes = utf8.encode(package);
    } else if (RegExp(r'EPUB/[ps][1-6]\.xhtml$').hasMatch(file.name)) {
      bytes = utf8.encode(
        '<html xmlns="http://www.w3.org/1999/xhtml"><body>'
        '<p id="target">${List.filled(100, 'Bounded reader text. ').join()}</p>'
        '</body></html>',
      );
    }
    archive.addFile(ArchiveFile(file.name, bytes.length, bytes));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'queued miss cannot destroy a pending cached composition delivery',
    () async {
      final h = await PublicationFixedHarness.open(mixedCachePublication());
      final pins = [
        for (var i = 1; i <= 3; i++)
          h.pool.pinSection((await h.composition.loadReflow(i))!),
      ];
      final cached = (await h.composition.loadReflow(4))!;
      await h.composition.drain();
      final miss = h.composition.loadReflow(5);
      final outcome = miss.then<Object?>((s) => s, onError: (Object e) => e);
      final hit = h.composition.loadReflow(4).then((section) {
        expect(section, same(cached));
        expect(section!.blocks.first.paragraph!.paragraph.debugDisposed, false);
        pins.add(h.pool.pinSection(section));
      });
      try {
        await hit;
        expect(await outcome, isA<SceneAdmissionException>());
        expect(h.composition.reflowSections, hasLength(4));
        expect(h.pool.resourceBudget.used[SceneResource.paragraphs], 4);
      } finally {
        for (final pin in pins) {
          pin.release();
        }
      }
      expect(await h.composition.loadReflow(5), isNotNull);
    },
  );

  test(
    'queued misses let a delivered borrower pin before another eviction',
    () async {
      final h = await PublicationFixedHarness.open(mixedCachePublication());
      final pins = [
        for (var i = 3; i <= 5; i++)
          h.pool.pinSection((await h.composition.loadReflow(i))!),
      ];
      try {
        final first = h.composition.loadReflow(1).then((section) {
          pins.add(h.pool.pinSection(section!));
        });
        final second = h.composition.loadReflow(2);
        final refusal = expectLater(
          second,
          throwsA(isA<SceneAdmissionException>()),
        );
        await first;
        await refusal;
        expect(h.composition.reflowSections.containsKey(1), true);
        expect(h.composition.reflowSections, hasLength(4));
      } finally {
        for (final pin in pins) {
          pin.release();
        }
      }
    },
  );

  test(
    'mixed composition retains at most four prepared reflow sections',
    () async {
      final h = await PublicationFixedHarness.open(mixedCachePublication());
      expect(h.composition.navigator.sections, hasLength(7));
      expect(h.composition.reflowSections.length, lessThanOrEqualTo(4));
      for (var i = 1; i < 7; i++) {
        expect(await h.composition.loadReflow(i), isNotNull);
        expect(h.composition.reflowSections.length, lessThanOrEqualTo(4));
      }
    },
  );

  test(
    'cached paragraphs stay charged without surfaces and release on close',
    () async {
      final h = await PublicationFixedHarness.open(mixedCachePublication());
      expect(h.pool.liveSurfaces, 0);
      final paragraphs = h.composition.reflowSections.values.fold<int>(
        0,
        (sum, section) =>
            sum + section.blocks.where((b) => b.paragraph != null).length,
      );
      expect(paragraphs, greaterThan(0));
      expect(h.pool.resourceBudget.used[SceneResource.paragraphs], paragraphs);
      h.composition.dispose();
      expect(h.pool.resourceBudget.used.values.every((n) => n == 0), true);
    },
  );

  test(
    'evicted reflow targets reload and live surface pins prevent eviction',
    () async {
      final h = await PublicationFixedHarness.open(mixedCachePublication());
      final section = (await h.composition.loadReflow(1))!;
      final pin = h.pool.pinSection(section);
      try {
        for (var i = 2; i < 7; i++) {
          await h.composition.loadReflow(i);
        }
        expect(await h.composition.loadReflow(1), same(section));
        expect(h.composition.reflowSections.length, lessThanOrEqualTo(4));
        final href = h.composition.navigator.sections[2].href;
        final target = await h.composition.navigator.forTocTarget(
          '$href#target',
        );
        expect(target, isA<LocatedReadingUnit>());
        expect(
          (target as LocatedReadingUnit).unit.activeSource.sectionIndex,
          2,
        );
      } finally {
        pin.release();
      }
    },
  );

  test(
    'four pinned sections refuse another preparation until release',
    () async {
      final h = await PublicationFixedHarness.open(mixedCachePublication());
      final pins = [
        for (var i = 1; i <= 4; i++)
          h.pool.pinSection((await h.composition.loadReflow(i))!),
      ];
      try {
        await expectLater(
          h.composition.loadReflow(5),
          throwsA(isA<SceneAdmissionException>()),
        );
        expect(h.composition.reflowSections, hasLength(4));
        expect(h.pool.resourceBudget.used[SceneResource.paragraphs], 4);
      } finally {
        for (final pin in pins) {
          pin.release();
        }
      }
      expect(await h.composition.loadReflow(5), isNotNull);
      expect(h.composition.reflowSections, hasLength(4));
      expect(h.pool.resourceBudget.used[SceneResource.paragraphs], 4);
    },
  );
}
