@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/engine/pagination/section_preparer.dart';

import '../layout/layout_test_support.dart';

/// Long-content shape checks and an indicative HOST-ONLY timing of the
/// 100,000-character paragraph. The numbers come from the Flutter test
/// engine on the development machine with its Ahem test font (every glyph a
/// square), so they say nothing about iPhone cost; the device run owns that.
void main() {
  initEngineBinding();

  test('the long chapter spans at least 30 pages and the CJK paragraph '
      'lays out once', () async {
    final book = openFixture('long-content');
    final preparer = SectionPreparer();
    final chapter = await prepareSection(
      book,
      0,
      preparer: preparer,
      resolver: fixtureResolver(),
    );
    expect(chapter.pageCount, greaterThanOrEqualTo(30));
    chapter.dispose();

    final runs = <int>[];
    final totals = <int>[];
    var lines = 0;
    var pages = 0;
    var units = 0;
    for (var i = 0; i < 5; i++) {
      final watch = Stopwatch()..start();
      final section = await prepareSection(
        book,
        1,
        preparer: preparer,
        resolver: fixtureResolver(),
      );
      final cost = section.paragraphCosts.reduce(
        (a, b) => a.codeUnits >= b.codeUnits ? a : b,
      );
      totals.add(watch.elapsedMilliseconds);
      runs.add(cost.layoutMicros);
      lines = cost.lines;
      units = cost.codeUnits;
      pages = section.pageCount;
      section.dispose();
    }
    runs.sort();
    totals.sort();
    expect(units, greaterThanOrEqualTo(100000));
    expect(lines, greaterThan(1000));
    // ignore: avoid_print, counts only; no logger in tests.
    print(
      'HOST-ONLY indicative: $units code units -> layout median '
      '${runs[runs.length ~/ 2]} us (min ${runs.first}, max ${runs.last}); '
      'whole section preparation (layout + line table + paging) median '
      '${totals[totals.length ~/ 2]} ms; '
      '$lines lines, $pages pages; font: Flutter test default (Ahem)',
    );
  });
}
