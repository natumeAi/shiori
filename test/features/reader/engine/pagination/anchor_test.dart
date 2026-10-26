@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/data/source/source_node.dart';
import 'package:shiori/features/reader/engine/pagination/anchor.dart';
import 'package:shiori/features/reader/engine/pagination/prepared_section.dart';
import 'package:shiori/features/reader/engine/pagination/section_preparer.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';

import '../layout/layout_test_support.dart';

const _fixtures = [
  'cfi-structure',
  'html-fallback',
  'inert-content',
  'opf-variants',
  'unicode',
  'styles',
  'images',
  'long-content',
  'chapters',
  'one-page',
];

void main() {
  initEngineBinding();
  final preparer = SectionPreparer();

  for (final id in _fixtures) {
    test(
      'every page of $id exports an anchor that resolves back to it',
      () async {
        final book = openFixture(id);
        var anchors = 0;
        for (final setting in gateSettings.entries) {
          for (var i = 0; i < book.sections.length; i++) {
            final section = await prepareSection(
              book,
              i,
              preparer: preparer,
              resolver: fixtureResolver(),
              settings: setting.value,
            );
            final service = PageAnchors(section);
            for (final page in section.pages) {
              final anchor = service.exportVisible(page.index);
              final hasContent =
                  page.map.spans.isNotEmpty || page.map.imageNodes.isNotEmpty;
              if (anchor == null) {
                // A page without text or images has nothing to anchor.
                expect(
                  hasContent,
                  isFalse,
                  reason: '$id#$i ${setting.key} page ${page.index}',
                );
                continue;
              }
              anchors++;
              final proof = service.prove(
                anchor.cfi,
                expectedIdentity: section.identity,
              );
              expect(proof.ok, isTrue, reason: '$id#$i page ${page.index}');
              expect(proof.pageIndex, page.index);
            }
            section.dispose();
          }
        }
        // ignore: avoid_print, counts only; no logger in tests.
        print('$id: $anchors page anchors proven');
        expect(anchors, greaterThan(0));
      },
    );
  }

  test('WebKit oracle CFIs land on a page where they are visible', () async {
    var checked = 0;
    var skippedNotRendered = 0;
    for (final id in _fixtures) {
      final vectors = jsonDecode(
        File('test/fixtures/reader/oracle/$id.webkit.json').readAsStringSync(),
      ) as Map<String, Object?>;
      final book = openFixture(id);
      final sections = vectors['sections']! as List<Object?>;
      for (var i = 0; i < book.sections.length; i++) {
        final section = await prepareSection(
          book,
          i,
          preparer: preparer,
          resolver: fixtureResolver(),
        );
        final service = PageAnchors(section);
        final samples =
            (sections[i]! as Map<String, Object?>)['samples']! as List<Object?>;
        for (final raw in samples) {
          final sample = raw! as Map<String, Object?>;
          final resolved = sample['resolved']! as Map<String, Object?>;
          final start = resolved['start']! as Map<String, Object?>;
          final node = start['node']! as int;
          final offset = start['offset']! as int;
          final cfi = sample['cfi']! as String;
          final isText =
              node >= 0 &&
              section.document.node(node).kind == SourceNodeKind.text;
          final laidOut = isText
              ? section.nodeBlock.containsKey(node)
              : section.imageBlock.containsKey(node);
          if (!laidOut) {
            skippedNotRendered++;
            continue;
          }
          final proof = service.prove(cfi, expectedIdentity: section.identity);
          expect(
            proof.ok,
            isTrue,
            reason: '$id#$i node $node offset $offset: ${proof.failure?.name}',
          );
          if (isText) {
            final page = section.pages[proof.pageIndex!];
            final shown = page.map.spans.any(
              (span) =>
                  span.nodeIndex == node &&
                  offset >= span.start &&
                  offset <= span.end,
            );
            expect(shown, isTrue, reason: '$id#$i node $node offset $offset');
          }
          checked++;
        }
        section.dispose();
      }
    }
    // ignore: avoid_print, counts only; no logger in tests.
    print(
      'oracle CFIs proven: $checked, not rendered (hidden/head): '
      '$skippedNotRendered',
    );
    expect(checked, greaterThan(100));
  });

  group('reflow and failure handling', () {
    late EpubBook book;
    setUp(() => book = openFixture('long-content'));

    Future<PreparedSection> prepared(
      ReaderSettings settings, {
      int generation = 0,
    }) => prepareSection(
      book,
      0,
      preparer: preparer,
      resolver: fixtureResolver(),
      settings: settings,
      generation: generation,
    );

    test('the accepted anchor stays visible after font size and line height '
        'changes', () async {
      var section = await prepared(const ReaderSettings());
      final keeper = AnchorKeeper();
      final middle = section.pageCount ~/ 2;
      final accepted = keeper.acceptPage(section, middle);
      expect(accepted, isNotNull);
      final cfi = keeper.acceptedCfi;
      var generation = 0;
      for (final settings in const [
        ReaderSettings(fontSize: 22),
        ReaderSettings(fontSize: 22, lineHeight: 2.0),
        ReaderSettings(fontSize: 14, lineHeight: 1.3, letterSpacing: 0.08),
        ReaderSettings(horizontalMargin: 36, verticalMargin: 24),
      ]) {
        section.dispose();
        generation++;
        section = await prepared(settings, generation: generation);
        final proof = keeper.reflow(section);
        expect(proof.ok, isTrue, reason: settings.fontSize.toString());
        expect(keeper.acceptedCfi, cfi, reason: 'reflow must not rewrite it');
        final page = section.pages[proof.pageIndex!];
        expect(PageAnchors(section).exportVisible(proof.pageIndex!), isNotNull);
        expect(page.map.spans, isNotEmpty);
      }
      section.dispose();
    });

    test('an injected proof failure keeps the previous anchor', () async {
      final section = await prepared(const ReaderSettings());
      var fail = false;
      final keeper = AnchorKeeper(
        proofHook: (_, _) => fail ? AnchorFailure.injected : null,
      );
      expect(keeper.acceptPage(section, 3), isNotNull);
      final before = keeper.acceptedCfi;

      fail = true;
      expect(keeper.acceptPage(section, 7), isNull);
      expect(keeper.acceptedCfi, before);

      fail = false;
      final other = PageAnchors(section).exportVisible(9)!;
      fail = true;
      final proof = keeper.accept(section, other.cfi);
      expect(proof.failure, AnchorFailure.injected);
      expect(keeper.acceptedCfi, before);

      expect(keeper.reflow(section).failure, AnchorFailure.injected);
      expect(keeper.acceptedCfi, before);

      fail = false;
      expect(keeper.accept(section, other.cfi).ok, isTrue);
      expect(keeper.acceptedCfi, other.cfi);
      section.dispose();
    });

    test(
      'failures are explicit and never fall back to another position',
      () async {
        final section = await prepared(const ReaderSettings());
        final anchors = PageAnchors(section);
        final good = anchors.exportVisible(2)!;

        expect(anchors.prove('not a cfi').failure, AnchorFailure.unresolved);
        expect(
          anchors.prove('epubcfi(/6/2[x]!/99/99/1:0)').failure,
          isIn([AnchorFailure.unresolved, AnchorFailure.roundTrip]),
        );
        // A different layout identity (stale generation) is rejected.
        final other = await prepared(const ReaderSettings(), generation: 5);
        expect(
          PageAnchors(other)
              .prove(good.cfi, expectedIdentity: section.identity)
              .failure,
          AnchorFailure.identityMismatch,
        );
        other.dispose();

        final keeper = AnchorKeeper()..acceptPage(section, 2);
        final accepted = keeper.acceptedCfi;
        expect(keeper.accept(section, 'epubcfi(/6/2!/4/99:0)').ok, isFalse);
        expect(keeper.acceptedCfi, accepted);
        section.dispose();
      },
    );
  });
}
