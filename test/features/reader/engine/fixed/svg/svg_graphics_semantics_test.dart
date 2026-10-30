import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/source/source_parser.dart';
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
    'CSS transform declarations are applied, not silently dropped',
    () async {
      final p = plan(
        '<rect id="r" x="10" y="10" width="20" height="20" style="fill:red;transform:translate(40px,0px)"/>',
      );
      final scene = await p.prepare(budget: SceneResourceBudget());
      try {
        expect(scene.capability, isA<CompleteSectionCapability>());
        final element = scene.elements.singleWhere(
          (e) => p.document.node(e.nodeIndex).id == 'r',
        );
        expect(element.transform.e, closeTo(40, 1e-9));
        expect(element.transform.f, closeTo(0, 1e-9));
      } finally {
        scene.dispose();
      }
    },
  );

  test('CSS geometry properties apply to the matching attributes', () async {
    final p = plan(
      '<rect id="r" x="10" y="10" width="20" height="20" style="width:40px;height:30px;x:5px;y:6px"/>',
    );
    final scene = await p.prepare(budget: SceneResourceBudget());
    try {
      expect(scene.capability, isA<CompleteSectionCapability>());
      final element = scene.elements.singleWhere(
        (e) => p.document.node(e.nodeIndex).id == 'r',
      );
      expect(element.bounds.left, closeTo(5, 1e-9));
      expect(element.bounds.top, closeTo(6, 1e-9));
      expect(element.bounds.width, closeTo(40, 1e-9));
      expect(element.bounds.height, closeTo(30, 1e-9));
    } finally {
      scene.dispose();
    }
    final path = plan(
      '<path id="p" d="M0 0L10 0" style=\'d:path("M0 0L20 0")\'/>',
    );
    final pathScene = await path.prepare(budget: SceneResourceBudget());
    try {
      expect(pathScene.capability, isA<CompleteSectionCapability>());
      final element = pathScene.elements.singleWhere(
        (e) => path.document.node(e.nodeIndex).id == 'p',
      );
      expect(element.bounds.width, closeTo(20, 1e-9));
    } finally {
      pathScene.dispose();
    }
  });

  test('unsupported CSS rendering declarations refuse the whole section', () {
    final p = plan(
      '<rect width="20" height="20" style="fill:red;font-size:12px"/>',
    );
    expect(p.capability, isA<UnsupportedSectionCapability>());
    expect(
      (p.capability as UnsupportedSectionCapability)
          .constructs
          .single
          .identifier,
      'svg-css-font-size',
    );
  });

  test('gradient stops resolve inherited currentColor from ancestors', () async {
    for (final css in ['', 'defs{color:red}']) {
      final p = plan(
        '<defs${css.isEmpty ? ' color="red"' : ''}><linearGradient id="g"><stop offset="0" stop-color="currentColor"/><stop offset="1" stop-color="currentColor"/></linearGradient></defs>'
        '<rect x="10" y="10" width="80" height="80" fill="url(#g)"/>',
        css: css,
      );
      final scene = await p.prepare(budget: SceneResourceBudget());
      try {
        expect(scene.capability, isA<CompleteSectionCapability>());
        final pixels = await _pixels(scene);
        final offset = (50 * 100 + 50) * 4;
        expect(pixels[offset], greaterThan(240), reason: css);
        expect(pixels[offset + 1], lessThan(15), reason: css);
        expect(pixels[offset + 2], lessThan(15), reason: css);
        expect(pixels[offset + 3], 255, reason: css);
      } finally {
        scene.dispose();
      }
    }
  });

  test('userSpaceOnUse pattern strokes paint a zero-height line', () async {
    final p = plan(
      '<defs><pattern id="p" width="4" height="4" patternUnits="userSpaceOnUse"><rect width="2" height="4" fill="red"/></pattern></defs>'
      '<line x1="10" y1="50" x2="90" y2="50" fill="none" stroke="url(#p)" stroke-width="4"/>',
    );
    final scene = await p.prepare(budget: SceneResourceBudget());
    try {
      expect(scene.capability, isA<CompleteSectionCapability>());
      final pixels = await _pixels(scene);
      final offset = (50 * 100 + 49) * 4;
      expect(pixels[offset], greaterThan(240));
      expect(pixels[offset + 1], lessThan(15));
      expect(pixels[offset + 3], 255);
    } finally {
      scene.dispose();
    }
  });

  test(
    'objectBoundingBox pattern on zero-height geometry is not rendered',
    () async {
      final p = plan(
        '<defs><pattern id="p" width=".5" height=".5"><rect width=".5" height=".5" fill="red"/></pattern></defs>'
        '<line x1="10" y1="50" x2="90" y2="50" fill="none" stroke="url(#p)" stroke-width="4"/>',
      );
      final scene = await p.prepare(budget: SceneResourceBudget());
      try {
        expect(scene.capability, isA<CompleteSectionCapability>());
        expect((await _pixels(scene)).any((v) => v != 0), false);
      } finally {
        scene.dispose();
      }
    },
  );

  test('zero-length dashes paint round and square caps only', () async {
    for (final cap in ['round', 'square']) {
      final p = plan(
        '<line x1="10" y1="50" x2="90" y2="50" fill="none" stroke="black" stroke-width="6" stroke-dasharray="0 12" stroke-linecap="$cap"/>',
      );
      final scene = await p.prepare(budget: SceneResourceBudget());
      try {
        expect(scene.capability, isA<CompleteSectionCapability>());
        final pixels = await _pixels(scene);
        expect(_alpha(pixels, 10, 50), 255, reason: cap);
        expect(_alpha(pixels, 46, 50), 255, reason: cap);
        expect(_alpha(pixels, 52, 50), 0, reason: cap);
        expect(_alpha(pixels, 82, 50), 255, reason: cap);
      } finally {
        scene.dispose();
      }
    }
    final endpoint = plan(
      '<line x1="10" y1="50" x2="34" y2="50" fill="none" stroke="black" stroke-width="6" stroke-dasharray="0 12" stroke-linecap="round"/>',
    );
    final endpointScene = await endpoint.prepare(budget: SceneResourceBudget());
    try {
      final pixels = await _pixels(endpointScene);
      expect(_alpha(pixels, 10, 50), 255);
      expect(_alpha(pixels, 22, 50), 255);
      expect(_alpha(pixels, 34, 50), 255);
    } finally {
      endpointScene.dispose();
    }
    final offset = plan(
      '<line x1="10" y1="50" x2="90" y2="50" fill="none" stroke="black" stroke-width="6" stroke-dasharray="0 12" stroke-dashoffset="6" stroke-linecap="round"/>',
    );
    final offsetScene = await offset.prepare(budget: SceneResourceBudget());
    try {
      final pixels = await _pixels(offsetScene);
      expect(_alpha(pixels, 10, 50), 0);
      expect(_alpha(pixels, 16, 50), 255);
    } finally {
      offsetScene.dispose();
    }
    final butt = plan(
      '<line x1="10" y1="50" x2="90" y2="50" fill="none" stroke="black" stroke-width="6" stroke-dasharray="0 12" stroke-linecap="butt"/>',
    );
    final scene = await butt.prepare(budget: SceneResourceBudget());
    try {
      expect(scene.capability, isA<CompleteSectionCapability>());
      expect((await _pixels(scene)).any((v) => v != 0), false);
    } finally {
      scene.dispose();
    }
  });
}

Future<List<int>> _pixels(SvgGraphicsScene scene) async {
  final image = await scene.picture!.toImage(100, 100);
  try {
    final data = (await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    ))!;
    return data.buffer.asUint8List().toList();
  } finally {
    image.dispose();
  }
}

int _alpha(List<int> pixels, int x, int y) => pixels[(y * 100 + x) * 4 + 3];
