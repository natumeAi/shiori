import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/geometry/source_fragment.dart';
import 'package:shiori/features/reader/data/geometry/source_geometry.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_scene.dart';
import 'package:shiori/features/reader/engine/layout/paragraph_factory.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/style/css_style_resolver.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';
import 'package:shiori/features/reader/engine/support/section_capability.dart';

import '../../contract_test_values.dart';
import '../style/style_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await ui.loadFontFromList(
      File('tool/oracle/fixtures/styles/EPUB/fonts/Roboto-Regular.ttf')
          .readAsBytesSync(),
      fontFamily: 'FixedSceneTest',
    );
  });
  Future<(FixedScene, StyleSample)> prepare(
    String body, {
    String css = '',
    SceneResourceBudget? budget,
  }) async {
    final sample = StyleSample.html(
      body,
      css: 'body{margin:0;font:20px Fixture}$css',
      metadata: '<meta property="rendition:layout">pre-paginated</meta>',
    );
    final styled = const CssStyleResolver().resolve(
      sample.book,
      0,
      sample.document,
      const ReaderSettings(),
      authoredViewport: AuthoredPageSize(320, 240),
    );
    final scene = await FixedSceneBuilder(
      document: sample.document,
      styles: styled,
      page: contractPage(),
      size: AuthoredPageSize(320, 240),
      fonts: ParagraphFonts(embedded: {'fixture': 'FixedSceneTest'}),
      budget: budget,
    ).build();
    addTearDown(scene.dispose);
    return (scene, sample);
  }

  for (final separator in ['<br/>', ' ']) {
    test('inline background has source-linked evidence on both lines: $separator', () async {
      final (scene, sample) = await prepare(
        '<p style="margin:0;width:30px"><span id="red" style="background:red">AA${separator}BB</span></p>',
      );
      expect(scene.capability.isComplete, true);
      final paints = scene.geometry.paint
          .where((p) => p.nodeIndex == sample.byId('red'))
          .toList();
      expect(paints, hasLength(2));
      expect(
        paints.every((p) => p.exactCoverage && p.alphaFootprint != null),
        true,
      );
      expect(paints[1].region.top, greaterThan(paints[0].region.top));
      final image = await scene.picture.toImage(320, 240);
      final data = (await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      ))!;
      for (final paint in paints) {
        final r = paint.region;
        final i = ((r.top + 1).floor() * 320 + (r.left + 1).floor()) * 4;
        expect(
          [data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2)],
          [255, 0, 0],
        );
      }
      image.dispose();
    });
  }

  test(
    'inline backgrounds retain their paragraph content clip and indent',
    () async {
      final (scene, sample) = await prepare(
        '<p id="clip" style="margin:0;width:24px;height:12px;overflow:hidden;text-indent:4px;white-space:nowrap">'
        '<span id="red" style="background:red;white-space:nowrap">AAAA</span></p>',
      );
      expect(scene.capability.isComplete, true);
      final paint = scene.geometry.paint.singleWhere(
        (p) => p.nodeIndex == sample.byId('red'),
      );
      expect(paint.clipIds, contains('box-${sample.byId('clip')}'));
      final image = await scene.picture.toImage(320, 240);
      final data = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      expect(data.getUint8((4 * 320 + 5) * 4 + 3), 255);
      expect(data.getUint8((4 * 320 + 25) * 4 + 3), 0);
      expect(data.getUint8((13 * 320 + 5) * 4 + 3), 0);
      image.dispose();
    },
  );

  test(
    'unsupported inline border refuses instead of dropping decoration',
    () async {
      final (scene, _) = await prepare(
        '<p><span style="border:2px solid red">AA</span></p>',
      );
      expect(scene.capability, isA<UnsupportedSectionCapability>());
    },
  );

  test(
    'positioned boxes use padding containing block and min beats max',
    () async {
      final (scene, sample) = await prepare(
        '<div id="p"><div id="x">Ab</div></div>',
        css: '#p{position:relative;width:200px;height:160px;padding:8px}#x{position:absolute;width:50%;height:20px;left:10%;top:12px;margin:3px;padding:4px;box-sizing:border-box;min-width:140px;max-width:40px}',
      );
      final box = scene.boxes.singleWhere(
        (b) => b.nodeIndex == sample.byId('x'),
      );
      expect(box.borderBox.left, closeTo(24.6, .001));
      expect(box.borderBox.top, 15);
      expect(box.borderBox.width, 140);
      expect(box.contentBox.width, 132);
      expect(scene.geometry.completeness, isA<CompleteGeometry>());
    },
  );
  test(
    'fixed, relative text and none retain authored coordinates and ranges',
    () async {
      final (scene, sample) = await prepare(
        '<div style="display:none">excluded</div><div id="f"><span style="position:relative;left:2px">Ab é</span></div>',
        css: '#f{position:fixed;width:100px;height:30px;right:2px;bottom:2px;padding:1px}',
      );
      final box = scene.boxes.singleWhere(
        (b) => b.nodeIndex == sample.byId('f'),
      );
      expect(box.borderBox.right, 318);
      expect(box.borderBox.bottom, 238);
      final text = scene.geometry.fragments.singleWhere(
        (f) => f.kind == SourceFragmentKind.xhtmlText,
      );
      expect(text.textRange!.end, 'Ab é'.length);
      expect(text.clusters.last.range.end - text.clusters.last.range.start, 2);
      expect(text.clusters.first.baselineStart.x, box.contentBox.left + 2);
      expect(
        scene.geometry.fragments.where(
          (f) =>
              f.elementAnchor != null &&
              f.elementAnchor!.nodeIndex != box.nodeIndex,
        ),
        isNotEmpty,
      );
    },
  );
  test(
    'sub/super grow line boxes and preserve nested source graphemes',
    () async {
      final (scene, sample) = await prepare(
        '<div id="p">A<sub>2</sub><sup><span>e&#x301;</span></sup><br/>B</div>',
        css: '#p{line-height:28px}',
      );
      expect(scene.capability.isComplete, true);
      expect(scene.geometry.completeness, isA<CompleteGeometry>());
      final fragments = scene.geometry.fragments
          .where((f) => f.kind == SourceFragmentKind.xhtmlText)
          .toList();
      final a = fragments.firstWhere(
        (f) => sample.document.node(f.nodeIndex).text == 'A',
      );
      final sub = fragments.firstWhere(
        (f) => sample.document.node(f.nodeIndex).text == '2',
      );
      final sup = fragments.firstWhere(
        (f) => sample.document.node(f.nodeIndex).text == 'e\u0301',
      );
      final b = fragments.firstWhere(
        (f) => sample.document.node(f.nodeIndex).text == 'B',
      );
      final baseline = a.clusters.single.baselineStart.y;
      expect(sub.clusters.single.baselineStart.y - baseline, closeTo(5, .0001));
      expect(
        baseline - sup.clusters.single.baselineStart.y,
        closeTo(20 / 3 + 1, .0001),
      );
      expect(sup.clusters.single.range.end, 2);
      expect(b.clusters.single.baselineStart.y - baseline, greaterThan(28));
      expect(
        scene.boxes
            .singleWhere((b) => b.nodeIndex == sample.byId('p'))
            .contentBox
            .height,
        closeTo(28 + 28 + 5 + 20 / 3 + 1, .001),
      );
    },
  );
  test(
    'wrapped sub/super keep source partitions and grow each affected line',
    () async {
      final (scene, _) = await prepare(
        '<div>A<sup>Ab Ab Ab Ab</sup><sub>2</sub></div>',
        css: 'div{width:40px;line-height:28px}',
      );
      expect(scene.capability.isComplete, true);
      expect(scene.geometry.completeness, isA<CompleteGeometry>());
      final fragment = scene.geometry.fragments.singleWhere(
        (f) => f.kind == SourceFragmentKind.xhtmlText && f.textRange!.end > 2,
      );
      expect(fragment.clusters.first.range.start, 0);
      expect(fragment.clusters.last.range.end, 11);
      expect(
        fragment.clusters.map((c) => c.baselineStart.y).toSet().length,
        greaterThan(1),
      );
    },
  );
  test('inline-block remains atomic in a painted paragraph', () async {
    final (scene, sample) = await prepare(
      '<div>Ab<span id="atomic" style="display:inline-block;width:30px;height:20px;background:red">Z</span>cd</div>',
    );
    final atomic = scene.boxes.singleWhere(
      (b) => b.nodeIndex == sample.byId('atomic'),
    );
    expect(atomic.borderBox.width, 30);
    expect(atomic.borderBox.left, greaterThan(20));
    expect(scene.capability.isComplete, true);
    expect(scene.geometry.completeness, isA<CompleteGeometry>());
  });
  test(
    'negative layers and nested positive contexts escape positioned auto',
    () async {
      final (scene, sample) = await prepare(
        '<div id="p" style="position:relative"><div id="high" style="position:absolute;z-index:8;width:10px;height:10px;background:red"></div></div><div id="low" style="position:absolute;z-index:2;width:10px;height:10px;background:blue"></div>',
      );
      final high = scene.geometry.paint.singleWhere(
        (p) => p.nodeIndex == sample.byId('high'),
      );
      final low = scene.geometry.paint.singleWhere(
        (p) => p.nodeIndex == sample.byId('low'),
      );
      expect(high.paintOrdinal, greaterThan(low.paintOrdinal));
      expect(high.alphaFootprint!.alpha.any((a) => a > 0), true);
    },
  );
  test('singular subtree paints nothing and exports no proof in a complete section', () async {
    final (singular, sample) = await prepare(
      '<div id="x"><div id="child" style="background:red">Ab</div></div><div id="visible" style="position:absolute;left:20px;top:20px;width:4px;height:4px;background:blue"></div>',
      css: '#x{transform:scaleX(0);overflow:hidden}',
    );
    expect(singular.capability.isComplete, true);
    expect(singular.geometry.completeness, isA<CompleteGeometry>());
    final suppressed = singular.boxes
        .where((box) => !box.hasVisibleTransform)
        .map((box) => box.nodeIndex)
        .toSet();
    expect(suppressed, containsAll([sample.byId('x'), sample.byId('child')]));
    expect(
      singular.geometry.fragments.any((f) => suppressed.contains(f.nodeIndex)),
      false,
    );
    expect(
      singular.geometry.fragments.where(
        (f) => f.kind == SourceFragmentKind.xhtmlText,
      ),
      isEmpty,
    );
    expect(singular.geometry.paint.map((p) => p.nodeIndex), [
      sample.byId('visible'),
    ]);
    final image = await singular.picture.toImage(320, 240);
    try {
      final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
          .buffer
          .asUint8List();
      expect(
        [
          for (var i = 3; i < rgba.length; i += 4)
            if (rgba[i] > 0) i ~/ 4,
        ],
        [
          for (var y = 20; y < 24; y++)
            for (var x = 20; x < 24; x++) y * 320 + x,
        ],
      );
    } finally {
      image.dispose();
    }
  });
  test('cycles and unknown CSS cannot publish complete evidence', () async {
    final (cycle, _) = await prepare(
      '<span style="display:inline-block"><div style="width:50%">Ab</div></span>',
    );
    expect(cycle.capability, isA<MalformedSectionCapability>());
    final (unknown, _) = await prepare(
      '<div id="x">Ab</div>',
      css: '#x{future-layout:active}',
    );
    expect(unknown.capability, isA<UnsupportedSectionCapability>());
  });
  test(
    'evidence admission fails explicitly and scene release is idempotent',
    () async {
      final budget = SceneResourceBudget(
        limits: {
          ...SceneResourceBudget.provisionalLimits,
          SceneResource.vectorBytes: 1,
        },
      );
      final (scene, _) = await prepare('<div>Ab</div>', budget: budget);
      expect(scene.capability, isA<ResourceSectionCapability>());
      expect(scene.geometry.completeness, isA<IncompleteGeometry>());
      expect(
        () => ReaderWorkGuard.callback(scene.dispose),
        throwsAssertionError,
      );
      scene.dispose();
      scene.dispose();
      expect(budget.used.values.every((v) => v == 0), true);
    },
  );
}
