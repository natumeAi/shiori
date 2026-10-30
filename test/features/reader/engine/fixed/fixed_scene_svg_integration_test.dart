import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/cfi/cfi.dart';
import 'package:shiori/features/reader/data/geometry/affine_transform.dart';
import 'package:shiori/features/reader/data/geometry/cluster_geometry.dart';
import 'package:shiori/features/reader/data/geometry/paint_geometry.dart';
import 'package:shiori/features/reader/data/geometry/source_geometry.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/resources/reader_resource_source.dart';
import 'package:shiori/features/reader/data/source/source_position.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_scene.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_scene_admission.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_section_preparer.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_source_lease.dart';
import 'package:shiori/features/reader/engine/fixed/svg/svg_graphics.dart';
import 'package:shiori/features/reader/engine/layout/font_registry.dart';
import 'package:shiori/features/reader/engine/layout/paragraph_factory.dart';
import 'package:shiori/features/reader/engine/layout/process_font_budget.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/support/layout_flags.dart';
import 'package:shiori/features/reader/engine/support/section_capability.dart';

import '../../contract_test_values.dart';
import '../style/style_test_support.dart';

final class _Resources implements ReaderResourceSource {
  _Resources(this.font);
  final Uint8List font;
  @override
  Uint8List? bytes(String path) => font;
  @override
  bool contains(String path) => true;
  @override
  int size(String path) => font.length;
  @override
  void dispose() {}
}

final class _ThrowingDisposeFeature extends SvgFeature {
  const _ThrowingDisposeFeature();
  @override
  String get key => 'test-throwing-dispose';
  @override
  Set<String> get tags => const {'rect'};
  @override
  Future<void> prepare(SvgFeaturePreparation preparation) async {
    for (final node in preparation.nodes) {
      preparation.markCovered(node);
    }
    preparation.onDispose(() => throw StateError('feature dispose'));
  }
}

final class _CountingDisposeFeature extends SvgFeature {
  @override
  String get key => 'test-counting-dispose';
  @override
  Set<String> get tags => const {'rect'};
  int disposed = 0;
  @override
  Future<void> prepare(SvgFeaturePreparation preparation) async {
    for (final node in preparation.nodes) {
      preparation.markCovered(node);
    }
    preparation.onDispose(() => disposed++);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final font = File('tool/oracle/fixtures/styles/EPUB/fonts/Roboto-Regular.ttf')
      .readAsBytesSync();

  FixedSectionPreparer preparer() => FixedSectionPreparer(
    fonts: FontRegistry(processBudget: ProcessFontBudget()),
    drainFonts: () async {},
  );

  FixedSourceLease source({required String body, String css = ''}) {
    final sample = StyleSample.html(
      body,
      css:
          '@font-face{font-family:Fixture;src:url(font.ttf)}'
          'body{margin:0;font:20px Fixture}$css',
      head: '<meta name="viewport" content="width=320,height=240"/>',
      files: {'font.ttf': font},
      metadata: '<meta property="rendition:layout">pre-paginated</meta>',
    );
    addTearDown(sample.book.archive.close);
    return FixedSourceLease(
      page: contractPage(),
      document: sample.document,
      styles: sample.styled,
      rendition: sectionRendition(sample.book, 0),
      resources: _Resources(Uint8List.fromList(font)),
      retainedSourceBytes: 1024,
      releaseSource: () {},
    );
  }

  Future<PreparedFixedScene> prepare(FixedSourceLease input) async {
    final p = preparer(), plan = p.plan(input);
    final budget = SceneResourceBudget();
    final lease = budget.reserveUnit(
      sourcePages: 1,
      resources: plan.resources,
      sourceDepth: plan.sourceDepth,
      layerDepth: plan.layerDepth,
    );
    addTearDown(() {
      if (!lease.isReleased) lease.release();
    });
    final operation = p.prepare(
      plan,
      FixedSceneAdmission(
        plan: plan,
        sceneLease: lease,
        pictureBytes: plan.pictureBytes,
        decodedImageBytes: plan.decodedImageBytes,
        reconcilePictureBytes: (_) => true,
        releaseReservations: lease.release,
      ),
    );
    final result = await operation.result;
    await operation.drained;
    return result;
  }

  Future<Uint8List> pixels(ui.Picture picture, int width, int height) async {
    final image = await picture.toImage(width, height);
    try {
      return (await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      ))!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  for (final c in [
    (
      name: 'absolute left/top',
      outer: '',
      inner: '',
      css: 'position:absolute;left:120px;top:30px',
      x: 120.0,
      y: 30.0,
    ),
    (
      name: 'absolute right/bottom',
      outer: '',
      inner: '',
      css: 'position:absolute;right:20px;bottom:25px',
      x: 260.0,
      y: 175.0,
    ),
    (
      name: 'absolute initial containing block through static ancestor',
      outer: 'margin-left:30px;margin-top:20px;width:200px;height:160px',
      inner: '',
      css: 'position:absolute;left:10%;top:25%',
      x: 32.0,
      y: 60.0,
    ),
    (
      name: 'percentage left/top',
      outer: 'position:absolute;left:30px;top:20px;width:200px;height:160px',
      inner: '',
      css: 'position:absolute;left:25%;top:25%',
      x: 80.0,
      y: 60.0,
    ),
    (
      name: 'percentage right/bottom',
      outer: 'position:absolute;left:30px;top:20px;width:200px;height:160px',
      inner: '',
      css: 'position:absolute;right:10%;bottom:25%',
      x: 170.0,
      y: 100.0,
    ),
    (
      name: 'fixed viewport percentages',
      outer: 'position:absolute;left:30px;top:20px;width:200px;height:160px',
      inner: '',
      css: 'position:fixed;left:50%;top:25%',
      x: 160.0,
      y: 60.0,
    ),
    (
      name: 'relative left/top',
      outer: 'position:absolute;left:30px;top:20px;width:200px;height:160px',
      inner: '',
      css: 'position:relative;left:12px;top:14px',
      x: 42.0,
      y: 34.0,
    ),
    (
      name: 'relative right/bottom percentages',
      outer: 'position:absolute;left:30px;top:20px;width:200px;height:160px',
      inner: '',
      css: 'position:relative;right:10%;bottom:5%',
      x: 10.0,
      y: 12.0,
    ),
    (
      name: 'nested positioned ancestors',
      outer: 'position:absolute;left:30px;top:20px;width:200px;height:160px',
      inner: 'position:absolute;left:20px;top:15px;width:160px;height:120px',
      css: 'position:absolute;right:10%;bottom:25%',
      x: 154.0,
      y: 85.0,
    ),
    (
      name: 'positioned padding containing block',
      outer: 'position:absolute;left:30px;top:20px;width:180px;height:140px;padding:10px',
      inner: '',
      css: 'position:absolute;left:25%;top:25%',
      x: 80.0,
      y: 60.0,
    ),
    (
      name: 'fixed right/bottom percentages',
      outer: 'position:absolute;left:30px;top:20px;width:200px;height:160px',
      inner: '',
      css: 'position:fixed;right:10%;bottom:25%',
      x: 248.0,
      y: 140.0,
    ),
    (
      name: 'transformed positioned ancestor',
      outer: 'position:absolute;left:30px;top:20px;width:200px;height:160px;transform:translate(10px,15px)',
      inner: '',
      css: 'position:absolute;left:25%;top:25%',
      x: 90.0,
      y: 75.0,
    ),
    (
      name: 'nested ancestor trailing placement',
      outer:
          'position:absolute;right:30px;bottom:20px;width:200px;height:160px',
      inner: 'position:relative;width:160px;height:120px',
      css: 'position:absolute;right:10%;bottom:25%',
      x: 194.0,
      y: 110.0,
    ),
    (
      name: 'fixed viewport under ancestor trailing placement',
      outer:
          'position:absolute;right:30px;bottom:20px;width:200px;height:160px',
      inner: 'position:relative;width:160px;height:120px',
      css: 'position:fixed;left:120px;top:70px',
      x: 120.0,
      y: 70.0,
    ),
  ]) {
    test('SVG CSS positioning: ${c.name}', () async {
      final input = source(
        body:
            '${c.outer.isEmpty ? '' : '<div style="${c.outer}">'}'
            '${c.inner.isEmpty ? '' : '<div style="${c.inner}">'}'
            '<svg id="positioned-svg" xmlns="http://www.w3.org/2000/svg" '
            'width="40" height="40" viewBox="0 0 20 20" '
            'style="display:block;${c.css}">'
            '<rect id="positioned-rect" x="5" y="5" width="10" height="10" fill="red"/>'
            '</svg>${c.inner.isEmpty ? '' : '</div>'}'
            '${c.outer.isEmpty ? '' : '</div>'}',
      );
      final result = await prepare(input);
      addTearDown(result.dispose);
      final rect = input.document.nodes
          .singleWhere((n) => n.id == 'positioned-rect')
          .index;
      final rgba = await pixels(result.scene.picture, 320, 240);
      final paint = result.geometry.paint.singleWhere(
        (p) => p.nodeIndex == rect,
      );
      // Independently authored expected pixels, including all transparent pixels.
      for (var y = 0; y < 240; y++) {
        for (var x = 0; x < 320; x++) {
          final expected =
              x >= c.x + 10 && x < c.x + 30 && y >= c.y + 10 && y < c.y + 30
              ? 255
              : 0;
          expect(
            rgba[(y * 320 + x) * 4 + 3],
            expected,
            reason: 'native at ($x,$y)',
          );
          expect(
            paint.alphaFootprint!.alphaAt(GeometryPoint(x + .5, y + .5)),
            expected,
            reason: 'evidence at ($x,$y)',
          );
        }
      }
      final fragment = result.geometry.fragments.singleWhere(
        (f) => f.nodeIndex == rect,
      );
      expect(fragment.sourceToUnit, AffineTransform(2, 0, 0, 2, c.x, c.y));
      final p = fragment.elementQuad.first, t = fragment.sourceToUnit;
      expect(
        GeometryPoint(t.a * p.x + t.c * p.y + t.e, t.b * p.x + t.d * p.y + t.f),
        GeometryPoint(c.x + 10, c.y + 10),
      );
      final position = SourcePosition(
        nodeIndex: fragment.elementAnchor!.nodeIndex,
        offset: 0,
      );
      expect(
        Cfi.resolveLocal(
          input.document,
          Cfi.export(input.document, position),
        ).start,
        position,
      );
      expect(result.geometry.completeness, isA<CompleteGeometry>());
      expect(result.scene.capability.isComplete, true);
    });
  }

  for (final position in ['absolute', 'fixed']) {
    test('nested span $position SVG bypasses inline placeholders', () async {
      final input = source(
        body:
            '<p style="margin:0"><span>prefix'
            '<svg id="out" xmlns="http://www.w3.org/2000/svg" '
            'width="40" height="40" style="position:$position;left:120px;top:70px">'
            '<rect id="out-rect" width="40" height="40" fill="red"/>'
            '</svg>suffix</span></p>',
      );
      final result = await prepare(input);
      addTearDown(result.dispose);
      final rect = input.document.nodes.singleWhere((n) => n.id == 'out-rect');
      final svg = input.document.nodes.singleWhere((n) => n.id == 'out');
      expect(
        result.scene.boxes
            .singleWhere((b) => b.nodeIndex == svg.index)
            .borderBox,
        const ui.Rect.fromLTWH(120, 70, 40, 40),
      );
      final paint = result.geometry.paint.singleWhere(
        (p) => p.nodeIndex == rect.index,
      );
      final rgba = await pixels(result.scene.picture, 320, 240);
      for (var y = 0; y < 240; y++) {
        for (var x = 0; x < 320; x++) {
          final expected = x >= 120 && x < 160 && y >= 70 && y < 110 ? 255 : 0;
          expect(
            paint.alphaFootprint!.alphaAt(GeometryPoint(x + .5, y + .5)),
            expected,
            reason: 'SVG evidence at ($x,$y)',
          );
          final offset = (y * 320 + x) * 4;
          // Other paragraph text is black; only the SVG contributes red pixels.
          expect(rgba[offset], expected, reason: 'native red at ($x,$y)');
          if (expected != 0) expect(rgba[offset + 3], 255);
        }
      }
      expect(result.scene.texts.single.block.text, 'prefixsuffix');
      expect(result.geometry.completeness, isA<CompleteGeometry>());
      expect(result.scene.capability.isComplete, true);
    });
  }

  for (final c in [
    (name: 'single line', before: 'prefix', after: 'suffix'),
    (name: 'line break', before: 'first<br/>last', after: 'suffix'),
    (
      name: 'nested relative span',
      before: 'outer<span style="position:relative;left:15px">inner',
      after: 'end</span>suffix',
    ),
  ]) {
    test('absolute SVG refuses unavailable inline containing block: ${c.name}', () async {
      final input = source(
        body:
            '<p style="margin:0"><span style="position:relative;left:30px">'
            '${c.before}<svg id="inline-cb" xmlns="http://www.w3.org/2000/svg" '
            'width="40" height="40" style="position:absolute;left:120px;top:70px">'
            '<rect width="40" height="40" fill="red"/></svg>${c.after}</span></p>',
      );
      final node = input.document.nodes
          .singleWhere((n) => n.id == 'inline-cb')
          .index;
      await expectLater(
        prepare(input).then((scene) {
          // Release an incorrectly published scene during the pre-fix run too.
          scene.dispose();
          return scene;
        }),
        throwsA(
          isA<FixedPreparationFailure>().having(
            (e) => e.capability,
            'typed inline containing-block refusal',
            isA<UnsupportedSectionCapability>()
                .having((c) => c.isComplete, 'complete', false)
                .having(
                  (c) => c.constructs.where(
                    (c) =>
                        c.identifier == 'inline-positioned-containing-block' &&
                        c.nodeIndex == node,
                  ),
                  'offending absolute descendant',
                  isNotEmpty,
                ),
          ),
        ),
      );
    });
  }

  for (final c in [
    (name: 'viewport fixed', display: '', position: 'fixed', x: 120),
    (
      name: 'positioned block',
      display: 'display:block;',
      position: 'absolute',
      x: 150,
    ),
  ]) {
    test(
      'inline containing-block refusal preserves ${c.name} SVG control',
      () async {
        final input = source(
          body:
              '<span style="${c.display}position:relative;left:30px">'
              '<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40" '
              'style="position:${c.position};left:120px;top:70px">'
              '<rect id="cb-control" width="40" height="40" fill="red"/></svg></span>',
        );
        final result = await prepare(input);
        addTearDown(result.dispose);
        final rect = input.document.nodes
            .singleWhere((n) => n.id == 'cb-control')
            .index;
        final paint = result.geometry.paint.singleWhere(
          (p) => p.nodeIndex == rect,
        );
        final rgba = await pixels(result.scene.picture, 320, 240);
        for (var y = 0; y < 240; y++) {
          for (var x = 0; x < 320; x++) {
            final expected = x >= c.x && x < c.x + 40 && y >= 70 && y < 110
                ? 255
                : 0;
            expect(
              rgba[(y * 320 + x) * 4 + 3],
              expected,
              reason: 'native ($x,$y)',
            );
            expect(
              paint.alphaFootprint!.alphaAt(GeometryPoint(x + .5, y + .5)),
              expected,
              reason: 'evidence ($x,$y)',
            );
          }
        }
        expect(result.geometry.completeness, isA<CompleteGeometry>());
        expect(result.scene.capability.isComplete, true);
      },
    );
  }

  test(
    'relative inline-block admits shifted paragraph with static control',
    () async {
      Future<PreparedFixedScene> inline(String css) => prepare(
        source(
          body:
              '<div>Ab<span id="atomic" style="display:inline-block;width:30px;'
              'height:20px;background:red;$css">Z</span>cd</div>',
        ),
      );
      final control = await inline('');
      addTearDown(control.dispose);
      final placed = await inline('position:relative;left:10px');
      addTearDown(placed.dispose);
      final node = placed.plan.source.document.nodes
          .singleWhere((n) => n.id == 'atomic')
          .index;
      final before = control.scene.boxes.singleWhere(
        (b) => b.nodeIndex == node,
      );
      final after = placed.scene.boxes.singleWhere((b) => b.nodeIndex == node);
      expect(after.borderBox, before.borderBox.shift(const ui.Offset(10, 0)));
      final point = after.borderBox.topLeft + const ui.Offset(2, 2);
      final paint = placed.geometry.paint.singleWhere(
        (p) => p.nodeIndex == node && p.kind == GeometryPaintKind.decoration,
      );
      expect(
        paint.alphaFootprint!.alphaAt(GeometryPoint(point.dx, point.dy)),
        255,
      );
      final rgba = await pixels(placed.scene.picture, 320, 240);
      final offset = (point.dy.floor() * 320 + point.dx.floor()) * 4;
      expect(rgba.sublist(offset, offset + 4), [255, 0, 0, 255]);
      expect(control.scene.capability.isComplete, true);
      expect(placed.geometry.completeness, isA<CompleteGeometry>());
      expect(placed.scene.capability.isComplete, true);
    },
  );

  test('SVG CSS positioning: relative inline placeholder', () async {
    Future<PreparedFixedScene> inline(String css) => prepare(
      source(
        body:
            '<div style="position:absolute;left:30px;top:20px;width:200px;height:160px">'
            '<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40" '
            'style="$css"><rect id="relative-rect" x="5" y="5" width="20" height="20" fill="red"/>'
            '</svg></div>',
      ),
    );
    final control = await inline('');
    addTearDown(control.dispose);
    final placed = await inline('position:relative;left:12px;top:14px');
    addTearDown(placed.dispose);
    final original = await pixels(control.scene.picture, 320, 240);
    final actual = await pixels(placed.scene.picture, 320, 240);
    final rect = placed.plan.source.document.nodes
        .singleWhere((n) => n.id == 'relative-rect')
        .index;
    final paint = placed.geometry.paint.singleWhere((p) => p.nodeIndex == rect);
    // Keep the native paragraph baseline (which can be fractional) and verify
    // the authored integer offset against the independent unpositioned control.
    for (var y = 0; y < 240; y++) {
      for (var x = 0; x < 320; x++) {
        final expected = x < 12 || y < 14
            ? 0
            : original[((y - 14) * 320 + x - 12) * 4 + 3];
        expect(
          actual[(y * 320 + x) * 4 + 3],
          expected,
          reason: 'native at ($x,$y)',
        );
        expect(
          paint.alphaFootprint!.alphaAt(GeometryPoint(x + .5, y + .5)),
          expected,
          reason: 'evidence at ($x,$y)',
        );
      }
    }
    final before = control.geometry.fragments.singleWhere(
      (f) => f.nodeIndex == rect,
    );
    final after = placed.geometry.fragments.singleWhere(
      (f) => f.nodeIndex == rect,
    );
    expect(
      after.sourceToUnit,
      AffineTransform(1, 0, 0, 1, 12, 14).compose(before.sourceToUnit),
    );
    final document = placed.plan.source.document;
    final position = SourcePosition(
      nodeIndex: after.elementAnchor!.nodeIndex,
      offset: 0,
    );
    expect(
      Cfi.resolveLocal(document, Cfi.export(document, position)).start,
      position,
    );
    expect(placed.geometry.completeness, isA<CompleteGeometry>());
    expect(placed.scene.capability.isComplete, true);
  });

  for (final css in [
    'position:sticky;left:10px',
    'position:absolute;left:calc(10px + 1%)',
  ]) {
    test('SVG unsupported CSS positioning refuses: $css', () async {
      await expectLater(
        prepare(
          source(
            body:
                '<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40" style="$css">'
                '<rect width="20" height="20"/></svg>',
          ),
        ),
        throwsA(
          isA<FixedPreparationFailure>()
              .having(
                (e) => e.capability.isComplete,
                'typed incomplete capability',
                false,
              )
              .having(
                (e) => e.capability.constructs.map((c) => c.identifier),
                'CSS positioning refusal',
                contains(
                  css.contains('sticky')
                      ? 'invalidValue:position'
                      : 'unsupportedUnit:calc',
                ),
              ),
        ),
      );
    });
  }

  for (final nested in [false, true]) {
    test(
      'inline SVG conserves its scene, source and paint: span=$nested',
      () async {
        final input = source(
          body:
              '<p style="margin:0">A${nested ? '<span>' : ''}'
              '<svg id="icon" xmlns="http://www.w3.org/2000/svg" width="20" height="16">'
              '<rect id="red" width="20" height="16" fill="red"/></svg>'
              '${nested ? '</span>' : ''}B</p>',
        );
        final result = await prepare(input);
        addTearDown(result.dispose);
        expect(result.plan.svgPlans, hasLength(1));
        expect(result.scene.svgScenes, hasLength(1));
        final red = input.document.nodes
            .singleWhere((n) => n.id == 'red')
            .index;
        expect(
          result.geometry.paint.where((p) => p.nodeIndex == red),
          isNotEmpty,
        );
        expect(
          result.geometry.fragments.where((f) => f.nodeIndex == red),
          isNotEmpty,
        );
        final data = await pixels(result.scene.picture, 320, 240);
        expect([
          for (var i = 0; i < data.length; i += 4)
            if (data[i] == 255 && data[i + 1] == 0 && data[i + 3] == 255) i,
        ], isNotEmpty);
        final box = result.scene.boxes.singleWhere(
          (b) =>
              b.nodeIndex ==
              input.document.nodes.singleWhere((n) => n.id == 'icon').index,
        );
        expect(box.borderBox.left, greaterThan(0));
        final center = box.borderBox.center;
        final i = (center.dy.floor() * 320 + center.dx.floor()) * 4;
        expect(data.sublist(i, i + 4), [255, 0, 0, 255]);
      },
    );
  }

  test('SVG presentation diagnostics reach the SVG module', () async {
    for (final inline in [false, true]) {
      final input = source(
        body:
            '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="80" '
            '${inline ? 'style="font-kerning:none"' : ''}>'
            '<text x="10" y="30">AVATAR</text></svg>',
        css: inline ? '' : 'svg{font-kerning:none}',
      );
      final result = await prepare(input);
      expect(result.scene.capability.isComplete, true);
      result.dispose();
    }
    final invalid = source(
      body:
          '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="80">'
          '<text x="10" y="30">AVATAR</text></svg>',
      css: 'svg{font-kerning:invalid}',
    );
    await expectLater(
      prepare(invalid),
      throwsA(
        isA<FixedPreparationFailure>().having(
          (e) => e.capability.constructs.map((c) => c.identifier),
          'SVG refusal',
          contains('svg-text-font-kerning'),
        ),
      ),
    );
  });

  test(
    'XHTML presentation diagnostics still refuse for mixed and separate rules',
    () async {
      for (final css in [
        'svg,div{font-kerning:none}',
        'svg{font-kerning:none}div{font-kerning:none}',
      ]) {
        final input = source(
          body:
              '<div>text</div><svg xmlns="http://www.w3.org/2000/svg" '
              'width="100" height="80"><text x="10" y="30">AVATAR</text></svg>',
          css: css,
        );
        await expectLater(
          prepare(input),
          throwsA(
            isA<FixedPreparationFailure>().having(
              (e) => e.capability.constructs.map((c) => c.identifier),
              'XHTML refusal',
              contains('unsupportedProperty:font-kerning'),
            ),
          ),
        );
      }
    },
  );

  test('SVG geometry and clips are placed exactly once through a transformed ancestor', () async {
    final input = source(
      body:
          '<div style="transform:translate(30px,20px)">'
          '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="80" viewBox="0 0 100 80">'
          '<rect x="5" y="5" width="20" height="20" fill="red"/>'
          '</svg></div>',
    );
    final result = await prepare(input);
    try {
      final document = result.plan.source.document;
      final svgIndex = document.nodes
          .singleWhere((n) => n.localName == 'svg')
          .index;
      final rectIndex = document.nodes
          .singleWhere((n) => n.localName == 'rect')
          .index;
      final box = result.scene.boxes.singleWhere(
        (b) => b.nodeIndex == svgIndex,
      );
      final placement = box.transform.compose(box.svgContentTransform!);
      expect(box.transform, isNot(const AffineTransform.identity()));

      final fragment = result.geometry.fragments.singleWhere(
        (f) => f.nodeIndex == rectIndex,
      );
      expect(fragment.sourceToUnit, placement);

      final paint = result.geometry.paint.singleWhere(
        (p) => p.nodeIndex == rectIndex,
      );
      expect(paint.region.transform, placement);

      final viewportClip = result.geometry.clips.singleWhere(
        (c) => c.id.startsWith('svg-') && c.id.endsWith('-$svgIndex'),
      );
      expect(viewportClip.region.transform, placement);
    } finally {
      result.dispose();
    }
  });

  test('disjoint nested SVG viewports keep their own clip chains', () async {
    final input = source(
      body:
          '<svg xmlns="http://www.w3.org/2000/svg" width="200" height="200" viewBox="0 0 200 200">'
          '<svg id="inside-a-svg" x="0" y="0" width="80" height="80" '
          'viewBox="0 0 80 80">'
          '<rect id="inside-a" x="10" y="10" width="40" height="40" fill="red"/>'
          '</svg>'
          '<svg id="inside-b-svg" x="100" y="100" width="80" height="80" '
          'viewBox="0 0 80 80">'
          '<rect id="inside-b" x="10" y="10" width="40" height="40" fill="blue"/>'
          '</svg></svg>',
    );
    final result = await prepare(input);
    try {
      final document = result.plan.source.document;
      final svgIndex = document.nodes
          .singleWhere(
            (n) =>
                n.localName == 'svg' &&
                n.parentIndex != null &&
                document.node(n.parentIndex!).namespaceUri !=
                    'http://www.w3.org/2000/svg',
          )
          .index;
      final svgBox = result.scene.boxes.singleWhere(
        (b) => b.nodeIndex == svgIndex,
      );
      final scene = svgBox.svgScene!;
      final bSvg = document.nodes.singleWhere((n) => n.id == 'inside-b-svg');
      final aSvg = document.nodes.singleWhere((n) => n.id == 'inside-a-svg');
      // The ids are supplied by the ids above; keep lookups explicit.
      final clipA = scene.geometry.clips.singleWhere(
        (c) => c.id.endsWith('-${aSvg.index}'),
      );
      final clipB = scene.geometry.clips.singleWhere(
        (c) => c.id.endsWith('-${bSvg.index}'),
      );
      final mergedA = 'svg-$svgIndex:${clipA.id}';
      final mergedB = 'svg-$svgIndex:${clipB.id}';
      expect(
        result.geometry.clips.map((c) => c.id),
        containsAll([mergedA, mergedB]),
      );

      final a = document.nodes.singleWhere((n) => n.id == 'inside-a').index;
      final b = document.nodes.singleWhere((n) => n.id == 'inside-b').index;
      final paintA = result.geometry.paint.singleWhere((p) => p.nodeIndex == a);
      final paintB = result.geometry.paint.singleWhere((p) => p.nodeIndex == b);
      expect(paintA.clipIds, contains(mergedA));
      expect(paintA.clipIds, isNot(contains(mergedB)));
      expect(paintB.clipIds, contains(mergedB));
      expect(paintB.clipIds, isNot(contains(mergedA)));

      final fragmentA = result.geometry.fragments.singleWhere(
        (f) => f.nodeIndex == a,
      );
      expect(fragmentA.clipIds, contains(mergedA));
      expect(fragmentA.clipIds, isNot(contains(mergedB)));
    } finally {
      result.dispose();
    }
  });

  test('XHTML paint after nested SVG groups keeps a unique later ordinal', () async {
    final input = source(
      body:
          '<div>'
          '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 100 100">'
          '<g><g><rect x="5" y="5" width="20" height="20" fill="red"/></g></g>'
          '</svg>'
          '<div id="after" style="width:10px;height:10px;background:blue"></div>'
          '</div>',
    );
    final result = await prepare(input);
    try {
      final document = result.plan.source.document;
      final svgIndex = document.nodes
          .singleWhere((n) => n.localName == 'svg')
          .index;
      final afterIndex = document.nodes
          .singleWhere((n) => n.id == 'after')
          .index;
      final svgBox = result.scene.boxes.singleWhere(
        (b) => b.nodeIndex == svgIndex,
      );
      final scene = svgBox.svgScene!;
      var maxSvgOrdinal = 0;
      for (final fragment in scene.geometry.fragments) {
        if (fragment.paintOrdinal > maxSvgOrdinal) {
          maxSvgOrdinal = fragment.paintOrdinal;
        }
      }
      for (final paint in scene.geometry.paint) {
        if (paint.paintOrdinal > maxSvgOrdinal) {
          maxSvgOrdinal = paint.paintOrdinal;
        }
      }
      final after = result.geometry.paint.singleWhere(
        (p) => p.nodeIndex == afterIndex,
      );
      expect(
        after.paintOrdinal,
        greaterThan(svgBox.paintOrdinal + maxSvgOrdinal),
      );

      final paintOrdinals = result.geometry.paint
          .map((p) => p.paintOrdinal)
          .toList();
      expect(paintOrdinals.toSet().length, paintOrdinals.length);
    } finally {
      result.dispose();
    }
  });

  test(
    'SVG color attributes survive while genuine CSS declarations still win',
    () async {
      for (final css in ['', 'defs{color:red}']) {
        final input = source(
          body:
              '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 100 100">'
              '<defs${css.isEmpty ? ' color="red"' : ''}>'
              '<linearGradient id="g">'
              '<stop offset="0" stop-color="currentColor"/>'
              '<stop offset="1" stop-color="currentColor"/>'
              '</linearGradient></defs>'
              '<rect x="10" y="10" width="80" height="80" fill="url(#g)"/>'
              '</svg>',
          css: css,
        );
        final result = await prepare(input);
        try {
          final rgba = await pixels(result.scene.picture, 320, 240);
          final offset = (50 * 320 + 50) * 4;
          expect(rgba.sublist(offset, offset + 4), [
            255,
            0,
            0,
            255,
          ], reason: css.isEmpty ? 'presentation attribute' : 'author CSS');
        } finally {
          result.dispose();
        }
      }
    },
  );

  test(
    'scene disposal releases every owner before rethrowing a feature failure',
    () async {
      final sample = StyleSample.html(
        '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 100 100">'
        '<rect x="5" y="5" width="20" height="20" fill="red"/></svg>'
        '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 100 100">'
        '<rect x="5" y="5" width="20" height="20" fill="blue"/></svg>',
        css: 'body{margin:0;font:20px Fixture}',
        files: {'font.ttf': font},
        metadata: '<meta property="rendition:layout">pre-paginated</meta>',
      );
      addTearDown(sample.book.archive.close);
      final roots = [
        for (final node in sample.document.nodes)
          if (node.localName == 'svg') node.index,
      ];
      final counting = _CountingDisposeFeature();
      final plans = {
        roots[0]: SvgGraphicsPlan.inspect(
          document: sample.document,
          rootIndex: roots[0],
          page: contractPage(),
          size: AuthoredPageSize(320, 240),
          features: SvgFeatureRegistry(const [_ThrowingDisposeFeature()]),
        ),
        roots[1]: SvgGraphicsPlan.inspect(
          document: sample.document,
          rootIndex: roots[1],
          page: contractPage(),
          size: AuthoredPageSize(320, 240),
          features: SvgFeatureRegistry([counting]),
        ),
      };
      final budget = SceneResourceBudget();
      final scene = await FixedSceneBuilder(
        document: sample.document,
        styles: sample.styled,
        page: contractPage(),
        size: AuthoredPageSize(320, 240),
        fonts: ParagraphFonts(embedded: {'fixture': 'FixedSceneTest'}),
        svgPlans: plans,
        budget: budget,
      ).build();
      expect(scene.geometry.completeness, isA<CompleteGeometry>());
      expect(() => scene.dispose(), throwsA(isA<StateError>()));
      expect(counting.disposed, 1);
      expect(budget.used.values.every((v) => v == 0), true);
      scene.dispose();
    },
  );
}
