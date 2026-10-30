import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/layout/reading_unit.dart';
import 'package:shiori/features/reader/data/layout/reading_unit_navigator.dart';
import 'package:shiori/features/reader/data/layout/source_page_slot.dart';
import 'package:shiori/features/reader/data/worker/publication_layout_facts.dart';
import 'package:shiori/features/reader/engine/pagination/reading_unit_navigator.dart';

import '../../../tool/reader/fixed_layout_mixed_harness.dart';

List<String> _issues(PublicationLayoutFacts facts) {
  final names = <String>{};
  for (final section in facts.sections) {
    names.addAll(
      section
          .directionIssues(
            pageProgressionDirection: facts.pageProgressionDirection,
          )
          .map((issue) => issue.name),
    );
  }
  return names.toList()..sort();
}

UnsupportedProbe _refusedProbe(
  PublicationLayoutFacts facts,
  int composedUnitCount,
) => (
  outcome: 'refused',
  unitsProduced: 0,
  publishedUnits: 0,
  issues: _issues(facts),
  boundary: 'test seam: simulated composer refusal',
  reason: 'Test-only seam simulating the missing direction admission gate.',
);

UnsupportedProbe _acceptedProbe(
  PublicationLayoutFacts facts,
  int composedUnitCount,
) => (
  outcome: 'accepted',
  unitsProduced: composedUnitCount,
  publishedUnits: 0,
  issues: _issues(facts),
  boundary: null,
  reason: 'Deliberately wrong expectation: accepted an unsupported RTL book.',
);

Future<UnitNavigationResult> _wrongReverseSource(
  ComposedReadingUnitNavigator navigator,
  ReadingUnit origin,
  UnitDirection direction,
) async {
  final result = await navigator.adjacent(origin, direction);
  if (direction != UnitDirection.previous || result is! LocatedReadingUnit) {
    return result;
  }
  final unit = result.unit;
  final real = unit.slots.whereType<RealSourcePageSlot>().toList();
  if (real.length != 2 || unit.activeSource.sectionIndex != 3) return result;
  return LocatedReadingUnit(
    ReadingUnit(
      id: unit.id,
      kind: unit.kind,
      slots: unit.slots,
      activeSource: real.first.page,
    ),
  );
}

Map<String, Object?> _variant(Map<String, Object?> report, String id) =>
    (report['cases'] as List).cast<Map<String, Object?>>().singleWhere(
      (fixture) => fixture['id'] == id,
    );

Map<String, Object?> _check(Map<String, Object?> variant, String key) =>
    (variant['checks'] as Map<String, Object?>)[key]! as Map<String, Object?>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('real composition leaves RTL unsupported, and traversal asserts active sources', () async {
    final report = await FixedLayoutMixedHarness().run();
    expect(report['execution'], {'completed': true, 'variantCount': 4});
    expect((report['rowVerdict'] as Map)['verdict'], 'pass');
    expect((report['rowVerdict'] as Map)['failedChecks'], isEmpty);
    for (final id in [
      'mixed-navigation-positive',
      'mixed-navigation-boundary',
      'mixed-navigation-nested',
    ]) {
      final variant = _variant(report, id);
      for (final key in FixedLayoutMixedHarness.checkKeys) {
        expect(_check(variant, key)['status'], 'pass', reason: '$id:$key');
      }
    }
    final positive = _variant(report, 'mixed-navigation-positive');
    final positiveC = _check(positive, 'c');
    final details = (positiveC['details'] as Map).cast<String, Object?>();
    final forward = (details['forward'] as Map).cast<String, Object?>();
    final reverse = (details['reverse'] as Map).cast<String, Object?>();
    expect(forward['sources'], [0, 1, 2, 5]);
    expect(forward['expectedSources'], [0, 1, 2, 5]);
    expect(reverse['sources'], [5, 3, 1, 0]);
    expect(reverse['expectedSources'], [5, 3, 1, 0]);
    final sameSpread = (details['sameSpread'] as List).single as Map;
    expect(sameSpread['activeSources'], [2, 3]);
    expect(sameSpread['slotsUnchanged'], true);
    expect(
      ((details['entryRule'] as Map)['reference'] as String),
      contains('fixed-layout.js'),
    );
    final boundary = _variant(report, 'mixed-navigation-boundary');
    final boundaryDetails = (_check(boundary, 'c')['details'] as Map)
        .cast<String, Object?>();
    expect((boundaryDetails['forward'] as Map)['sources'], [0, 1, 2, 3, 5]);
    expect((boundaryDetails['reverse'] as Map)['sources'], [5, 3, 2, 1, 0]);
    expect((boundaryDetails['portrait'] as Map)['onePagePerUnit'], true);
    final unsupported = _variant(report, 'mixed-navigation-unsupported');
    final outcome = (unsupported['outcome'] as Map).cast<String, Object?>();
    expect(outcome['kind'], 'refused');
    expect(outcome['issues'], contains('rtlProgression'));
    expect(outcome['unitsProduced'], 0);
    expect(outcome['publishedUnits'], 0);
    expect(unsupported['units'], isEmpty);
    expect(_check(unsupported, 'e')['status'], 'pass');
  });
  test('test seams force unsupported acceptance and wrong reverse activation to fail', () async {
    final clean = await FixedLayoutMixedHarness(
      unsupportedProbe: _refusedProbe,
      writeReport: false,
    ).run();
    expect((clean['rowVerdict'] as Map)['verdict'], 'pass');

    final accepted = await FixedLayoutMixedHarness(
      unsupportedProbe: _acceptedProbe,
      writeReport: false,
    ).run();
    expect(
      _check(_variant(accepted, 'mixed-navigation-unsupported'), 'e')['status'],
      'fail',
    );
    expect((accepted['rowVerdict'] as Map)['verdict'], 'fail');

    final wrong = await FixedLayoutMixedHarness(
      unsupportedProbe: _refusedProbe,
      navigationSeam: _wrongReverseSource,
      writeReport: false,
    ).run();
    final wrongPositive = _variant(wrong, 'mixed-navigation-positive');
    expect(_check(wrongPositive, 'c')['status'], 'fail');
    expect(
      ((_check(wrongPositive, 'c')['details'] as Map)['reverse']
          as Map)['sources'],
      [5, 2, 1, 0],
    );
    expect((wrong['rowVerdict'] as Map)['verdict'], 'fail');
    expect(
      (wrong['rowVerdict'] as Map)['failedChecks'],
      anyElement(contains('mixed-navigation-positive:c')),
    );

    final copy = jsonDecode(jsonEncode(clean['cases'])) as List;
    final firstChecks = (copy.first as Map)['checks'] as Map;
    (firstChecks['a'] as Map)['status'] = 'fail';
    expect(
      FixedLayoutMixedHarness.rowVerdictFor(copy.cast<Map<String, Object?>>()),
      'fail',
    );
    expect((clean['rowVerdict'] as Map)['verdict'], 'pass');
  });
}
