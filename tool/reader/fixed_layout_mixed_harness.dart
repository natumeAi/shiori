import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:shiori/features/reader/data/cfi/cfi.dart';
import 'package:shiori/features/reader/data/layout/authored_dimension_resolver.dart';
import 'package:shiori/features/reader/data/layout/reading_unit.dart';
import 'package:shiori/features/reader/data/layout/reading_unit_navigator.dart';
import 'package:shiori/features/reader/data/layout/reading_unit_section.dart';
import 'package:shiori/features/reader/data/layout/section_source_facts.dart';
import 'package:shiori/features/reader/data/layout/source_page_slot.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/source/source_position.dart';
import 'package:shiori/features/reader/data/worker/publication_import_facts.dart';
import 'package:shiori/features/reader/data/worker/publication_layout_facts.dart';
import 'package:shiori/features/reader/engine/pagination/reading_unit_composer.dart';
import 'package:shiori/features/reader/engine/pagination/reading_unit_navigator.dart';
import 'package:shiori/features/reader/engine/support/layout_flags.dart';

import '../../test/features/reader/data/layout/fixed_layout_test_support.dart';
import '../../test/features/reader/engine/pagination/reading_unit_test_support.dart';
import '../../test/features/reader/engine/surface/fixed_session_test_support.dart';

const _row = 'mixed-navigation';
const _caseIds = [
  'mixed-navigation-positive',
  'mixed-navigation-boundary',
  'mixed-navigation-nested',
  'mixed-navigation-unsupported',
];
const _checkKeys = ['a', 'b', 'c', 'd', 'e'];
const _criterion =
    'source/spine order and CFI exact; blank has no source; no fixed/reflow pair';
const _requirement =
    'research/rendering-plan.md section 3 row "Mixed navigation": a reading '
    'unit never pairs a reflow page with a fixed page; adjacent traversal and '
    'explicit TOC navigation preserve their separate reference rules.';

typedef NavigationSeam = Future<UnitNavigationResult> Function(
  ComposedReadingUnitNavigator navigator,
  ReadingUnit origin,
  UnitDirection direction,
);

/// What the real rendition/composition path yielded for the unsupported case.
typedef UnsupportedProbe = ({
  String outcome,
  int unitsProduced,
  int? publishedUnits,
  List<String> issues,
  String? boundary,
  String reason,
});

typedef UnsupportedProbeSeam = UnsupportedProbe Function(
  PublicationLayoutFacts facts,
  int composedUnitCount,
);

/// A row passes only when every case has a pass or an explicit non-applicable
/// check. Execution success is deliberately not part of this decision.
String mixedRowVerdictFor(List<Map<String, Object?>> variants) {
  if (variants.length != _caseIds.length) return 'fail';
  final ids = {for (final variant in variants) variant['id']};
  if (!_caseIds.every(ids.contains)) return 'fail';
  for (final variant in variants) {
    final checks = variant['checks'];
    if (checks is! Map) return 'fail';
    final unsupported = variant['id'] == 'mixed-navigation-unsupported';
    for (final key in _checkKeys) {
      final check = checks[key];
      if (check is! Map) return 'fail';
      final status = check['status'];
      final wanted = unsupported && key != 'e' ? 'not-applicable' : 'pass';
      if (status != wanted) return 'fail';
    }
  }
  return 'pass';
}

Map<String, Object?> _check(
  String status, {
  Map<String, Object?> details = const {},
  List<String> failures = const [],
}) => {
  'status': status,
  'pass': status == 'pass',
  'details': details,
  'failures': failures,
};

Map<String, Object?> _notApplicable(String reason) =>
    _check('not-applicable', details: {'reason': reason});

bool _sameList<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _sameSlots(
  List<Map<String, Object?>> actual,
  List<Map<String, Object?>> expected,
) {
  if (actual.length != expected.length) return false;
  for (var i = 0; i < actual.length; i++) {
    if (actual[i]['index'] != expected[i]['index'] ||
        actual[i]['side'] != expected[i]['side'] ||
        actual[i]['source'] != expected[i]['source']) {
      return false;
    }
  }
  return true;
}

List<Map<String, Object?>> _unitSummary(ComposedReadingUnitNavigator nav) => [
  for (var i = 0; i < nav.units.length; i++)
    {
      'index': i,
      'unit': nav.units[i].id.stableId,
      'kind': nav.units[i].kind.name,
      'activeSource': nav.units[i].activeSource.sectionIndex,
      'slots': [
        for (final slot in nav.units[i].slots)
          if (slot is BlankSourcePageSlot)
            {'blank': true, 'source': null, 'mode': null, 'side': null}
          else
            {
              'blank': false,
              'source': (slot as RealSourcePageSlot).page.sectionIndex,
              'mode': slot.mode.name,
              'side': slot.side.name,
            },
      ],
    },
];

/// Mixed-navigation host experiment. The report's row verdict is independent
/// of process success; this harness claims no fidelity or device acceptance.
final class FixedLayoutMixedHarness {
  FixedLayoutMixedHarness({
    this.navigationSeam,
    this.unsupportedProbe,
    this.writeReport = true,
  });
  final NavigationSeam? navigationSeam;
  final UnsupportedProbeSeam? unsupportedProbe;
  final bool writeReport;

  static const output = 'build/fixed-layout-mixed';
  static const row = _row;
  static const caseIds = _caseIds;
  static const checkKeys = _checkKeys;
  static String rowVerdictFor(List<Map<String, Object?>> variants) =>
      mixedRowVerdictFor(variants);

  Future<Map<String, Object?>> run() async {
    final corpusBytes = File('test/fixtures/reader/fixed_layout/corpus.json')
        .readAsBytesSync();
    final oracleBytes = File('test/fixtures/reader/fixed_layout/oracle.json')
        .readAsBytesSync();
    final corpus = jsonDecode(utf8.decode(corpusBytes)) as Map<String, Object?>;
    final oracle = jsonDecode(utf8.decode(oracleBytes)) as Map<String, Object?>;
    if (oracle['corpusSHA256'] != sha256.convert(corpusBytes).toString()) {
      throw StateError('Oracle does not match the exact corpus bytes');
    }
    final fixtureCases = (corpus['cases'] as List)
        .map(jsonObject)
        .where((fixture) => fixture['row'] == _row)
        .toList();
    final references = {
      for (final reference in (oracle['cases'] as List).map(jsonObject))
        reference['id']: reference,
    };
    final variants = <Map<String, Object?>>[];
    for (final id in _caseIds) {
      final fixture = fixtureCases.where((c) => c['id'] == id).single;
      variants.add(await _measure(fixture, references[id]!));
    }
    final degraded = <String>[];
    final differences = <Map<String, Object?>>[];
    for (final variant in variants) {
      for (final key in (variant['failingChecks'] as List).cast<String>()) {
        degraded.add('${variant['id']}:$key');
      }
      differences.addAll(
        (variant['namedDifferences'] as List).cast<Map<String, Object?>>(),
      );
    }
    final report = <String, Object?>{
      'schemaVersion': 1,
      'evidence': 'host-native-mixed-navigation-no-device-claim',
      'corpusSHA256': sha256.convert(corpusBytes).toString(),
      'oracleSHA256': sha256.convert(oracleBytes).toString(),
      'rowVerdict': {
        'row': _row,
        'criterion': _criterion,
        'requirement': _requirement,
        'verdict': mixedRowVerdictFor(variants),
        'failedChecks': degraded,
        'namedDifferences': differences,
      },
      'execution': {'completed': true, 'variantCount': variants.length},
      'cases': variants,
    };
    if (writeReport) {
      Directory(output).createSync(recursive: true);
      File(
        '$output/report.json',
      ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
    }
    return report;
  }

  Future<Map<String, Object?>> _measure(
    Map<String, Object?> fixture,
    Map<String, Object?> reference,
  ) async {
    final id = fixture['id'] as String;
    final expectedCapability = fixture['expectedCapability'] as String;
    final session = FixedSessionFixture(caseId: id);
    try {
      final metadata = importMetadata(
        session.book.archive,
        session.book.package.opfPath,
      );
      final facts = importLayoutFacts(
        session.book,
        metadata,
        0,
        session.documents[0]!,
      );
      final issues = _directionIssues(facts);
      if (expectedCapability == 'unsupported') {
        final issuesBySection = {
          for (final section in facts.sections)
            section.sectionIndex: section.directionIssues(
              pageProgressionDirection: facts.pageProgressionDirection,
            ),
        };
        final probeSections = [
          for (var i = 0; i < session.book.sections.length; i++)
            ReadingUnitSection(
              page: session.page(i),
              href: session.book.sections[i].item.href,
              rendition: sectionRendition(session.book, i),
              linear: session.book.sections[i].spine.isLinear,
              layoutKey: 'unsupported-probe-$i',
              dimensions: sectionRendition(session.book, i).isFixed == true
                  ? resolveAuthoredDimensions(
                      source: extractSectionSourceFacts(session.documents[i]!),
                      packageRendition: session.book.package.rendition,
                    )
                  : null,
              directionIssues: issuesBySection[i] ?? const {},
            ),
        ];
        ComposedReadingUnitNavigator? guarded;
        UnsupportedDirectionCompositionException? refusal;
        try {
          guarded = ComposedReadingUnitNavigator(
            sections: probeSections,
            viewportWidth: session.width,
            viewportHeight: session.height,
            documents: {
              for (var i = 0; i < session.book.sections.length; i++)
                session.page(i): session.documents[i]!,
            },
            locateReflow: (_, _) => 0,
          );
        } on UnsupportedDirectionCompositionException catch (error) {
          refusal = error;
        }
        final UnsupportedProbe realProbe = refusal == null
            ? (
                outcome: 'composed-unsupported',
                unitsProduced: guarded!.units.length,
                publishedUnits: null,
                issues: issues,
                boundary:
                    'none in ReadingUnitComposer/ComposedReadingUnitNavigator; '
                    'session/fixed publication not exercised',
                reason:
                    'The production composer composed ${guarded.units.length} '
                    'candidate units despite direction issues.',
              )
            : (
                outcome: 'refused',
                unitsProduced: 0,
                publishedUnits: 0,
                issues: [for (final issue in refusal.issues) issue.name]
                  ..sort(),
                boundary:
                    'ReadingUnitComposer.plan -> '
                    'UnsupportedDirectionCompositionException',
                reason: refusal.reason,
              );
        final probe =
            unsupportedProbe?.call(facts, realProbe.unitsProduced) ?? realProbe;
        final e = _unsupportedCheck(expectedCapability, probe);
        final checks = <String, Map<String, Object?>>{
          'a': _notApplicable(
            'typed direction refusal produced ${probe.unitsProduced} units; '
            'source invariants are not accepted for an unsupported publication',
          ),
          'b': _notApplicable(
            'typed direction refusal produced ${probe.unitsProduced} units; '
            'reference slots are not accepted',
          ),
          'c': _notApplicable(
            'typed direction refusal produced ${probe.unitsProduced} units; '
            'navigation is not accepted',
          ),
          'd': _notApplicable(
            'typed direction refusal produced ${probe.unitsProduced} units; '
            'CFI acceptance is not claimed',
          ),
          'e': e,
        };
        return {
          'id': id,
          'row': _row,
          'variant': fixture['variant'],
          'expectedCapability': expectedCapability,
          'outcome': {
            'kind': probe.outcome,
            'issues': probe.issues,
            'unitsProduced': probe.unitsProduced,
            'publishedUnits': probe.publishedUnits,
            'partialSuccess':
                probe.publishedUnits != null && probe.publishedUnits! > 0,
            'boundary': probe.boundary,
            'reason': probe.reason,
          },
          'units': guarded == null || probe.outcome == 'refused'
              ? <Object?>[]
              : _unitSummary(guarded),
          'checks': checks,
          'namedDifferences': [
            {
              'kind': 'typed-unsupported-outcome',
              'requirement': _requirement,
              'criterion': fixture['criterion'] ?? _criterion,
              'expectedCapability': expectedCapability,
              'typedOutcome': {
                'kind': probe.outcome,
                'issues': probe.issues,
                'reason': probe.reason,
              },
              'unitsProduced': probe.unitsProduced,
              'publishedUnits': probe.publishedUnits,
              'boundary': probe.boundary,
              'reason': probe.reason,
            },
          ],
          'failingChecks': _failing(checks),
        };
      }
      await session.prepareNavigation();
      final nav = session.navigator;
      final probe = (
        outcome: 'composed',
        unitsProduced: nav.units.length,
        publishedUnits: null,
        issues: issues,
        boundary: null,
        reason: 'Required variant composed through the production path.',
      );
      final a = _spineCheck(session, nav);
      final b = _referenceSlotCheck(
        session,
        nav,
        reference,
        fixture['criterion'] as String? ?? _criterion,
      );
      final c = await _navigationCheck(session, nav, seam: navigationSeam);
      final d = _cfiCheck(session, nav);
      final e = _unsupportedCheck(expectedCapability, probe);
      final checks = <String, Map<String, Object?>>{
        'a': a,
        'b': b,
        'c': c,
        'd': d,
        'e': e,
      };
      final bDetails = b['details']! as Map<String, Object?>;
      final reflowDifferences = (bDetails['reflowDifferences'] as List)
          .cast<Map<String, Object?>>();
      return {
        'id': id,
        'row': _row,
        'variant': fixture['variant'],
        'expectedCapability': expectedCapability,
        'outcome': {
          'kind': 'composed',
          'unitCount': nav.units.length,
          'sourceCount': nav.units.fold<int>(
            0,
            (sum, unit) => sum + unit.realSourceCount,
          ),
          'issues': issues,
        },
        'units': _unitSummary(nav),
        'checks': checks,
        'namedDifferences': reflowDifferences
            .where((difference) => difference['sideChanged'] == true)
            .toList(),
        'failingChecks': _failing(checks),
      };
    } finally {
      session.dispose();
    }
  }
}

List<String> _failing(Map<String, Map<String, Object?>> checks) => [
  for (final key in _checkKeys)
    if (checks[key]!['status'] == 'fail') key,
];

Map<String, Object?> _spineCheck(
  FixedSessionFixture session,
  ComposedReadingUnitNavigator nav,
) {
  final failures = <String>[];
  final realSources = <Map<String, Object?>>[];
  var blankSlots = 0;
  for (var i = 0; i < nav.units.length; i++) {
    final unit = nav.units[i];
    final modes = <String>{};
    for (final slot in unit.slots) {
      if (slot is BlankSourcePageSlot) {
        blankSlots++;
        continue;
      }
      final real = slot as RealSourcePageSlot;
      modes.add(real.mode.name);
      realSources.add({
        'unit': i,
        'source': real.page.sectionIndex,
        'spine': real.page.spineIndex,
        'mode': real.mode.name,
        'side': real.side.name,
      });
    }
    if (modes.length > 1) {
      failures.add('unit $i pairs ${modes.join('/')} sources');
    }
    if (unit.kind == ReadingUnitKind.reflowPage &&
        !modes.contains('reflowable')) {
      failures.add('unit $i is not reflow-composed');
    }
    if (unit.kind != ReadingUnitKind.reflowPage && !modes.contains('fixed')) {
      failures.add('unit $i is not fixed-composed');
    }
  }
  final sources = [for (final source in realSources) source['source'] as int];
  final expectedSources = [
    for (final section in nav.sections) section.page.sectionIndex,
  ];
  if (!_sameList(sources, expectedSources)) {
    failures.add('real sources are not in filtered spine order: $sources');
  }
  if (sources.toSet().length != sources.length) {
    failures.add('a real source appears more than once');
  }
  final spines = [for (final source in realSources) source['spine'] as int];
  final expectedSpines = [
    for (final section in nav.sections) section.page.spineIndex,
  ];
  if (!_sameList(spines, expectedSpines)) {
    failures.add('real sources are not in original spine order: $spines');
  }
  final blankProbe = _blankProbe();
  if (blankProbe['pass'] != true) {
    failures.add('synthetic padded spread does not keep its blank source-free');
  }
  return _check(
    failures.isEmpty ? 'pass' : 'fail',
    details: {
      'sectionCount': session.book.sections.length,
      'realSources': realSources,
      'sourceOrder': sources,
      'spineOrder': spines,
      'blankSlots': blankSlots,
      'blankSlotType': 'BlankSourcePageSlot',
      'blankSlotsCarryNoSource': true,
      'syntheticBlankProbe': blankProbe,
    },
    failures: failures,
  );
}

Map<String, Object?> _blankProbe() {
  final unit = const ReadingUnitComposer()
      .compose(
        [unitSection(0, side: 'right')],
        viewportWidth: 900,
        viewportHeight: 600,
      )
      .single;
  final blank = unit.slots.first;
  final real = unit.slots.last;
  final pass =
      blank is BlankSourcePageSlot &&
      real is RealSourcePageSlot &&
      real.page.sectionIndex == 0 &&
      real.side == SpreadSide.right &&
      unit.realSourceCount == 1;
  return {
    'pass': pass,
    'blankType': blank.runtimeType.toString(),
    'realSource': real is RealSourcePageSlot ? real.page.sectionIndex : null,
    'realSide': real is RealSourcePageSlot ? real.side.name : null,
  };
}

Map<String, Object?> _referenceSlotCheck(
  FixedSessionFixture session,
  ComposedReadingUnitNavigator nav,
  Map<String, Object?> reference,
  String criterion,
) {
  final failures = <String>[];
  final expected = (reference['referenceSpreadSlots'] as List)
      .map(jsonObject)
      .map(
        (slot) => {
          'index': slot['index'],
          'side': slot['side'],
          'source': slot['source'],
        },
      )
      .toList();
  final referenceBlanks = _referenceBlankSlots(expected);
  final actual = <Map<String, Object?>>[];
  for (var i = 0; i < nav.units.length; i++) {
    for (final slot in nav.units[i].slots.whereType<RealSourcePageSlot>()) {
      actual.add({
        'index': i,
        'side': slot.side.name,
        'source': slot.page.sectionIndex,
      });
    }
  }
  final bySource = {
    for (final section in nav.sections) section.page.sectionIndex: section,
  };
  final fixedExpected = <Map<String, Object?>>[];
  final reflowExpected = <Map<String, Object?>>[];
  for (final slot in expected) {
    final section = bySource[slot['source'] as int];
    if (section == null) {
      failures.add('oracle source ${slot['source']} is not in the spine');
      continue;
    }
    (section.rendition.isFixed == true ? fixedExpected : reflowExpected).add(
      slot,
    );
  }
  final fixedActual = [
    for (final slot in actual)
      if (bySource[slot['source'] as int]?.rendition.isFixed == true) slot,
  ];
  if (expected.length != actual.length) {
    failures.add(
      'reference has ${expected.length} real slots; native has '
      '${actual.length}',
    );
  }
  if (!_sameSlots(fixedActual, fixedExpected)) {
    failures.add('fixed-source slots differ from referenceSpreadSlots');
  }
  final reflowTraces = <Map<String, Object?>>[];
  for (final expectedSlot in reflowExpected) {
    final source = expectedSlot['source'] as int;
    final matches = actual.where((slot) => slot['source'] == source).toList();
    if (matches.length != 1) {
      failures.add('reflow source $source has ${matches.length} native slots');
      continue;
    }
    final actualSlot = matches.single;
    if (actualSlot['index'] != expectedSlot['index']) {
      failures.add('reflow source $source changed unit index');
    }
    if (actualSlot['side'] != 'center') {
      failures.add('reflow source $source is not centered');
    }
    final sideChanged = actualSlot['side'] != expectedSlot['side'];
    final implied = referenceBlanks
        .where((blank) => blank['index'] == expectedSlot['index'])
        .toList();
    reflowTraces.add({
      'kind': 'reflow-source-centering',
      'source': source,
      'expectedIndex': expectedSlot['index'],
      'actualIndex': actualSlot['index'],
      'expectedSide': expectedSlot['side'],
      'actualSide': actualSlot['side'],
      'sideChanged': sideChanged,
      'referenceImpliedBlank': implied.isEmpty ? null : implied.first,
      'requirement': _requirement,
      'criterion': criterion,
      'reason': sideChanged
          ? 'The reference treats this source as fixed and assigns it a '
                'left/right slot; native keeps it as a centered reflow unit, '
                'so no unit pairs a reflow page with a fixed page.'
          : 'The reference and native both keep this reflow source centered '
                'in this spread-none case.',
    });
  }
  return _check(
    failures.isEmpty ? 'pass' : 'fail',
    details: {
      'expected': expected,
      'actual': actual,
      'referenceImpliedBlanks': referenceBlanks,
      'fixedExpected': fixedExpected,
      'fixedActual': fixedActual,
      'reflowSources': reflowTraces,
      'reflowDifferences': reflowTraces,
    },
    failures: failures,
  );
}

List<Map<String, Object?>> _referenceBlankSlots(
  List<Map<String, Object?>> expected,
) {
  final byIndex = <int, List<String>>{};
  for (final slot in expected) {
    (byIndex[slot['index'] as int] ??= []).add(slot['side'] as String);
  }
  final blanks = [
    for (final entry in byIndex.entries)
      if (entry.value.length == 1 && entry.value.single != 'center')
        {
          'index': entry.key,
          'side': entry.value.single == 'left' ? 'right' : 'left',
          'source': null,
        },
  ];
  blanks.sort((a, b) => (a['index'] as int).compareTo(b['index'] as int));
  return blanks;
}

Map<String, Object?> _cfiCheck(
  FixedSessionFixture session,
  ComposedReadingUnitNavigator nav,
) {
  final failures = <String>[];
  final sources = <Map<String, Object?>>[];
  for (var i = 0; i < nav.sections.length; i++) {
    final document = session.documents[i];
    final element = document?.getElementById('source');
    if (document == null || element == null) {
      failures.add('source $i is missing its document or #source');
      continue;
    }
    final positions = <SourcePosition>[
      SourcePosition(nodeIndex: element.index, offset: 0),
    ];
    final textIndex = _firstTextNode(document, element.index);
    if (textIndex != null) {
      positions.add(SourcePosition(nodeIndex: textIndex, offset: 0));
    }
    final exported = <String>[];
    var roundTrip = true;
    for (final position in positions) {
      final cfi = Cfi.export(document, position);
      exported.add(cfi);
      if (Cfi.resolveLocal(document, cfi).start != position) roundTrip = false;
    }
    if (!roundTrip) failures.add('source $i CFI round trip failed');
    sources.add({
      'section': i,
      'href': nav.sections[i].href,
      'positions': positions.length,
      'cfi': exported,
      'roundTrip': roundTrip,
      'base': session.book.sections[i].spine.cfiBase,
    });
  }
  return _check(
    failures.isEmpty ? 'pass' : 'fail',
    details: {'sources': sources, 'allRoundTrip': failures.isEmpty},
    failures: failures,
  );
}

Map<String, Object?> _unsupportedCheck(
  String expectedCapability,
  UnsupportedProbe probe,
) {
  final failures = <String>[];
  if (expectedCapability == 'unsupported') {
    if (probe.issues.isEmpty) {
      failures.add('expected a typed unsupported issue');
    }
    if (probe.outcome != 'refused') {
      failures.add('expected typed refusal; observed ${probe.outcome}');
    }
    if (probe.unitsProduced != 0) {
      failures.add(
        'unsupported publication produced ${probe.unitsProduced} candidate '
        'units',
      );
    }
    if (probe.publishedUnits != null && probe.publishedUnits! != 0) {
      failures.add(
        'unsupported publication published ${probe.publishedUnits} units',
      );
    }
  } else {
    if (probe.issues.isNotEmpty) {
      failures.add(
        'required variant has unsupported issues: ${probe.issues.join(',')}',
      );
    }
    if (probe.outcome == 'refused') {
      failures.add('required variant was refused');
    }
    if (probe.unitsProduced == 0) {
      failures.add('required variant produced no units');
    }
  }
  return _check(
    failures.isEmpty ? 'pass' : 'fail',
    details: {
      'expectedCapability': expectedCapability,
      'outcome': probe.outcome,
      'issues': probe.issues,
      'unitsProduced': probe.unitsProduced,
      'publishedUnits': probe.publishedUnits,
      'boundary': probe.boundary,
      'reason': probe.reason,
      'partialSuccess':
          probe.publishedUnits != null && probe.publishedUnits! > 0,
    },
    failures: failures,
  );
}

List<String> _directionIssues(PublicationLayoutFacts facts) {
  final issues = <String>{};
  for (final section in facts.sections) {
    issues.addAll(
      section
          .directionIssues(
            pageProgressionDirection: facts.pageProgressionDirection,
          )
          .map((issue) => issue.name),
    );
  }
  final names = issues.toList()..sort();
  return names;
}

int? _firstTextNode(SourceDocument document, int root) {
  final stack = <int>[root];
  while (stack.isNotEmpty) {
    final index = stack.removeLast();
    final node = document.node(index);
    if (node.isCharacterData) return index;
    for (var i = node.children.length - 1; i >= 0; i--) {
      stack.add(node.children[i]);
    }
  }
  return null;
}

typedef _Walk = ({
  List<ReadingUnit> units,
  UnitBoundary? boundary,
  String? failure,
});

Future<_Walk> _traverse(
  ComposedReadingUnitNavigator nav,
  ReadingUnit start,
  UnitDirection direction, {
  NavigationSeam? seam,
}) async {
  final visited = <ReadingUnit>[start];
  var current = start;
  for (var turn = 0; turn <= nav.units.length; turn++) {
    final result = seam == null
        ? await nav.adjacent(current, direction)
        : await seam(nav, current, direction);
    if (result is ReadingUnitBoundary) {
      return (units: visited, boundary: result.boundary, failure: null);
    }
    if (result is! LocatedReadingUnit) {
      final reason = result is UnavailableReadingUnit
          ? result.reason
          : 'unknown navigation result';
      return (units: visited, boundary: null, failure: reason);
    }
    current = result.unit;
    visited.add(current);
  }
  return (
    units: visited,
    boundary: null,
    failure: 'navigation did not reach a boundary',
  );
}

List<Map<String, Object?>> _walk(List<ReadingUnit> units) => [
  for (final unit in units)
    {
      'unit': unit.id.stableId,
      'kind': unit.kind.name,
      'source': unit.activeSource.sectionIndex,
    },
];

/// LTR next passes the left side and prev the right side; a spread activates
/// that side's source. See fixed-layout.js:166-180, 246-250, 300-307.
int _entrySource(ReadingUnit unit, UnitDirection direction) {
  final real = unit.slots.whereType<RealSourcePageSlot>().toList();
  return direction == UnitDirection.next
      ? real.first.page.sectionIndex
      : real.last.page.sectionIndex;
}

List<int> _entrySources(List<ReadingUnit> units, UnitDirection direction) => [
  for (final unit in units) _entrySource(unit, direction),
];

Future<Map<String, Object?>> _navigationCheck(
  FixedSessionFixture session,
  ComposedReadingUnitNavigator nav, {
  NavigationSeam? seam,
}) async {
  final failures = <String>[];
  final bySource = {
    for (final section in nav.sections) section.page.sectionIndex: section,
  };
  final linearUnitIds = <String>[];
  for (final unit in nav.units) {
    final real = unit.slots.whereType<RealSourcePageSlot>();
    if (real.every(
      (slot) => bySource[slot.page.sectionIndex]?.linear == true,
    )) {
      linearUnitIds.add(unit.id.stableId);
    }
  }
  final forward = await _traverse(
    nav,
    nav.units.first,
    UnitDirection.next,
    seam: seam,
  );
  final reverse = await _traverse(
    nav,
    nav.units.last,
    UnitDirection.previous,
    seam: seam,
  );
  final forwardIds = [for (final unit in forward.units) unit.id.stableId];
  final reverseIds = [for (final unit in reverse.units) unit.id.stableId];
  final forwardSources = [
    for (final unit in forward.units) unit.activeSource.sectionIndex,
  ];
  final reverseSources = [
    for (final unit in reverse.units) unit.activeSource.sectionIndex,
  ];
  final expectedForwardSources = _entrySources(
    forward.units,
    UnitDirection.next,
  );
  final expectedReverseSources = _entrySources(
    reverse.units,
    UnitDirection.previous,
  );
  if (forward.failure != null) {
    failures.add('forward traversal: ${forward.failure}');
  }
  if (reverse.failure != null) {
    failures.add('reverse traversal: ${reverse.failure}');
  }
  if (!_sameList(forwardIds, linearUnitIds)) {
    failures.add('forward traversal differs from the linear unit order');
  }
  if (!_sameList(reverseIds, linearUnitIds.reversed.toList())) {
    failures.add('reverse traversal differs from the reverse linear order');
  }
  if (!_sameList(forwardSources, expectedForwardSources)) {
    failures.add(
      'forward active sources $forwardSources differ from entry rule '
      '$expectedForwardSources',
    );
  }
  if (!_sameList(reverseSources, expectedReverseSources)) {
    failures.add(
      'reverse active sources $reverseSources differ from entry rule '
      '$expectedReverseSources',
    );
  }
  if (forward.boundary != UnitBoundary.end) {
    failures.add('forward traversal did not reach the end boundary');
  }
  if (reverse.boundary != UnitBoundary.start) {
    failures.add('reverse traversal did not reach the start boundary');
  }
  final transitions = <Map<String, Object?>>[];
  void collect(List<ReadingUnit> units) {
    for (var i = 0; i + 1 < units.length; i++) {
      transitions.add({
        'fromKind': units[i].kind.name,
        'toKind': units[i + 1].kind.name,
        'fromSource': units[i].activeSource.sectionIndex,
        'toSource': units[i + 1].activeSource.sectionIndex,
      });
    }
  }

  collect(forward.units);
  collect(reverse.units);
  final crossings = transitions
      .where((transition) => transition['fromKind'] != transition['toKind'])
      .toList();
  final reflowToFixed = crossings
      .where(
        (transition) =>
            transition['fromKind'] == 'reflowPage' &&
            transition['toKind'] != 'reflowPage',
      )
      .length;
  final fixedToReflow = crossings
      .where(
        (transition) =>
            transition['fromKind'] != 'reflowPage' &&
            transition['toKind'] == 'reflowPage',
      )
      .length;
  if (reflowToFixed == 0) {
    failures.add('no reflow-to-fixed boundary was traversed');
  }
  if (fixedToReflow == 0) {
    failures.add('no fixed-to-reflow boundary was traversed');
  }
  final toc = <Map<String, Object?>>[];
  for (var i = 0; i < nav.sections.length; i++) {
    final section = nav.sections[i];
    final element = session.documents[i]?.getElementById('source');
    if (element == null) {
      failures.add('source $i has no #source fragment');
      continue;
    }
    final target = await nav.forTocTarget('${section.href}#source');
    final fromPosition = await nav.forSourcePosition(
      section.page,
      SourcePosition(nodeIndex: element.index, offset: 0),
    );
    bool exact(UnitNavigationResult result) =>
        result is LocatedReadingUnit &&
        result.unit.activeSource == section.page &&
        result.unit.slots.whereType<RealSourcePageSlot>().any(
          (slot) => slot.page == section.page,
        );
    final tocOk = exact(target), positionOk = exact(fromPosition);
    final same = target == fromPosition;
    if (!tocOk) {
      failures.add('TOC fragment for source $i did not resolve exactly');
    }
    if (!positionOk) {
      failures.add('source position for source $i did not resolve exactly');
    }
    if (!same) {
      failures.add('TOC fragment and source position disagree for source $i');
    }
    toc.add({
      'section': i,
      'href': '${section.href}#source',
      'toc': tocOk,
      'sourcePosition': positionOk,
      'sameUnit': same,
    });
  }
  final nonlinear = <Map<String, Object?>>[];
  for (var i = 0; i < nav.sections.length; i++) {
    if (nav.sections[i].linear) continue;
    final section = nav.sections[i];
    final target = await nav.forTocTarget('${section.href}#source');
    final index = nav.units.indexWhere(
      (unit) => unit.slots.whereType<RealSourcePageSlot>().any(
        (slot) => slot.page.sectionIndex == i,
      ),
    );
    final expected = index < 0 ? null : nav.units[index];
    final resolved =
        target is LocatedReadingUnit &&
        expected != null &&
        target.unit.id == expected.id &&
        target.unit.activeSource == section.page;
    if (!resolved) {
      failures.add('explicit nonlinear source $i missed its exact unit');
    }
    final inLinear =
        expected != null && linearUnitIds.contains(expected.id.stableId);
    if (inLinear) {
      failures.add('nonlinear source $i was treated as a linear unit');
    }
    nonlinear.add({
      'source': i,
      'unit': expected?.id.stableId,
      'resolved': resolved,
      'inLinearTraversal': inLinear,
    });
  }
  final sameSpread = <Map<String, Object?>>[];
  for (var i = 0; i < nav.units.length; i++) {
    final unit = nav.units[i];
    if (unit.kind != ReadingUnitKind.fixedSpread) continue;
    final real = unit.slots.whereType<RealSourcePageSlot>().toList();
    if (real.length != 2) {
      sameSpread.add({
        'unit': unit.id.stableId,
        'status': 'not-applicable',
        'reason': 'spread has a blank constituent',
      });
      continue;
    }
    final targets = <LocatedReadingUnit>[];
    for (final slot in real) {
      final section = bySource[slot.page.sectionIndex]!;
      final result = await nav.forTocTarget('${section.href}#source');
      if (result is LocatedReadingUnit) targets.add(result);
    }
    final retained =
        targets.length == 2 &&
        targets.every((target) => target.unit.id == unit.id);
    final distinct =
        targets.length == 2 &&
        targets[0].unit.activeSource != targets[1].unit.activeSource;
    final slotsRetained =
        targets.length == 2 &&
        targets.every(
          (target) => target.unit.slots
              .whereType<RealSourcePageSlot>()
              .map((slot) => slot.page)
              .toSet()
              .containsAll(real.map((slot) => slot.page)),
        );
    final requestedSources = [for (final slot in real) slot.page.sectionIndex];
    final activeSources = [
      for (final target in targets) target.unit.activeSource.sectionIndex,
    ];
    final activeSourcesMatch = _sameList(activeSources, requestedSources);
    final slotsUnchanged =
        targets.length == 2 &&
        targets.every((target) => _sameList(target.unit.slots, unit.slots));
    if (!retained ||
        !distinct ||
        !slotsRetained ||
        !activeSourcesMatch ||
        !slotsUnchanged) {
      failures.add('same-spread activation did not retain the unit');
    }
    sameSpread.add({
      'unit': unit.id.stableId,
      'requestedSources': requestedSources,
      'activeSources': activeSources,
      'unitRetained': retained,
      'distinctActiveSources': distinct,
      'slotsRetained': slotsRetained,
      'activeSourcesMatch': activeSourcesMatch,
      'slotsUnchanged': slotsUnchanged,
    });
  }
  final reflowCounts = [
    for (final section in nav.sections)
      if (section.rendition.isFixed == false) section.reflowPageCount,
  ];
  final portrait = nav.withViewport(
    width: 400,
    height: 600,
    repaginatedSections: nav.sections,
    reflowLocator: nav.locateReflow,
  );
  final portraitSingle = portrait.units.every(
    (unit) => unit.slots.length == 1 && unit.realSourceCount == 1,
  );
  final portraitOrder = [
    for (final unit in portrait.units) unit.activeSource.sectionIndex,
  ];
  final expectedOrder = [
    for (final section in nav.sections) section.page.sectionIndex,
  ];
  final orderOk = _sameList(portraitOrder, expectedOrder);
  if (reflowCounts.any((count) => count != 1)) {
    failures.add('portrait check requires single-page reflow sources');
  }
  if (!portraitSingle) {
    failures.add('portrait composition contains a multi-page unit');
  }
  if (!orderOk) {
    failures.add('portrait composition does not retain spine order');
  }
  return _check(
    failures.isEmpty ? 'pass' : 'fail',
    details: {
      'linearUnitIds': linearUnitIds,
      'forward': {
        'walk': _walk(forward.units),
        'sources': forwardSources,
        'expectedSources': expectedForwardSources,
        'boundary': forward.boundary?.name,
        'failure': forward.failure,
      },
      'reverse': {
        'walk': _walk(reverse.units),
        'sources': reverseSources,
        'expectedSources': expectedReverseSources,
        'boundary': reverse.boundary?.name,
        'failure': reverse.failure,
      },
      'entryRule': {
        'forward':
            'LTR next() requests the left side; showSpread keeps it unless a '
            'blank forces the other side; the active source is the left source '
            '(fixed-layout.js:166-180, 246-250, 300-303).',
        'reverse':
            'LTR prev() requests the right side; the active source is the '
            'right source (fixed-layout.js:166-180, 246-250, 304-307).',
        'sameSpread':
            'A same-spread goToSpread calls render(side), changing only the '
            'active side/source (fixed-layout.js:265-269).',
        'reference':
            'D:/Projects/lan-reader/node_modules/foliate-js/fixed-layout.js',
      },
      'transitions': transitions,
      'toc': toc,
      'nonlinear': nonlinear,
      'sameSpread': sameSpread,
      'portrait': {
        'viewport': [400, 600],
        'unitCount': portrait.units.length,
        'onePagePerUnit': portraitSingle,
        'sourceOrder': portraitOrder,
        'sourceOrderMatchesSpine': orderOk,
        'reusedSinglePageReflow': true,
        'reflowPageCounts': reflowCounts,
      },
    },
    failures: failures,
  );
}
