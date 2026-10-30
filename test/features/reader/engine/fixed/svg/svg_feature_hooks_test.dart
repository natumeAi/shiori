import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/geometry/cluster_geometry.dart';
import 'package:shiori/features/reader/data/geometry/paint_geometry.dart';
import 'package:shiori/features/reader/data/geometry/source_fragment.dart';
import 'package:shiori/features/reader/data/geometry/source_geometry.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/source/source_parser.dart';
import 'package:shiori/features/reader/data/worker/publication_cancellation.dart';
import 'package:shiori/features/reader/engine/fixed/svg/svg_graphics.dart';
import 'package:shiori/features/reader/engine/fixed/svg/svg_presentation.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/pagination/preparation.dart';
import 'package:shiori/features/reader/engine/support/section_capability.dart';

import '../../../../../../tool/reader/fixed_layout_scene_input.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final corpus = jsonDecode(
    File('test/fixtures/reader/fixed_layout/corpus.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final fixture = (corpus['cases'] as List).cast<Map<String, Object?>>().first;
  final input = SceneHarnessInput(
    fixture,
    corpus,
    File((corpus['font'] as Map)['path'] as String).readAsBytesSync(),
  );
  tearDownAll(input.book.archive.close);
  SvgGraphicsPlan plan(
    String markup, {
    required SvgFeatureRegistry features,
    SvgFeatureHost host = const SvgFeatureHost.unavailable(),
  }) {
    final document = const SourceParser().parse(
      '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">$markup</svg>',
      mediaType: 'image/svg+xml',
    );
    return SvgGraphicsPlan.inspect(
      document: document,
      rootIndex: document.documentElementIndex,
      page: input.page,
      size: AuthoredPageSize(100, 100),
      features: features,
      host: host,
    );
  }

  test('the unavailable host reports no foreignObject or text service', () {
    const host = SvgFeatureHost.unavailable();
    expect(host.foreignObject.available, false);
    expect(host.text.available, false);
  });

  test('clip annotation preserves separate fill and stroke roles', () async {
    final budget = SceneResourceBudget();
    final scene = await plan(
      '<rect id="target" width="30" height="30" fill="red" stroke="blue" data-hook="yes"/>',
      features: SvgFeatureRegistry([_FakeFeature([])]),
    ).prepare(budget: budget);
    try {
      expect(scene.capability.isComplete, true);
      final paints = scene.geometry.paint
          .where((p) => p.clipIds.contains('fake-clip'))
          .toList();
      expect(paints.map((p) => p.role), [
        GeometryPaintRole.fill,
        GeometryPaintRole.stroke,
      ]);
    } finally {
      scene.dispose();
    }
    expect(budget.used.values.every((v) => v == 0), true);
  });

  test(
    'post-paint capture is isolated, post-opacity and awaited before proof',
    () async {
      final feature = _PostPaintFeature();
      final p = plan(
        '<g data-post="yes" opacity=".25">'
        '<rect x="10" y="10" width="20" height="20"/></g>'
        '<rect x="50" y="50" width="10" height="10"/>',
        features: SvgFeatureRegistry([feature]),
      );
      final budget = SceneResourceBudget();
      var finished = false;
      final future = p.prepare(budget: budget).then((scene) {
        finished = true;
        return scene;
      });
      await feature.entered.future;
      expect(finished, false);
      expect(feature.events, ['geometry', 'paint', 'post']);
      feature.resume.complete();
      final scene = await future;
      try {
        expect(feature.events, ['geometry', 'paint', 'post', 'post-done']);
        expect(feature.alpha!.alphaAt(GeometryPoint(20, 20)), 64);
        expect(feature.alpha!.alphaAt(GeometryPoint(55, 55)), 0);
        expect(scene.geometry.completeness, isA<CompleteGeometry>());
      } finally {
        scene.dispose();
      }
      expect(budget.used.values.every((v) => v == 0), true);
    },
  );

  test('refusing registry keeps the existing typed identifiers', () {
    final refusing = SvgFeatureRegistry([const _RefusingFeature()]);
    for (final (tag, identifier) in [
      ('filter', 'svg-filter'),
      ('feTurbulence', 'svg-feTurbulence'),
      ('clipPath', 'svg-clipPath'),
      ('mask', 'svg-mask'),
      ('foreignObject', 'svg-foreignObject'),
      ('text', 'svg-text'),
      ('tspan', 'svg-tspan'),
      ('textPath', 'svg-textPath'),
    ]) {
      final p = plan('<defs><$tag id="feature"/></defs>', features: refusing);
      expect(p.capability, isA<UnsupportedSectionCapability>(), reason: tag);
      expect(
        (p.capability as UnsupportedSectionCapability)
            .constructs
            .single
            .identifier,
        identifier,
        reason: tag,
      );
    }
    for (final (attribute, identifier) in [
      ('clip-path', 'svg-attribute-clip-path'),
      ('mask', 'svg-attribute-mask'),
      ('filter', 'svg-filter'),
    ]) {
      final p = plan(
        '<rect width="10" height="10" $attribute="url(#missing)"/>',
        features: refusing,
      );
      expect(p.capability, isA<UnsupportedSectionCapability>());
      expect(
        (p.capability as UnsupportedSectionCapability)
            .constructs
            .single
            .identifier,
        identifier,
      );
    }
    final document = const SourceParser().parse(
      '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100"><rect id="r"/></svg>',
      mediaType: 'image/svg+xml',
    );
    for (final (property, identifier) in [
      ('clip-path', 'svg-css-clip-path'),
      ('mask', 'svg-css-mask'),
    ]) {
      final presentation = SvgPresentation.resolve(
        document,
        ['#r{$property:url(#missing)}'],
        viewportWidth: 100,
        viewportHeight: 100,
        features: refusing,
      );
      expect(presentation.problems, contains(identifier), reason: property);
    }
  });

  test(
    'fake feature proves admission, reservation, ordering, paint and geometry',
    () async {
      final events = <String>[];
      final fake = _FakeFeature(events);
      final features = SvgFeatureRegistry([fake]);
      final p = plan(
        '<g id="group" data-hook="wrap"><rect id="target" data-hook="wrap" x="10" y="10" width="20" height="20" fill="red"/></g>',
        features: features,
      );
      expect(p.capability, isA<CompleteSectionCapability>());
      expect(p.resources[SceneResource.gradientStops], 10);
      expect(
        p.reservation()[SceneResource.layerPixels],
        // Bounded evidence rasterization (2026-10-30): one authored raster.
        100 * 100 * (p.layerDepth + 3) + 20,
      );
      final budget = SceneResourceBudget();
      final scene = await p.prepare(budget: budget);
      try {
        expect(scene.capability, isA<CompleteSectionCapability>());
        final group = p.document.nodes
            .singleWhere((n) => n.id == 'group')
            .index;
        final target = p.document.nodes
            .singleWhere((n) => n.id == 'target')
            .index;
        expect(
          events.indexOf('prepare'),
          lessThan(events.indexOf('enter:$group')),
        );
        expect(events, [
          'prepare',
          'enter:$group',
          'enter:$target',
          'exit:$target',
          'exit:$group',
        ]);
        expect(
          scene.geometry.fragments.any((f) => f.nodeIndex == target),
          true,
        );
        expect(
          scene.geometry.fragments
              .where((f) => f.nodeIndex == target)
              .any((f) => f.clipIds.contains('fake-clip')),
          true,
        );
        expect(scene.geometry.clips.any((c) => c.id == 'fake-clip'), true);
        expect(scene.geometry.completeness, isA<CompleteGeometry>());
        scene.dispose();
        scene.dispose();
        expect(events.where((e) => e == 'dispose'), hasLength(1));
      } finally {
        scene.dispose();
      }
      expect(budget.used.values.every((v) => v == 0), true);
    },
  );

  test(
    'fake feature failure releases once and publishes no partial scene',
    () async {
      final events = <String>[];
      final p = plan(
        '<rect id="target" data-hook="wrap" width="20" height="20"/>',
        features: SvgFeatureRegistry([
          _FakeFeature(events, mode: _FakeMode.fail),
        ]),
      );
      final budget = SceneResourceBudget();
      final scene = await p.prepare(budget: budget);
      try {
        expect(scene.capability, isA<RenderSectionCapability>());
        expect(scene.picture, isNull);
        expect(events.where((e) => e == 'dispose'), hasLength(1));
      } finally {
        scene.dispose();
      }
      expect(budget.used.values.every((v) => v == 0), true);
    },
  );

  test('fake feature cancellation releases once', () async {
    final events = <String>[];
    final p = plan(
      '<rect id="target" data-hook="wrap" width="20" height="20"/>',
      features: SvgFeatureRegistry([
        _FakeFeature(events, mode: _FakeMode.cancel),
      ]),
    );
    final budget = SceneResourceBudget(), token = PublicationCancellation();
    await expectLater(
      p.prepare(budget: budget, cancellation: token),
      throwsA(isA<PreparationCancelled>()),
    );
    expect(events.where((e) => e == 'dispose'), hasLength(1));
    expect(budget.used.values.every((v) => v == 0), true);
  });

  test('fake feature can publish explicit incomplete geometry', () async {
    final events = <String>[];
    final p = plan(
      '<rect id="target" data-hook="wrap" width="20" height="20"/>',
      features: SvgFeatureRegistry([
        _FakeFeature(events, mode: _FakeMode.incomplete),
      ]),
    );
    final budget = SceneResourceBudget();
    final scene = await p.prepare(budget: budget);
    try {
      final geometry = scene.geometry.completeness;
      expect(geometry, isA<IncompleteGeometry>());
      expect(
        (geometry as IncompleteGeometry).issues.single.reason,
        'fake incomplete',
      );
    } finally {
      scene.dispose();
    }
    expect(budget.used.values.every((v) => v == 0), true);
  });

  test('a feature-owned node without completion stays incomplete', () async {
    final p = plan(
      '<rect id="target" data-hook="wrap" width="20" height="20"/>',
      features: SvgFeatureRegistry([
        _FakeFeature([], mode: _FakeMode.noCompletion),
      ]),
    );
    final scene = await p.prepare(budget: SceneResourceBudget());
    try {
      expect(scene.capability, isA<CompleteSectionCapability>());
      final geometry = scene.geometry.completeness;
      expect(geometry, isA<IncompleteGeometry>());
      expect(
        (geometry as IncompleteGeometry).issues.any(
          (issue) => issue.reason.contains('did not report completion'),
        ),
        true,
      );
    } finally {
      scene.dispose();
    }
  });

  test('a paint wrapper must call paintDefault exactly once', () async {
    for (final mode in [_FakeMode.paintSkip, _FakeMode.paintRepeat]) {
      final p = plan(
        '<rect id="target" data-hook="wrap" width="20" height="20"/>',
        features: SvgFeatureRegistry([_FakeFeature([], mode: mode)]),
      );
      final budget = SceneResourceBudget();
      final scene = await p.prepare(budget: budget);
      try {
        expect(scene.capability, isA<UnsupportedSectionCapability>());
        expect(scene.picture, isNull);
      } finally {
        scene.dispose();
      }
      expect(budget.used.values.every((v) => v == 0), true);
    }
  });

  test(
    'captured default replays, runs inner wrappers once and releases once',
    () async {
      final events = <String>[];
      final capture = _CaptureFeature();
      final p = plan(
        '<g data-capture="yes"><rect data-hook="wrap" x="10" y="10" '
        'width="10" height="10" fill="red"/></g>',
        features: SvgFeatureRegistry([capture, _FakeFeature(events)]),
      );
      final budget = SceneResourceBudget();
      final scene = await p.prepare(budget: budget);
      try {
        expect(scene.capability, isA<CompleteSectionCapability>());
        expect(events.where((e) => e.startsWith('enter:')), hasLength(1));
        expect(capture.source!.debugDisposed, false);
        final image = await scene.picture!.toImage(100, 100);
        try {
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawStraightRgba,
          ))!.buffer.asUint8List();
          for (final x in [15, 45]) {
            final offset = (15 * 100 + x) * 4;
            expect(bytes.sublist(offset, offset + 4), [255, 0, 0, 255]);
          }
        } finally {
          image.dispose();
        }
      } finally {
        scene.dispose();
        scene.dispose();
      }
      expect(capture.source!.debugDisposed, true);
      expect(budget.used.values.every((v) => v == 0), true);
    },
  );

  test('default capture retains fractional viewport clips on replay', () async {
    final capture = _CaptureFeature();
    String viewport(double x, String attributes) =>
        '<svg x="$x" y="25.25" width="10" height="10" overflow="hidden">'
        '<g $attributes><svg x="-5.25" y="2.5" width="12.5" height="20" '
        'overflow="hidden"><rect x="-20" y="-20" width="80" height="80" '
        'fill="red"/></svg></g></svg>';
    final grids = <List<int>>[];
    for (final captured in [true, false]) {
      final budget = SceneResourceBudget();
      final scene = await plan(
        captured
            ? viewport(20.5, 'data-capture="yes"')
            : '${viewport(20.5, '')}${viewport(50.5, '')}',
        features: SvgFeatureRegistry(captured ? [capture] : []),
      ).prepare(budget: budget);
      try {
        expect(scene.capability.isComplete, true);
        expect(scene.geometry.completeness, isA<CompleteGeometry>());
        final image = await scene.picture!.toImage(100, 100);
        try {
          grids.add(
            (await image.toByteData(
              format: ui.ImageByteFormat.rawStraightRgba,
            ))!.buffer.asUint8List(),
          );
        } finally {
          image.dispose();
        }
      } finally {
        scene.dispose();
      }
      expect(budget.used.values.every((v) => v == 0), true);
    }
    expect(grids.first, orderedEquals(grids.last));
    expect(capture.source!.debugDisposed, true);
  });

  test(
    'capture releases on failure, cancellation and mixed default calls',
    () async {
      for (final mode in ['fail', 'cancel', 'mixed', 'paintFirst']) {
        final token = PublicationCancellation();
        final capture = _CaptureFeature(mode: mode, token: token);
        final p = plan(
          '<rect data-capture="yes" width="20" height="20"/>',
          features: SvgFeatureRegistry([capture]),
        );
        final budget = SceneResourceBudget();
        if (mode == 'cancel') {
          await expectLater(
            p.prepare(budget: budget, cancellation: token),
            throwsA(isA<PreparationCancelled>()),
          );
        } else {
          final scene = await p.prepare(budget: budget);
          expect(scene.picture, isNull);
          expect(
            scene.capability,
            mode == 'fail'
                ? isA<RenderSectionCapability>()
                : isA<UnsupportedSectionCapability>(),
          );
          scene.dispose();
        }
        if (mode != 'paintFirst') expect(capture.source!.debugDisposed, true);
        expect(budget.used.values.every((v) => v == 0), true);
      }
    },
  );

  test('preReserved debits the base before pattern sub-leases', () async {
    final p = plan(
      '<defs><pattern id="p" width="1.5625" height="1.5625" patternUnits="userSpaceOnUse"><rect width=".5" height=".5" fill="red"/></pattern></defs>'
      '<rect width="100" height="100" fill="url(#p)"/>',
      features: SvgFeatureRegistry([]),
    );
    final reservation = p.reservation();
    final local = SceneResourceBudget(
      limits: {
        for (final resource in SceneResource.values)
          resource: switch (resource) {
            SceneResource.references => 4096,
            SceneResource.vectorOperations => 1000000,
            SceneResource.vectorBytes => 16 * 1024 * 1024,
            SceneResource.layerPixels => reservation[resource] ?? 1,
            SceneResource.layerBytes => reservation[resource] ?? 1,
            _ => (p.resources[resource] ?? 0) > 0 ? p.resources[resource]! : 1,
          },
      },
    );
    final scene = await p.prepare(budget: local, preReserved: true);
    try {
      expect(scene.capability, isA<ResourceSectionCapability>());
      expect(scene.picture, isNull);
    } finally {
      scene.dispose();
    }
    expect(local.used.values.every((v) => v == 0), true);
  });

  test('feature content in patterns and markers refuses explicitly', () {
    final features = SvgFeatureRegistry([_FakeFeature([])]);
    final pattern = plan(
      '<defs><pattern id="p" width="4" height="4"><rect data-hook="wrap" width="1" height="1"/></pattern></defs>'
      '<rect width="10" height="10" fill="url(#p)"/>',
      features: features,
    );
    expect(pattern.capability, isA<UnsupportedSectionCapability>());
    expect(
      (pattern.capability as UnsupportedSectionCapability)
          .constructs
          .single
          .identifier,
      'svg-feature-in-pattern',
    );
    final marker = plan(
      '<defs><marker id="m"><rect data-hook="wrap" width="1" height="1"/></marker></defs>'
      '<path d="M0 0L10 10" stroke="black" marker-start="url(#m)"/>',
      features: features,
    );
    expect(marker.capability, isA<UnsupportedSectionCapability>());
    expect(
      (marker.capability as UnsupportedSectionCapability)
          .constructs
          .single
          .identifier,
      'svg-feature-in-marker',
    );
  });
}

final class _PostPaintFeature extends SvgFeature {
  final entered = Completer<void>(), resume = Completer<void>();
  final events = <String>[];
  GeometryAlphaFootprint? alpha;
  @override
  String get key => 'post';
  @override
  Set<String> get attributes => const {'data-post'};
  @override
  void geometry(SvgFeatureGeometryContext context) => events.add('geometry');
  @override
  bool captureOutput(SvgFeatureNode node) =>
      node.attributes.containsKey('data-post');
  @override
  void paint(SvgFeaturePaint context) {
    events.add('paint');
    context.paintDefault();
  }

  @override
  Future<void> postPaint(SvgFeaturePostPaintContext post) async {
    events.add('post');
    entered.complete();
    await resume.future;
    final node = post.geometry.nodes.singleWhere((n) => captureOutput(n));
    alpha = await AuthoredEvidenceRaster.rasterize(
      post.outputFor(node)!,
      width: 100,
      height: 100,
      budget: post.rasterBudget,
      reserve: (_) {},
      checkCancellation: post.checkCancellation,
    );
    post.geometry.markCovered(node);
    events.add('post-done');
  }
}

final class _CaptureFeature extends SvgFeature {
  _CaptureFeature({this.mode = 'ok', this.token});
  final String mode;
  final PublicationCancellation? token;
  ui.Picture? source;
  @override
  String get key => 'capture';
  @override
  Set<String> get attributes => const {'data-capture'};
  @override
  Future<void> prepare(SvgFeaturePreparation context) async {
    for (final node in context.nodes) {
      if (node.attributes.containsKey('data-capture')) {
        context.markCovered(node);
      }
    }
  }

  @override
  void paint(SvgFeaturePaint context) {
    if (mode == 'paintFirst') context.paintDefault();
    source = context.captureDefault();
    expect(identical(context.captureDefault(), source), true);
    expect(context.paintDefaultCalls, 1);
    if (mode == 'fail') throw StateError('failure after capture');
    if (mode == 'cancel') token!.cancel();
    if (mode == 'mixed') context.paintDefault();
    context.canvas.drawPicture(source!);
    context.canvas.save();
    context.canvas.translate(30, 0);
    context.canvas.drawPicture(source!);
    context.canvas.restore();
  }
}

enum _FakeMode {
  ok,
  fail,
  cancel,
  incomplete,
  noCompletion,
  paintSkip,
  paintRepeat,
}

final class _RefusingFeature extends SvgFeature {
  const _RefusingFeature();
  @override
  String get key => 'test-refusal';
  @override
  Set<String> get tags => const {
    'filter',
    'feTurbulence',
    'clipPath',
    'mask',
    'foreignObject',
    'text',
    'tspan',
    'textPath',
  };
  @override
  Set<String> get attributes => const {'filter', 'clip-path', 'mask'};
  @override
  Set<String> get presentationProperties => const {
    'filter',
    'clip-path',
    'mask',
  };
  @override
  String? presentationRefusal(String property, String value) =>
      switch (property) {
        'clip-path' => 'svg-css-clip-path',
        'mask' => 'svg-css-mask',
        _ => null,
      };
  @override
  void admit(SvgFeatureAdmission admission) {
    final tag = admission.tag;
    if (tag != null && tags.contains(tag)) admission.refuse('svg-$tag');
    if (admission.attributes.containsKey('filter')) {
      admission.refuse('svg-filter');
    }
    if (admission.attributes.containsKey('clip-path')) {
      admission.refuse('svg-attribute-clip-path');
    }
    if (admission.attributes.containsKey('mask')) {
      admission.refuse('svg-attribute-mask');
    }
  }
}

final class _FakeFeature extends SvgFeature {
  _FakeFeature(this.events, {this.mode = _FakeMode.ok});
  final List<String> events;
  final _FakeMode mode;
  @override
  String get key => 'fake';
  @override
  Set<String> get attributes => const {'data-hook'};
  @override
  void admit(SvgFeatureAdmission admission) {
    admission.charge(SceneResource.gradientStops, 5);
    admission.chargeLayers(pixels: 10, bytes: 40);
  }

  @override
  Future<void> prepare(SvgFeaturePreparation preparation) async {
    events.add('prepare');
    preparation.onDispose(() => events.add('dispose'));
    preparation.reserve({SceneResource.vectorOperations: 7});
    await Future<void>.value();
    if (mode == _FakeMode.fail) throw StateError('fake failure');
    if (mode == _FakeMode.cancel) {
      preparation.cancellation!.cancel();
      preparation.checkCancellation();
    }
  }

  @override
  void geometry(SvgFeatureGeometryContext context) {
    final owned = [
      for (final node in context.nodes)
        if (node.attributes.containsKey('data-hook')) node,
    ];
    if (mode == _FakeMode.incomplete) {
      for (final node in owned) {
        context.markIncomplete(node, GeometryGapKind.paint, 'fake incomplete');
      }
    } else if (mode != _FakeMode.noCompletion) {
      for (final node in owned) {
        context.markCovered(node);
      }
    }
    final matches = [
      for (final node in context.nodes)
        if (node.id == 'target') node,
    ];
    if (matches.length != 1) return;
    final node = matches.single;
    const clipId = 'fake-clip';
    context.geometry.addClip(
      GeometryClip(
        id: clipId,
        region: GeometryRegion(
          left: 0,
          top: 0,
          width: 1,
          height: 1,
          transform: node.transform,
        ),
      ),
    );
    context.addClipTo(node.nodeIndex, clipId);
    context.geometry.addFragment(
      SourceFragment(
        page: context.plan.page,
        nodeIndex: node.nodeIndex,
        kind: SourceFragmentKind.element,
        textRange: null,
        clusters: const [],
        elementAnchor: SourceElementAnchor(
          nodeIndex: node.nodeIndex,
          elementId: node.id,
        ),
        sourceToUnit: node.transform,
        clipIds: const [],
        maskIds: const [],
        paintOrdinal: node.paintOrdinal,
        effectiveOpacity: 1,
      ),
    );
  }

  @override
  void paint(SvgFeaturePaint context) {
    if (mode == _FakeMode.paintSkip) {
      events.add('skip:${context.node.nodeIndex}');
      return;
    }
    events.add('enter:${context.node.nodeIndex}');
    context.paintDefault();
    if (mode == _FakeMode.paintRepeat) context.paintDefault();
    events.add('exit:${context.node.nodeIndex}');
  }
}
