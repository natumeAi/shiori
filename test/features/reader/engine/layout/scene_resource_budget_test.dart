import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/source/source_parser.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';

void main() {
  test('every resource boundary, atomic refusal and exact-once release', () {
    for (final resource in SceneResource.values) {
      final budget = SceneResourceBudget();
      final cap = budget.limits[resource]!;
      final owner = budget.reserve({resource: cap});
      final before = budget.used;
      expect(
        () => budget.reserve({resource: 1}),
        throwsA(_exhausted(resource)),
      );
      expect(budget.used, before);
      owner.release();
      owner.release();
      expect(budget.used[resource], 0);
      expect(budget.peaks[resource], cap);
      expect(owner.isReleased, isTrue);
      budget.reserve({resource: cap}).release();
    }
  });
  test('late failure does not charge earlier classes', () {
    final budget = SceneResourceBudget();
    final current = budget.reserve({SceneResource.paragraphs: 8192});
    expect(
      () => budget.reserve({
        SceneResource.sourceBytes: 123,
        SceneResource.paragraphs: 1,
      }),
      throwsA(_exhausted(SceneResource.paragraphs)),
    );
    expect(budget.used, {SceneResource.paragraphs: 8192});
    expect(budget.peaks, {SceneResource.paragraphs: 8192});
    current.release();
  });
  test('three retained spreads plus reserve own eight source pages', () {
    final budget = SceneResourceBudget();
    final units = List.generate(
      4,
      (_) => budget.reserveUnit(
        sourcePages: 2,
        resources: {SceneResource.sourceBytes: 100},
      ),
    );
    expect(budget.used[SceneResource.readingUnits], 4);
    expect(budget.used[SceneResource.sourcePages], 8);
    expect(
      () => budget.reserveUnit(sourcePages: 1),
      throwsA(_exhausted(SceneResource.readingUnits)),
    );
    units.last.release();
    final replacement = budget.reserveUnit(sourcePages: 1);
    expect(budget.used[SceneResource.sourcePages], 7);
    expect(budget.used[SceneResource.sourceBytes], 300);
    for (final unit in units) {
      unit.release();
    }
    replacement.release();
    expect(budget.used.values, everyElement(0));
    expect(budget.peaks[SceneResource.sourcePages], 8);
  });
  test('constituent page bound is independent of unit bound', () {
    final budget = SceneResourceBudget(
      limits: {
        ...SceneResourceBudget.provisionalLimits,
        SceneResource.sourcePages: 3,
      },
    );
    final old = budget.reserveUnit(sourcePages: 2);
    expect(
      () => budget.reserveUnit(sourcePages: 2),
      throwsA(_exhausted(SceneResource.sourcePages)),
    );
    expect(budget.used[SceneResource.readingUnits], 1);
    final next = budget.reserveUnit(sourcePages: 1);
    old.release();
    expect(budget.used[SceneResource.sourcePages], 1);
    next.release();
  });
  test('old and replacement payloads remain charged during overlap', () {
    final budget = SceneResourceBudget(
      limits: {
        ...SceneResourceBudget.provisionalLimits,
        SceneResource.sourceBytes: 10,
      },
    );
    final old = budget.reserveUnit(
      sourcePages: 1,
      resources: {SceneResource.sourceBytes: 6},
    );
    expect(
      () => budget.reserveUnit(
        sourcePages: 1,
        resources: {SceneResource.sourceBytes: 5},
      ),
      throwsA(_exhausted(SceneResource.sourceBytes)),
    );
    final next = budget.reserveUnit(
      sourcePages: 1,
      resources: {SceneResource.sourceBytes: 4},
    );
    old.release();
    expect(budget.used[SceneResource.sourceBytes], 4);
    next.release();
    expect(budget.peaks[SceneResource.sourceBytes], 10);
  });
  test('depth boundaries refuse before charging', () {
    final budget = SceneResourceBudget();
    budget
        .reserve({}, sourceDepth: 64, referenceDepth: 32, layerDepth: 8)
        .release();
    for (final depth in SceneDepth.values) {
      expect(
        () => budget.reserve(
          {SceneResource.sourceBytes: 1},
          sourceDepth: depth == SceneDepth.source ? 65 : 0,
          referenceDepth: depth == SceneDepth.reference ? 33 : 0,
          layerDepth: depth == SceneDepth.layer ? 9 : 0,
        ),
        throwsA(
          isA<SceneAdmissionException>()
              .having(
                (e) => e.failure,
                'failure',
                SceneAdmissionFailure.complexityExceeded,
              )
              .having((e) => e.depth, 'depth', depth),
        ),
      );
    }
    expect(budget.used, isEmpty);
  });
  test(
    'layers count physical area, buffers, bytes and avoid integer overflow',
    () {
      final budget = SceneResourceBudget(
        limits: {
          ...SceneResourceBudget.provisionalLimits,
          SceneResource.layerPixels: 200,
          SceneResource.layerBytes: 800,
        },
      );
      final layer = budget.reserveLayer(10, 10, buffers: 2);
      expect(budget.used[SceneResource.layerBytes], 800);
      expect(
        () => budget.reserveLayer(1, 1),
        throwsA(_exhausted(SceneResource.layerPixels)),
      );
      layer.release();
      expect(budget.used.values, everyElement(0));
      expect(
        () => budget.reserveLayer(0x7fffffffffffffff, 2),
        throwsA(_exhausted(SceneResource.layerPixels)),
      );
      expect(
        () => budget.reserveLayer(1, 1, buffers: 0x7fffffffffffffff),
        throwsA(_exhausted(SceneResource.layerPixels)),
      );
      final bytes = SceneResourceBudget(
        limits: {
          ...SceneResourceBudget.provisionalLimits,
          SceneResource.layerPixels: 200,
          SceneResource.layerBytes: 399,
        },
      );
      expect(
        () => bytes.reserveLayer(10, 10),
        throwsA(_exhausted(SceneResource.layerBytes)),
      );
      expect(bytes.used, isEmpty);
    },
  );
  test('invalid policy and requests leave admission unchanged', () {
    expect(() => SceneResourceBudget(limits: {}), throwsArgumentError);
    expect(() => SceneResourceBudget(sourceDepthLimit: 0), throwsArgumentError);
    final budget = SceneResourceBudget();
    expect(
      () => budget.reserve({SceneResource.sourceBytes: -1}),
      throwsArgumentError,
    );
    expect(() => budget.reserve({}, sourceDepth: -1), throwsArgumentError);
    expect(() => budget.reserveLayer(0, 1), throwsArgumentError);
    expect(() => budget.reserveUnit(sourcePages: 0), throwsArgumentError);
    expect(() => budget.reserveUnit(sourcePages: 3), throwsArgumentError);
    expect(
      () => budget.reserveUnit(
        sourcePages: 1,
        resources: {SceneResource.sourcePages: 0},
      ),
      throwsArgumentError,
    );
    expect(budget.used, isEmpty);
  });
  test('reservation snapshots cannot be mutated', () {
    final request = {SceneResource.sourceBytes: 3};
    final budget = SceneResourceBudget();
    final owner = budget.reserve(request);
    request[SceneResource.sourceBytes] = 99;
    expect(() => owner.charge.clear(), throwsUnsupportedError);
    expect(() => budget.used.clear(), throwsUnsupportedError);
    expect(() => budget.limits.clear(), throwsUnsupportedError);
    owner.release();
    expect(budget.used[SceneResource.sourceBytes], 0);
  });
  test('invalid late resource refuses without charging a valid prefix', () {
    final budget = SceneResourceBudget();
    final current = budget.reserveUnit(sourcePages: 2);
    final before = budget.used;
    expect(
      () => budget.reserveUnit(
        sourcePages: 2,
        resources: {
          SceneResource.sourceBytes: 100,
          SceneResource.paragraphs: -1,
        },
      ),
      throwsArgumentError,
    );
    expect(budget.used, before);
    expect(budget.used[SceneResource.sourcePages], 2);
    current.release();
  });
  test(
    'every generated corpus projection fits eight source-page admissions',
    () {
      final corpus = jsonDecode(
        File('test/fixtures/reader/fixed_layout/corpus.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>;
      final cases = corpus['cases'] as List<dynamic>;
      expect(cases, isNotEmpty);
      for (final value in cases) {
        final fixture = value as Map<String, dynamic>;
        final source = fixture['source'] as String;
        final document = const SourceParser().parse(source);
        final depths = <int, int>{};
        var maxDepth = 0;
        var textCodeUnits = 0;
        for (final node in document.nodes) {
          final depth = node.parentIndex == null
              ? 1
              : depths[node.parentIndex]! + 1;
          depths[node.index] = depth;
          if (depth > maxDepth) maxDepth = depth;
          textCodeUnits += node.text?.length ?? 0;
        }
        final budget = SceneResourceBudget();
        final units = List.generate(
          4,
          (_) => budget.reserveUnit(
            sourcePages: 2,
            sourceDepth: maxDepth,
            resources: {
              SceneResource.sourceBytes: utf8.encode(source).length * 2,
              SceneResource.sourceNodes: document.nodes.length * 2,
              SceneResource.textCodeUnits: textCodeUnits * 2,
            },
          ),
        );
        for (final unit in units) {
          unit.release();
        }
        expect(
          budget.used.values,
          everyElement(0),
          reason: fixture['id'] as String,
        );
      }
    },
  );

  test(
    'lease shrink returns part of one class and release returns the rest once',
    () {
      final budget = SceneResourceBudget();
      final lease = budget.reserveUnit(
        sourcePages: 1,
        resources: {
          SceneResource.vectorBytes: 1000,
          SceneResource.sourceBytes: 50,
        },
      );
      final peak = budget.peaks[SceneResource.vectorBytes];
      lease.shrink(SceneResource.vectorBytes, 0);
      expect(lease.charge[SceneResource.vectorBytes], 1000);
      lease.shrink(SceneResource.vectorBytes, 400);
      expect(lease.charge[SceneResource.vectorBytes], 600);
      expect(lease.charge[SceneResource.sourceBytes], 50);
      expect(budget.used[SceneResource.vectorBytes], 600);
      expect(budget.used[SceneResource.sourceBytes], 50);
      expect(budget.peaks[SceneResource.vectorBytes], peak);
      // The freed capacity is immediately admissible to another unit.
      final other = budget.reserve({SceneResource.vectorBytes: 400});
      expect(budget.used[SceneResource.vectorBytes], 1000);
      other.release();
      expect(
        () => lease.shrink(SceneResource.vectorBytes, 601),
        throwsArgumentError,
      );
      expect(
        () => lease.shrink(SceneResource.vectorBytes, -1),
        throwsArgumentError,
      );
      expect(
        () => lease.shrink(SceneResource.paragraphs, 1),
        throwsArgumentError,
      );
      expect(() => lease.charge.clear(), throwsUnsupportedError);
      expect(budget.used[SceneResource.vectorBytes], 600);
      lease.release();
      lease.release();
      expect(budget.used.values, everyElement(0));
      expect(
        () => lease.shrink(SceneResource.vectorBytes, 0),
        throwsStateError,
      );
      expect(budget.used.values, everyElement(0));
    },
  );
  test(
    'shrinking one lease never changes another lease on the same budget',
    () {
      final budget = SceneResourceBudget();
      final a = budget.reserve({SceneResource.vectorBytes: 100});
      final b = budget.reserve({SceneResource.vectorBytes: 100});
      a.shrink(SceneResource.vectorBytes, 100);
      expect(a.charge[SceneResource.vectorBytes], 0);
      expect(b.charge[SceneResource.vectorBytes], 100);
      expect(budget.used[SceneResource.vectorBytes], 100);
      a.release();
      expect(budget.used[SceneResource.vectorBytes], 100);
      b.release();
      expect(budget.used[SceneResource.vectorBytes], 0);
    },
  );
}

Matcher _exhausted(SceneResource resource) => isA<SceneAdmissionException>()
    .having(
      (e) => e.failure,
      'failure',
      SceneAdmissionFailure.resourceExhausted,
    )
    .having((e) => e.resource, 'resource', resource);
