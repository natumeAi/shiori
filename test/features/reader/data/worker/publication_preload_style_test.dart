import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/data/resources/reader_resource_budget.dart';
import 'package:shiori/features/reader/data/worker/publication_tag.dart';
import 'package:shiori/features/reader/data/worker/publication_worker.dart';
import 'package:shiori/features/reader/engine/style/css_style_resolver.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';

void main() {
  final manifest = jsonDecode(
    File('assets/reader_fixtures/manifest.json').readAsStringSync(),
  ) as Map<String, Object?>;
  for (final value in manifest['fixtures']! as List<Object?>) {
    final fixture = value! as Map<String, Object?>;
    test(
      'worker detached source/styles match fixture ${fixture['id']}',
      () async {
        final file = File('assets/reader_fixtures/${fixture['file']}');
        final book = EpubBook.open(file.readAsBytesSync());
        final worker = await PublicationWorker.spawn();
        final budget = ReaderResourceBudget();
        try {
          await worker.open(file.path, const PublicationTag('style-parity'));
          for (final settings in [
            const ReaderSettings(),
            const ReaderSettings(fontSize: 26, lineHeight: 2),
          ]) {
            final loaded = await worker.preloadSection(
              0,
              settings: settings,
              budget: budget,
            );
            final expected = book.loadSection(0);
            final styles = const CssStyleResolver().resolve(
              book,
              0,
              expected,
              settings,
            );
            final plan = loaded.plan;
            expect(plan.document.nodes.length, expected.nodes.length);
            expect(plan.cfiBase, book.sections.first.spine.cfiBase);
            for (var i = 0; i < expected.nodes.length; i++) {
              final actual = plan.styled.styleOf(i);
              final wanted = styles.styleOf(i);
              expect(actual == null, wanted == null);
              if (actual == null || wanted == null) continue;
              expect(actual.fontSize, wanted.fontSize);
              expect(actual.fontFamilies, wanted.fontFamilies);
              expect(actual.writingMode, wanted.writingMode);
              expect(actual.direction, wanted.direction);
              expect(actual.display, wanted.display);
              expect(actual.width, wanted.width);
              expect(actual.height, wanted.height);
            }
            expect(
              () => plan.styled.rootStyle.fontFamilies.add('mutation'),
              throwsUnsupportedError,
            );
            expect(() => plan.lengths.clear(), throwsUnsupportedError);
            loaded.dispose();
            expect(budget.accountedBytes, 0);
          }
        } finally {
          await worker.close();
          book.archive.close();
        }
      },
    );
  }
}
