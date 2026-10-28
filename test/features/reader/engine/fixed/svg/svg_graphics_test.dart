import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart' show svg;
import 'package:shiori/features/reader/data/canonical/canonical_text.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/source/source_parser.dart';
import 'package:shiori/features/reader/data/worker/publication_cancellation.dart';
import 'package:shiori/features/reader/engine/pagination/preparation.dart';
import 'package:shiori/features/reader/engine/fixed/svg/svg_graphics.dart';
import 'package:shiori/features/reader/engine/fixed/svg/svg_presentation.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
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
  SvgGraphicsPlan plan(String children, {String extra = '', String css = ''}) {
    final doc = const SourceParser().parse(
      '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" $extra>$children</svg>',
      mediaType: 'image/svg+xml',
    );
    final presentation = SvgPresentation.resolve(
      doc,
      [css],
      viewportWidth: 100,
      viewportHeight: 100,
    );
    return SvgGraphicsPlan.inspect(
      document: doc,
      rootIndex: doc.documentElementIndex,
      page: input.page,
      size: AuthoredPageSize(100, 100),
      resolvedPresentation: presentation.values,
      presentationProblems: presentation.problems,
    );
  }

  test(
    'all path verbs, subpaths, numbers and source identity survive',
    () async {
      final p = plan(
        '<path id="p" d="M5 5L20 5l5 5H40h5V20v5C45 30 40 35 35 35c-5 0-5 5-10 5S10 45 10 40s-5-5-5-10Q5 20 10 20q5 0 5-5T20 10t5 0A5 8 30 0 1 35 15a5 5 0 1 0 5 5Z m1e1 1e1 5 0 0 5z" fill-rule="evenodd" stroke="blue" stroke-width="2" stroke-linecap="round" stroke-linejoin="bevel" stroke-miterlimit="3" stroke-dasharray="2 1 3" stroke-dashoffset="1"/>',
      );
      final budget = SceneResourceBudget();
      final scene = await p.prepare(budget: budget);
      try {
        expect(scene.capability, isA<CompleteSectionCapability>());
        expect(
          scene.geometry.fragments.any(
            (f) => f.elementAnchor?.elementId == 'p',
          ),
          true,
        );
        expect(
          scene.geometry.paint.single.alphaFootprint!.alpha.any((a) => a > 0),
          true,
        );
        expect(CanonicalIndex.build(p.document).length, 0);
      } finally {
        scene.dispose();
      }
      expect(budget.used.values.every((v) => v == 0), true);
    },
  );
  test('gradients retain units, spread, transforms and inherited stops', () async {
    for (final type in ['linearGradient', 'radialGradient']) {
      for (final units in ['objectBoundingBox', 'userSpaceOnUse']) {
        for (final spread in ['pad', 'repeat', 'reflect']) {
          final p = plan(
            '<defs><$type id="g" gradientUnits="$units" spreadMethod="$spread" gradientTransform="rotate(15) scale(.9)"><stop stop-color="red"/><stop offset="50%" stop-color="green"/><stop offset="1" stop-color="blue"/></$type><$type id="copy" href="#g"/></defs><rect x="10" y="10" width="80" height="80" fill="url(#copy)"/>',
          );
          final scene = await p.prepare(budget: SceneResourceBudget());
          try {
            expect(
              scene.capability.isComplete,
              true,
              reason: '$type $units $spread',
            );
          } finally {
            scene.dispose();
          }
        }
      }
    }
  });
  test(
    'patterns retain their black outline and source-linked footprint',
    () async {
      final p = plan(
        '<defs><pattern id="p" width="8" height="8" patternUnits="userSpaceOnUse" patternTransform="translate(2 3) rotate(10)"><rect width="4" height="8" fill="green"/></pattern></defs><rect x="10" y="10" width="80" height="80" fill="url(#p)" stroke="black" stroke-width="2"/>',
      );
      final budget = SceneResourceBudget();
      final scene = await p.prepare(budget: budget);
      try {
        expect(scene.capability.isComplete, true);
        final image = await scene.picture!.toImage(100, 100);
        try {
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.rawStraightRgba,
          ))!;
          final bytes = data.buffer.asUint8List(), offset = (50 * 100 + 10) * 4;
          expect(bytes.sublist(offset, offset + 4), [0, 0, 0, 255]);
        } finally {
          image.dispose();
        }
      } finally {
        scene.dispose();
      }
      expect(budget.used.values.every((v) => v == 0), true);
    },
  );
  test(
    'use instances preserve referenced source, instance paths and ordering',
    () async {
      final p = plan(
        '<defs><symbol id="s" viewBox="5 5 10 10"><circle id="dot" cx="10" cy="10" r="5"/></symbol></defs><use id="a" href="#s" width="20" height="20"/><use id="b" href="#s" x="40" width="30" height="30"/>',
      );
      final scene = await p.prepare(budget: SceneResourceBudget());
      try {
        expect(scene.capability.isComplete, true);
        final node = p.document.nodes.singleWhere((n) => n.id == 'dot').index;
        final instances = scene.elements
            .where((e) => e.nodeIndex == node)
            .toList();
        expect(instances, hasLength(2));
        expect(instances[0].instancePath, isNot(instances[1].instancePath));
        expect(instances[0].paintOrdinal, lessThan(instances[1].paintOrdinal));
        expect(instances[0].transform.a, 2);
        expect(instances[1].transform.a, 3);
      } finally {
        scene.dispose();
      }
    },
  );
  test('references, operations, source and reference depths refuse before paint', () async {
    final cycle = plan(
      '<defs><g id="a"><use href="#b"/></g><g id="b"><use href="#a"/></g></defs><use href="#a"/>',
    );
    expect(cycle.capability, isA<MalformedSectionCapability>());
    final deep = plan(
      '${List.filled(70, '<g>').join()}<rect width="1" height="1"/>${List.filled(70, '</g>').join()}',
    );
    expect(deep.capability, isA<ResourceSectionCapability>());
    final refs = plan(
      '<defs>${List.generate(35, (j) => '<g id="g$j">${j == 34 ? '<rect width="1" height="1"/>' : '<use href="#g${j + 1}"/>'}</g>').join()}</defs><use href="#g0"/>',
    );
    expect(refs.capability, isA<ResourceSectionCapability>());
    final good = plan('<rect width="80" height="80"/>');
    final budget = SceneResourceBudget(
      limits: {
        ...SceneResourceBudget.provisionalLimits,
        SceneResource.vectorOperations: 1,
      },
    );
    final refused = await good.prepare(budget: budget);
    expect(refused.capability, isA<ResourceSectionCapability>());
    expect(refused.picture, isNull);
    refused.dispose();
    expect(budget.used.values.every((v) => v == 0), true);
  });
  test('unknown filter, missing image and unknown attributes publish no partial scene', () async {
    final filtered = plan(
      '<g id="x"><rect width="20" height="20"/></g>',
      css: '#x{filter:url(#unknown)}',
    );
    expect(filtered.capability, isA<UnsupportedSectionCapability>());
    final unknown = plan(
      '<rect width="20" height="20" vector-effect="non-scaling-stroke"/>',
    );
    expect(unknown.capability, isA<UnsupportedSectionCapability>());
    final scene = await plan(
      '<image href="missing.png" width="20" height="20"/>',
    ).prepare(budget: SceneResourceBudget());
    expect(scene.capability, isA<UnsupportedSectionCapability>());
    expect(scene.picture, isNull);
    expect(scene.geometry.fragments, isEmpty);
    scene.dispose();
  });
  test(
    'nested SVG images use admitted resources and retain the image source',
    () async {
      final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, 10, 5),
        ui.Paint()..color = const ui.Color(0xffff0000),
      );
      final picture = recorder.endRecording(),
          image = await recorderImage(picture);
      final budget = SceneResourceBudget();
      final scene =
          await plan(
            '<svg x="10" y="20" width="60" height="30" viewBox="5 5 20 10" preserveAspectRatio="xMaxYMin slice"><image id="image" href="local.png" x="5" y="5" width="20" height="10" preserveAspectRatio="none"/></svg>',
          ).prepare(
            budget: budget,
            images: SvgGraphicsImages(rasters: {'local.png': image}),
          );
      try {
        expect(scene.capability.isComplete, true);
        expect(
          scene.geometry.fragments.any(
            (f) => f.elementAnchor?.elementId == 'image',
          ),
          true,
        );
        expect(scene.geometry.clips, hasLength(2));
        expect(
          scene.geometry.paint.single.alphaFootprint!.alpha.any(
            (a) => a == 255,
          ),
          true,
        );
      } finally {
        scene.dispose();
        image.dispose();
        picture.dispose();
      }
      expect(budget.used.values.every((v) => v == 0), true);
    },
  );
  test('marker arcs expose only authored vertices and retain marker source identity', () async {
    final p = plan(
      '<defs><marker id="m" orient="auto-start-reverse" markerUnits="userSpaceOnUse"><circle id="dot" cx="1" cy="1" r="1"/></marker></defs><path d="M10 50 A30 30 0 1 1 70 50 L90 50" fill="none" stroke="black" marker-start="url(#m)" marker-mid="url(#m)" marker-end="url(#m)"/>',
    );
    final scene = await p.prepare(budget: SceneResourceBudget());
    try {
      expect(scene.capability.isComplete, true);
      final node = p.document.nodes.singleWhere((n) => n.id == 'dot').index;
      expect(scene.elements.where((e) => e.nodeIndex == node), hasLength(3));
    } finally {
      scene.dispose();
    }
  });
  test(
    'pattern strokes, object units and inherited content are admitted',
    () async {
      final p = plan(
        '<defs><pattern id="base" width=".2" height=".2" patternUnits="objectBoundingBox" patternContentUnits="objectBoundingBox"><rect width=".1" height=".2" fill="red"/></pattern><pattern id="copy" href="#base" patternTransform="rotate(5)"/></defs><rect x="20" y="20" width="60" height="60" fill="none" stroke="url(#copy)" stroke-width="5" stroke-dasharray="5 2"/>',
      );
      final budget = SceneResourceBudget();
      final scene = await p.prepare(budget: budget);
      try {
        expect(scene.capability.isComplete, true);
        expect(
          scene.geometry.paint.single.alphaFootprint!.alpha.any((a) => a > 0),
          true,
        );
      } finally {
        scene.dispose();
      }
      expect(budget.used.values.every((v) => v == 0), true);
    },
  );
  test('tiny patterns, excess stops and opacity layers are bounded', () async {
    final tiny = plan(
      '<defs><pattern id="p" width=".000001" height=".000001" patternUnits="userSpaceOnUse"><rect width="1" height="1"/></pattern></defs><rect width="100" height="100" fill="url(#p)"/>',
    );
    final scene = await tiny.prepare(budget: SceneResourceBudget());
    expect(scene.capability, isA<ResourceSectionCapability>());
    expect(scene.picture, isNull);
    scene.dispose();
    final stops = plan(
      '<defs><linearGradient id="g">${List.filled(4097, '<stop/>').join()}</linearGradient></defs>',
    );
    expect(stops.capability, isA<ResourceSectionCapability>());
    final layers = plan(
      '${List.filled(9, '<g opacity=".5">').join()}<rect width="1" height="1"/>${List.filled(9, '</g>').join()}',
    );
    expect(layers.capability, isA<ResourceSectionCapability>());
  });
  test('SVG presentation reuses selectors, importance and authored media', () {
    final doc = const SourceParser().parse(
      '<svg xmlns="http://www.w3.org/2000/svg"><rect id="r" class="paint" style="fill:green"/></svg>',
      mediaType: 'image/svg+xml',
    );
    final resolved = SvgPresentation.resolve(
      doc,
      [
        'rect{fill:red}.paint{fill:blue!important}@media screen and (min-width:80px) and (orientation:landscape){#r{stroke:orange}}',
      ],
      viewportWidth: 100,
      viewportHeight: 50,
    );
    expect(resolved.problems, isEmpty);
    final node = doc.nodes.singleWhere((n) => n.id == 'r').index;
    expect(resolved.values[node]!['fill'], 'blue');
    expect(resolved.values[node]!['stroke'], 'orange');
  });
  test(
    'Bezier bounds are tight and scene disposal leaves no compiler cache owner',
    () async {
      final count = svg.cache.count;
      final p = plan('<path id="curve" d="M0 0 Q50 100 100 0"/>');
      final budget = SceneResourceBudget();
      final scene = await p.prepare(budget: budget);
      expect(scene.capability.isComplete, true);
      final curve = scene.elements.singleWhere(
        (e) => p.document.node(e.nodeIndex).id == 'curve',
      );
      expect(curve.bounds.bottom, closeTo(50, 1e-8));
      scene.dispose();
      scene.dispose();
      expect(svg.cache.count, count);
      expect(budget.used.values.every((v) => v == 0), true);
    },
  );
  test(
    'cancellation drains native work and releases every partial owner',
    () async {
      final p = plan(
        '<rect width="80" height="80"/><circle cx="40" cy="40" r="20"/>',
      );
      final token = PublicationCancellation(), budget = SceneResourceBudget();
      final future = p.prepare(budget: budget, cancellation: token);
      token.cancel();
      await expectLater(future, throwsA(isA<PreparationCancelled>()));
      expect(budget.used.values.every((v) => v == 0), true);
    },
  );
}

Future<ui.Image> recorderImage(ui.Picture picture) => picture.toImage(10, 5);
