import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/geometry/affine_transform.dart';
import 'package:shiori/features/reader/data/geometry/cluster_geometry.dart';
import 'package:shiori/features/reader/data/geometry/paint_geometry.dart';
import 'package:shiori/features/reader/data/geometry/source_geometry.dart';
import 'package:shiori/features/reader/data/geometry/source_fragment.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/resources/archive_reader_resource_source.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_scene_admission.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_section_preparer.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_source_lease.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_svg_text_fonts.dart';
import 'package:shiori/features/reader/engine/fixed/svg/svg_graphics.dart';
import 'package:shiori/features/reader/engine/layout/font_registry.dart';
import 'package:shiori/features/reader/engine/layout/font_format.dart';
import 'package:shiori/features/reader/engine/layout/process_font_budget.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/style/css_style_resolver.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';
import 'package:shiori/features/reader/engine/support/layout_flags.dart';

import '../../../../../../tool/reader/fixed_layout_scene_input.dart';
import '../../../../../../tool/reader/fixed_layout_svg_text_harness.dart';

final class _Fixture {
  _Fixture(String markup, {String? sourceOverride, String? fontPath}) {
    final corpus = jsonDecode(
      File('test/fixtures/reader/fixed_layout/corpus.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final template = (corpus['cases'] as List)
        .cast<Map<String, Object?>>()
        .firstWhere((e) => e['id'] == 'svg-text-positive');
    final source =
        sourceOverride ??
        '<html xmlns="http://www.w3.org/1999/xhtml"><head>'
            '<meta name="viewport" content="width=320,height=240"/>'
            '<style>@font-face{font-family:Fixture;src:url(/font.ttf)}'
            'html,body{margin:0;width:320px;height:240px}</style></head><body>'
            '<svg xmlns="http://www.w3.org/2000/svg" width="320" height="240">'
            '$markup</svg></body></html>';
    input = SceneHarnessInput(
      {...template, 'source': source},
      corpus,
      File(fontPath ?? (corpus['font'] as Map)['path'] as String)
          .readAsBytesSync(),
    );
    registry = FontRegistry(
      processBudget: process,
      register: (bytes, alias) async {
        registrations++;
        await ui.loadFontFromList(bytes, fontFamily: alias);
      },
    );
    lease = FixedSourceLease(
      page: input.page,
      document: input.document,
      styles: const CssStyleResolver().resolve(
        input.book,
        0,
        input.document,
        const ReaderSettings(),
        authoredViewport: AuthoredPageSize(320, 240),
      ),
      rendition: sectionRendition(input.book, 0),
      resources: ArchiveReaderResourceSource(input.book.archive),
      retainedSourceBytes: utf8.encode(source).length,
      releaseSource: () {
        releases++;
      },
    );
    preparer = FixedSectionPreparer(
      fonts: registry,
      drainFonts: registry.drainFonts,
    );
  }
  late final SceneHarnessInput input;
  late final FontRegistry registry;
  late final FixedSourceLease lease;
  late final FixedSectionPreparer preparer;
  final process = ProcessFontBudget();
  final budget = SceneResourceBudget();
  int registrations = 0, releases = 0;
  FixedSvgTextFontService? service;
  PreparedFixedScene? scene;
  Future<PreparedFixedScene> prepare() async {
    final plan = preparer.plan(lease);
    service = plan.svgFeatureHost.text as FixedSvgTextFontService;
    final reservation = budget.reserveUnit(
      sourcePages: 1,
      resources: plan.resources,
      sourceDepth: plan.sourceDepth,
      referenceDepth: plan.referenceDepth,
      layerDepth: plan.layerDepth,
    );
    final operation = preparer.prepare(
      plan,
      FixedSceneAdmission(
        plan: plan,
        sceneLease: reservation,
        pictureBytes: plan.pictureBytes,
        decodedImageBytes: plan.decodedImageBytes,
        reconcilePictureBytes: (_) => true,
        releaseReservations: reservation.release,
      ),
    );
    try {
      return scene = await operation.result;
    } finally {
      await operation.drained;
    }
  }

  void close() {
    scene?.dispose();
    scene?.dispose();
    lease.dispose();
    input.book.archive.close();
    expect(budget.used.values.every((v) => v == 0), true);
  }
}

String _text(String attrs, String body) =>
    '<text font-family="Fixture" font-size="20" $attrs>$body</text>';
List<SourceFragment> _fragments(PreparedFixedScene scene) => scene
    .geometry
    .fragments
    .where((f) => f.kind == SourceFragmentKind.svgText)
    .toList();
double _advance(SourceFragment fragment) => fragment.clusters.fold(
  0,
  (sum, c) =>
      sum +
      math.sqrt(
        math.pow(c.baselineEnd.x - c.baselineStart.x, 2) +
            math.pow(c.baselineEnd.y - c.baselineStart.y, 2),
      ),
);

Future<void> _expectTextCoverage(
  ui.Picture picture,
  SourceGeometry geometry,
  ui.Rect extent,
) async {
  expect(geometry.completeness, isA<CompleteGeometry>());
  final text = geometry.paint
      .where((p) => p.kind == GeometryPaintKind.text)
      .single;
  final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
  canvas.translate(-extent.left, -extent.top);
  canvas.drawPicture(picture);
  final shifted = recorder.endRecording();
  final image = await shifted.toImage(
    extent.width.toInt(),
    extent.height.toInt(),
  );
  try {
    final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
        .buffer
        .asUint8List();
    var painted = 0;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final alpha = rgba[(y * image.width + x) * 4 + 3];
        if (alpha > 0) painted++;
        expect(
          text.alphaFootprint!.alphaAt(
            GeometryPoint(extent.left + x + .5, extent.top + y + .5),
          ),
          alpha,
          reason: 'placed text alpha at $x,$y',
        );
      }
    }
    expect(painted, greaterThan(0));
  } finally {
    image.dispose();
    shifted.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    '80px SVG text in an offset XHTML box retains per-source evidence',
    () async {
      final f = _Fixture(
        '',
        sourceOverride:
            '<html xmlns="http://www.w3.org/1999/xhtml"><head>'
            '<meta name="viewport" content="width=320,height=240"/>'
            '<style>@font-face{font-family:Fixture;src:url(/font.ttf)}'
            'html,body{margin:0;width:320px;height:240px}</style></head><body>'
            '<div style="position:absolute;left:120px;top:30px;width:80px;height:80px">'
            '<svg xmlns="http://www.w3.org/2000/svg" width="80" height="80">'
            '${_text('x="10" y="40"', 'Ab')}</svg></div></body></html>',
      );
      try {
        final scene = await f.prepare();
        expect(_fragments(scene).single.sourceToUnit.e, 120);
        await _expectTextCoverage(
          scene.scene.picture,
          scene.geometry,
          const ui.Rect.fromLTWH(0, 0, 320, 240),
        );
      } finally {
        f.close();
      }
    },
  );
  test(
    'text equal-area prepare override uses the effective negative origin',
    () async {
      final f = _Fixture(_text('x="10" y="40"', 'Ab'));
      final budget = SceneResourceBudget();
      SvgGraphicsScene? scene;
      try {
        final base = f.preparer.plan(f.lease).svgPlans.single;
        await f.registry.loadResources(
          f.lease.resources,
          f.lease.styles.fontFaces,
          scope: f.lease.page.content.sha256,
          requiredFonts: true,
        );
        final plan = SvgGraphicsPlan.inspect(
          document: base.document,
          rootIndex: base.rootIndex,
          page: base.page,
          size: AuthoredPageSize(80, 80),
          host: base.host,
          resolvedPresentation: base.presentation,
          placement: AffineTransform(1, 0, 0, 1, 100, 0),
        );
        final effective = AffineTransform(1, 0, 0, 1, -100, 0);
        expect(
          plan.reservation()[SceneResource.layerPixels],
          plan.reservation(placement: effective)[SceneResource.layerPixels],
        );
        scene = await plan.prepare(budget: budget, placement: effective);
        expect(scene.capability.isComplete, true);
        await _expectTextCoverage(
          scene.picture!,
          scene.geometry,
          const ui.Rect.fromLTWH(-100, 0, 180, 80),
        );
      } finally {
        scene?.dispose();
        expect(budget.used.values.every((v) => v == 0), true);
        f.close();
      }
    },
  );
  test(
    'positions flatten across tspans; rotation repeats and dy accumulates',
    () async {
      final f = _Fixture(
        _text(
          'x="10 40 70 100" y="40"',
          '<tspan dx="1 2" rotate="0 10">Ab</tspan>'
              '<tspan dy="3 4" rotate="20">CD</tspan>',
        ),
      );
      try {
        final scene = await f.prepare();
        final clusters = _fragments(scene).expand((f) => f.clusters).toList();
        final expected = [(11, 40), (42, 40), (70, 43), (100, 47)];
        for (var i = 0; i < clusters.length; i++) {
          expect(clusters[i].baselineStart.x, closeTo(expected[i].$1, 1e-8));
          expect(clusters[i].baselineStart.y, closeTo(expected[i].$2, 1e-8));
        }
        expect(clusters[1].rotationRadians, closeTo(math.pi / 18, 1e-8));
        expect(clusters[3].rotationRadians, closeTo(math.pi / 9, 1e-8));
      } finally {
        f.close();
      }
    },
  );
  test('start middle and end anchors use shaped advance', () async {
    final f = _Fixture(
      [
        for (final anchor in ['start', 'middle', 'end'])
          _text('x="160" y="40" text-anchor="$anchor"', 'Ab'),
      ].join(),
    );
    try {
      final fragments = _fragments(await f.prepare());
      final width = _advance(fragments.first);
      for (var i = 0; i < 3; i++) {
        expect(
          fragments[i].clusters.first.baselineStart.x,
          closeTo(160 - width * i / 2, 1e-8),
        );
      }
      expect(f.registrations, 1);
      expect(f.process.faces, 1);
    } finally {
      f.close();
    }
  });
  test('whole tspan textLength has its own spacingAndGlyphs scope', () async {
    final f = _Fixture(
      _text(
        'x="20" y="40" textLength="100"',
        '<tspan textLength="180" lengthAdjust="spacingAndGlyphs">Ab</tspan>',
      ),
    );
    try {
      expect(
        _advance(_fragments(await f.prepare()).single),
        closeTo(180, 1e-8),
      );
    } finally {
      f.close();
    }
  });
  test('kerning auto and normal enable kern; none disables it', () async {
    final f = _Fixture(
      [
        for (final mode in ['auto', 'normal', 'none'])
          _text('x="20" y="40" font-kerning="$mode"', 'AVATAR'),
      ].join(),
    );
    try {
      final fragments = _fragments(await f.prepare());
      expect(_advance(fragments[0]), _advance(fragments[1]));
      expect(_advance(fragments[2]), greaterThan(_advance(fragments[0])));
      expect(f.registrations, 1);
    } finally {
      f.close();
    }
  });
  test(
    'boundary CSS kern=0 matches oracle through production SVG module',
    () async {
      const folder = 'test/fixtures/reader/fixed_layout';
      final corpus =
          jsonDecode(File('$folder/corpus.json').readAsStringSync()) as Map;
      final fixture = (corpus['cases'] as List).cast<Map>().singleWhere(
        (c) => c['id'] == 'svg-text-boundary',
      );
      final oracle =
          jsonDecode(File('$folder/oracle.json').readAsStringSync()) as Map;
      final reference = (oracle['cases'] as List)
          .cast<Map<String, Object?>>()
          .singleWhere((c) => c['id'] == fixture['id']);
      final f = _Fixture('', sourceOverride: fixture['source'] as String);
      SvgGraphicsScene? svg;
      final budget = SceneResourceBudget();
      try {
        final plan = f.preparer.plan(f.lease);
        final service = plan.svgFeatureHost.text as FixedSvgTextFontService;
        expect(
          service.presentation.values.values.any(
            (a) => a['font-kerning'] == 'none',
          ),
          true,
        );
        // This is deliberately a module diagnostic. The fixed row still checks
        // its own global CSS diagnostics and must remain red until its handoff.
        await f.registry.loadResources(
          f.lease.resources,
          f.lease.styles.fontFaces,
          scope: f.lease.page.content.sha256,
          requiredFonts: true,
        );
        svg = await plan.svgPlans.single.prepare(budget: budget);
        expect(svg.capability.isComplete, true);
        final measured = measureSvgTextSourceGeometry(
          svg.geometry,
          f.input.document,
          reference,
        );
        expect(measured['clusterConservation'], true);
        expect(measured['maximumCssPx'], lessThanOrEqualTo(.5));
        expect(measured['pass'], true);
        // ignore: avoid_print
        print(jsonEncode({'boundaryModuleOnly': measured}));
      } finally {
        svg?.dispose();
        expect(budget.used.values.every((v) => v == 0), true);
        f.close();
      }
    },
  );
  test('end anchor includes dx and letter/word spacing', () async {
    final f = _Fixture(
      [
        for (final anchor in ['start', 'end'])
          _text(
            'x="160" y="40" text-anchor="$anchor" '
                'dx="1 2 3" letter-spacing="2" word-spacing="3"',
            'A b',
          ),
      ].join(),
    );
    try {
      final fragments = _fragments(await f.prepare());
      final width = _advance(fragments.first) + 12;
      expect(
        fragments.last.clusters.first.baselineStart.x,
        closeTo(161 - width, 1e-8),
      );
      expect(fragments.last.clusters.last.baselineEnd.x, closeTo(161, 1e-8));
    } finally {
      f.close();
    }
  });
  test('text geometry keeps one transform and module paint order', () async {
    final f = _Fixture(
      '<g transform="translate(7 9)">'
      '<rect x="0" y="0" width="2" height="2"/>'
      '${_text('x="20" y="40" transform="translate(3 4)"', 'Ab')}'
      '<rect x="0" y="0" width="2" height="2"/></g>',
    );
    try {
      final scene = await f.prepare();
      final fragment = _fragments(scene).single;
      expect(fragment.clusters.first.baselineStart.x, 20);
      expect(fragment.clusters.first.baselineStart.y, 40);
      expect(fragment.sourceToUnit.e, 10);
      expect(fragment.sourceToUnit.f, 13);
      final paints = scene.geometry.paint;
      final text = paints.singleWhere((p) => p.nodeIndex == fragment.nodeIndex);
      expect(text.paintOrdinal, fragment.paintOrdinal);
      expect(paints.any((p) => p.paintOrdinal < text.paintOrdinal), true);
      expect(paints.any((p) => p.paintOrdinal > text.paintOrdinal), true);
    } finally {
      f.close();
    }
  });
  test('textPath ignores parent textLength and obeys its own length', () async {
    final f = _Fixture(
      '<defs><path id="p" d="M20 100 Q160 10 290 120"/></defs>${_text('textLength="40"', '<textPath href="#p" startOffset="5%" '
          'textLength="180" lengthAdjust="spacingAndGlyphs">Ab</textPath>')}',
    );
    try {
      final fragment = _fragments(await f.prepare()).single;
      expect(_advance(fragment), closeTo(180, 1e-8));
      expect(fragment.clusters.first.rotationRadians, lessThan(0));
    } finally {
      f.close();
    }
  });
  test('unsupported profiles refuse before font registration or lease allocation', () async {
    final cases = [
      _text('writing-mode="vertical-rl"', 'Ab'),
      _text('direction="rtl"', 'Ab'),
      _text('', '\u05d0'),
      _text('', 'A<tspan textLength="100">b</tspan>'),
      '<defs><path id="p" d="M0 0 L100 100"/></defs>${_text('', '<textPath href="#p">Ab</textPath>')}',
      _text('', '<tspan transform="translate(1 2)">Ab</tspan>'),
      _text('rotate="bad"', 'Ab'),
      _text('font-kerning="invalid"', 'Ab'),
      _text('startOffset="10"', 'Ab'),
      _text('width="100"', 'Ab'),
      _text('x="20" y="40 50" text-anchor="middle"', 'Ab'),
      '<defs><clipPath id="c"><rect width="100" height="100"/></clipPath></defs>'
          '<g clip-path="url(#c)">${_text('x="20" y="40"', 'Ab')}</g>',
    ];
    for (final markup in cases) {
      final f = _Fixture(markup);
      try {
        final plan = f.preparer.plan(f.lease);
        expect(plan.capability.isComplete, false, reason: markup);
        expect(f.registrations, 0);
        expect(f.process.bytes, 0);
      } finally {
        f.close();
      }
    }
  });
  test(
    'combining continuation positions and cross-node clusters refuse',
    () async {
      for (final body in [
        _text('x="20 60" y="40"', 'e\u0301'),
        _text('x="20" y="40"', 'f<tspan>i</tspan>'),
      ]) {
        final f = _Fixture(body);
        try {
          await expectLater(
            f.prepare(),
            throwsA(isA<FixedPreparationFailure>()),
          );
          expect(f.service!.liveLeases, 0);
          expect(f.releases, 1);
        } finally {
          f.close();
        }
      }
    },
  );
  test(
    'lease is immutable, coalesced and released once with scene disposal',
    () async {
      final f = _Fixture(_text('x="20" y="40"', 'Ab fi'));
      try {
        final scene = await f.prepare();
        expect(f.service!.liveLeases, 1);
        final bytes = f.process.registeredBytes;
        expect(f.process.faces, 1);
        final borrowed = await f.service!.acquire(
          SvgTextFontRequest(
            document: f.input.document,
            nodeIndex: 0,
            families: {'fixture'},
            textCodeUnits: 5,
          ),
        );
        expect(
          () => borrowed.fonts.single.bytes.setUint8(0, 0),
          throwsUnsupportedError,
        );
        borrowed.release();
        borrowed.release();
        expect(f.service!.liveLeases, 1);
        expect(f.registrations, 1);
        expect(f.process.registeredBytes, bytes);
        scene.dispose();
        scene.dispose();
        expect(f.service!.liveLeases, 0);
        expect(f.releases, 1);
        expect(f.process.registeredBytes, bytes);
        expect(f.budget.used.values.every((v) => v == 0), true);
      } finally {
        f.close();
      }
    },
  );
  test(
    'unadmitted host font refuses; missing glyph releases acquired lease',
    () async {
      final unadmitted = _Fixture(_text('', 'Ab'));
      try {
        final service = FixedSvgTextFontService(
          unadmitted.lease,
          unadmitted.registry,
        );
        await expectLater(
          service.acquire(
            SvgTextFontRequest(
              document: unadmitted.input.document,
              nodeIndex: 0,
              families: {'fixture'},
              textCodeUnits: 2,
            ),
          ),
          throwsA(isA<RequiredFontException>()),
        );
        expect(service.liveLeases, 0);
        expect(unadmitted.registrations, 0);
      } finally {
        unadmitted.close();
      }
      final missing = _Fixture(_text('', '\u{10ffff}'));
      try {
        await expectLater(missing.prepare(), throwsA(isA<Object>()));
        expect(missing.service!.liveLeases, 0);
        expect(missing.releases, 1);
        expect(missing.budget.used.values.every((v) => v == 0), true);
      } finally {
        missing.close();
      }
    },
  );
  test('WOFF2 faces convert and shape like their SFNT control', () async {
    Future<double> advance(String fontPath) async {
      final f = _Fixture(_text('x="10" y="40"', 'Ab fi Z'), fontPath: fontPath);
      try {
        final width = _advance(_fragments(await f.prepare()).single);
        expect(f.registrations, 1);
        return width;
      } finally {
        f.close();
      }
    }

    final control = await advance(
      'tool/oracle/fixtures/styles/EPUB/fonts/Roboto-Regular.ttf',
    );
    final woff2 = await advance(
      'test/fixtures/reader/fixed_layout/Roboto-Regular.woff2',
    );
    expect(control, greaterThan(0));
    expect(woff2, closeTo(control, 1e-9));
  });
}
