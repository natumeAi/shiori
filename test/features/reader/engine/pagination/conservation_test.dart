@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/engine/layout/layout_model.dart';
import 'package:shiori/features/reader/engine/pagination/conservation.dart';
import 'package:shiori/features/reader/engine/pagination/section_preparer.dart';

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
    for (final setting in gateSettings.entries) {
      test('conservation $id @ ${setting.key}', () async {
        final book = openFixture(id);
        for (var i = 0; i < book.sections.length; i++) {
          final resolver = fixtureResolver();
          final document = book.loadSection(i);
          final styled = resolver.resolve(book, i, document, setting.value);
          final section = await prepareSection(
            book,
            i,
            preparer: preparer,
            resolver: resolver,
            settings: setting.value,
          );
          final report = checkConservation(section, styled);
          // ignore: avoid_print, counts only; no logger in tests.
          print(
            '$id#$i ${setting.key}: pages=${report.pages} lines=${report.lines} chars=${report.sourceCharacters} images=${report.images} surfaced=${report.surfacedUnsupported} ok=${report.ok}',
          );
          expect(report.failures, isEmpty, reason: '$id#$i');
          if (id == 'styles') {
            final texts = section.blocks
                .map((b) => b.block)
                .whereType<TextBlock>()
                .map((b) => b.text)
                .toList();
            expect(texts.any((t) => t.startsWith('• ')), isTrue);
            expect(texts.any((t) => t.startsWith('◦ ')), isTrue);
            expect(texts.any((t) => t.startsWith('3. ')), isTrue);
          }
          section.dispose();
        }
      });
    }
  }
}
