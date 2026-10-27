import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/resources/archive_reader_resource_source.dart';
import 'package:shiori/features/reader/data/resources/reader_resource_budget.dart';
import 'package:shiori/features/reader/engine/pagination/section_preparer.dart';
import 'package:shiori/features/reader/engine/layout/layout_model.dart';
import 'package:shiori/features/reader/data/worker/publication_worker.dart';
import 'package:shiori/features/reader/engine/style/css_style_resolver.dart';
import 'package:shiori/features/reader/engine/style/computed_style.dart';

import '../../data/worker/import_test_support.dart';
import '../layout/layout_test_support.dart';
import 'guarded_resource_source.dart';
import 'resource_parity_snapshot.dart';

void main() {
  initEngineBinding();
  final manifest = jsonDecode(
    File('assets/reader_fixtures/manifest.json').readAsStringSync(),
  ) as Map<String, Object?>;
  for (final value in manifest['fixtures']! as List<Object?>) {
    final fixture = value! as Map<String, Object?>;
    final id = fixture['id']! as String;
    test('prepared archive/preloaded parity for all sections/settings: $id', () async {
      final file = File('assets/reader_fixtures/${fixture['file']}');
      final book = openFixture(id);
      final worker = await PublicationWorker.spawn();
      final budget = ReaderResourceBudget();
      try {
        await worker.prepare(file.path, identityFor(file));
        for (final settings in gateSettings.values) {
          for (var i = 0; i < book.sections.length; i++) {
            final document = book.loadSection(i);
            final styled = const CssStyleResolver().resolve(
              book,
              i,
              document,
              settings,
            );
            final expected = await SectionPreparer().prepare(
              PrepareRequest.resources(
                resources: ArchiveReaderResourceSource(book.archive),
                sectionHref: book.sections[i].item.href,
                sectionBase: book.sections[i].spine.cfiBase,
                sectionIndex: i,
                document: document,
                styled: styled,
                settings: settings,
                viewportWidth: phoneWidth,
                viewportHeight: phoneHeight,
                contentId: 'test-content',
              ),
            );
            final loaded = await worker.preloadSection(
              i,
              settings: settings,
              budget: budget,
            );
            for (var node = 0; node < document.nodes.length; node++) {
              expect(
                _style(loaded.plan.styled.styleOf(node)),
                _style(styled.styleOf(node)),
                reason: 'style node $node',
              );
            }
            final guarded = GuardedResourceSource(loaded.resources);
            final preparer = SectionPreparer();
            final actual = await preparer.prepare(
              PrepareRequest.resources(
                resources: guarded,
                sectionHref: loaded.plan.href,
                sectionBase: loaded.plan.cfiBase,
                sectionIndex: i,
                document: loaded.plan.document,
                styled: loaded.plan.styled,
                settings: settings,
                viewportWidth: phoneWidth,
                viewportHeight: phoneHeight,
                contentId: 'test-content',
              ),
            );
            try {
              expect(
                resourceParitySnapshot(actual),
                resourceParitySnapshot(expected),
                reason: '$id section $i',
              );
              List<Object?> runs(Iterable<TextBlock> blocks) => [
                for (final block in blocks)
                  [
                    block.text,
                    for (final run in block.runs)
                      [
                        run.start,
                        run.end,
                        run.scale,
                        run.placeholderWidth,
                        _style(run.style),
                      ],
                  ],
              ];
              expect(
                runs(actual.model.blocks.whereType<TextBlock>()),
                runs(expected.model.blocks.whereType<TextBlock>()),
              );
              // Exercise the later encoded read too, not just intrinsic sizing.
              for (var page = 0; page < actual.pageCount; page++) {
                await actual.ensureImages(page, preparer.images);
              }
              if (loaded.plan.styled.fontFaces.isNotEmpty) {
                expect(guarded.sizes, greaterThan(0));
              }
              expect(guarded.disposals, 0);
            } finally {
              actual.dispose();
              actual.dispose();
              preparer.images.clearUnleased();
              expected.dispose();
            }
            expect(guarded.disposals, 1);
            expect(budget.accountedBytes, 0);
          }
        }
      } finally {
        await worker.close();
        book.archive.close();
      }
    });
  }
}

Object? _style(ComputedStyle? value) => value == null
    ? null
    : [
        value.display,
        value.margin,
        value.padding,
        value.textIndent,
        value.textAlign,
        value.fontSize,
        value.fontWeight,
        value.fontStyle,
        value.fontFamilies,
        value.lineHeight,
        value.letterSpacing,
        value.color,
        value.backgroundColor,
        value.whiteSpace,
        value.verticalAlign,
        value.underline,
        value.lineThrough,
        value.overflowWrapAnywhere,
        value.width,
        value.height,
        value.maxWidth,
        value.maxHeight,
        value.writingMode,
        value.direction,
        value.breakBefore,
        value.breakAfter,
        value.listStyleType,
      ];
