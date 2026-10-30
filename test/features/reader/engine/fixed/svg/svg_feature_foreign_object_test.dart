import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/geometry/source_fragment.dart';
import 'package:shiori/features/reader/data/geometry/source_geometry.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/resources/reader_resource_source.dart';
import 'package:shiori/features/reader/data/source/source_parser.dart';
import 'package:shiori/features/reader/data/worker/publication_cancellation.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_scene.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_preparation_plan.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_source_lease.dart';
import 'package:shiori/features/reader/engine/fixed/svg/svg_graphics.dart';
import 'package:shiori/features/reader/engine/layout/paragraph_factory.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/pagination/preparation.dart';
import 'package:shiori/features/reader/engine/support/layout_flags.dart';
import 'package:shiori/features/reader/engine/support/section_capability.dart';

import '../../../contract_test_values.dart';
import '../../style/style_test_support.dart';

final class _Resources implements ReaderResourceSource {
  @override
  Uint8List? bytes(String path) => null;
  @override
  bool contains(String path) => false;
  @override
  int size(String path) => 0;
  @override
  void dispose() {}
}

final class _Probe implements SvgForeignObjectEvidenceLayoutService {
  _Probe(this.delegate, {this.cancel = false, this.invalidIdentity = false});
  final SvgForeignObjectEvidenceLayoutService delegate;
  final bool cancel, invalidIdentity;
  int calls = 0, releases = 0;
  late SvgForeignObjectEvidence evidence;
  @override
  bool get available => true;
  @override
  SvgForeignObjectEvidence evidenceFor(SvgForeignObjectLayout layout) =>
      evidence;
  @override
  Future<SvgForeignObjectLayout?> layout(
    SvgForeignObjectRequest request,
  ) async {
    calls++;
    final result = (await delegate.layout(request))!;
    final owned = delegate.evidenceFor(result);
    evidence = SvgForeignObjectEvidence(
      geometry: owned.geometry,
      dispose: () {
        releases++;
        owned.dispose();
      },
    );
    if (cancel) request.cancellation!.cancel();
    if (!invalidIdentity) return result;
    final f = result.fragments.first;
    return SvgForeignObjectLayout(
      picture: result.picture,
      bounds: result.bounds,
      clips: result.clips,
      fragments: [
        SourceFragment(
          page: f.page,
          nodeIndex: 0,
          kind: SourceFragmentKind.element,
          textRange: null,
          clusters: const [],
          elementAnchor: SourceElementAnchor(nodeIndex: 0),
          sourceToUnit: f.sourceToUnit,
          clipIds: f.clipIds,
          maskIds: const [],
          paintOrdinal: f.paintOrdinal,
          effectiveOpacity: 1,
        ),
      ],
    );
  }
}

final class _PictureOnly implements SvgForeignObjectLayoutService {
  @override
  bool get available => true;
  @override
  Future<SvgForeignObjectLayout?> layout(
    SvgForeignObjectRequest request,
  ) async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(ui.Offset.zero & request.viewport, ui.Paint());
    return SvgForeignObjectLayout(
      picture: recorder.endRecording(),
      bounds: ui.Offset.zero & request.viewport,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final font = File('tool/oracle/fixtures/styles/EPUB/fonts/Roboto-Regular.ttf')
      .readAsBytesSync();
  setUpAll(() => ui.loadFontFromList(font, fontFamily: 'ForeignTest'));
  const xhtml = 'http://www.w3.org/1999/xhtml';
  const body =
      '<div xmlns="$xhtml" style="font:20px Fixture">A<span '
      'style="position:relative;top:3px;left:2px">Z</span></div>';
  StyleSample sample(String inner, {String attrs = '', String tail = ''}) {
    final s = StyleSample.html(
      '<svg xmlns="http://www.w3.org/2000/svg" '
      'width="320" height="240"><g transform="translate(10 15)">'
      '<foreignObject x="20" y="30" width="180" height="120" $attrs>'
      '$inner</foreignObject></g>$tail</svg>',
      css: 'body{margin:0}',
      head: '<meta name="viewport" content="width=320,height=240"/>',
      metadata: '<meta property="rendition:layout">pre-paginated</meta>',
    );
    addTearDown(s.book.archive.close);
    return s;
  }

  _Probe service(StyleSample s, {bool cancel = false, bool invalid = false}) =>
      _Probe(
        FixedForeignObjectLayoutService(
          styles: s.styled,
          page: contractPage(),
          fonts: ParagraphFonts(embedded: const {'fixture': 'ForeignTest'}),
        ),
        cancel: cancel,
        invalidIdentity: invalid,
      );
  SvgGraphicsPlan plan(
    StyleSample s,
    SvgForeignObjectLayoutService host,
  ) => SvgGraphicsPlan.inspect(
    document: s.document,
    rootIndex: s.document.nodes.firstWhere((n) => n.localName == 'svg').index,
    page: contractPage(),
    size: AuthoredPageSize(320, 240),
    resolvedPresentation: {for (final n in s.document.nodes) n.index: const {}},
    host: SvgFeatureHost(
      foreignObject: host,
      text: const SvgUnavailableTextFontService(),
    ),
  );

  test(
    'real host preserves relative span geometry, clips and sibling paint order',
    () async {
      final s = sample(body, tail: '<rect id="after" width="4" height="4"/>');
      final host = service(s), budget = SceneResourceBudget();
      final scene = await plan(s, host).prepare(budget: budget);
      expect(scene.capability.isComplete, true);
      expect(scene.geometry.completeness, isA<CompleteGeometry>());
      final texts = scene.geometry.fragments
          .where((f) => f.kind == SourceFragmentKind.xhtmlText)
          .toList();
      expect(texts, hasLength(2));
      expect(
        texts.last.clusters.single.baselineStart.y -
            texts.first.clusters.single.baselineStart.y,
        3,
      );
      expect(texts.last.sourceToUnit.e, 30);
      expect(texts.last.sourceToUnit.f, 45);
      expect(texts.every((f) => f.clipIds.length >= 2), true);
      final after = s.document.getElementById('after')!.index;
      final ordinal = scene.geometry.paint
          .singleWhere((p) => p.nodeIndex == after)
          .paintOrdinal;
      expect(
        scene.geometry.paint
            .where((p) => p.nodeIndex != after)
            .every((p) => p.paintOrdinal < ordinal),
        true,
      );
      scene.dispose();
      scene.dispose();
      expect(host.releases, 1);
      expect(budget.used.values.every((v) => v == 0), true);
    },
  );

  test('resource refusal happens before the host allocates', () async {
    final s = sample(body), host = service(s);
    final budget = SceneResourceBudget(
      limits: {
        ...SceneResourceBudget.provisionalLimits,
        SceneResource.sourceNodes: 1,
      },
    );
    final scene = await plan(s, host).prepare(budget: budget);
    expect(scene.capability, isA<ResourceSectionCapability>());
    expect(host.calls, 0);
    scene.dispose();
  });

  test('picture-only hosts cannot claim internal geometry complete', () async {
    final s = sample(body), budget = SceneResourceBudget();
    final scene = await plan(s, _PictureOnly()).prepare(budget: budget);
    expect(scene.geometry.completeness, isA<IncompleteGeometry>());
    expect(
      (scene.geometry.completeness as IncompleteGeometry).issues.any(
        (i) => i.reason.contains('internal paint evidence'),
      ),
      true,
    );
    scene.dispose();
    expect(budget.used.values.every((v) => v == 0), true);
  });

  test(
    'custom SVG clipping remains incomplete until child evidence is processed',
    () async {
      final s = sample(
        body,
        attrs: 'clip-path="url(#clip)"',
        tail: '<defs><clipPath id="clip"><rect width="50" height="60"/></clipPath></defs>',
      );
      final scene = await plan(
        s,
        service(s),
      ).prepare(budget: SceneResourceBudget());
      expect(scene.geometry.completeness, isA<IncompleteGeometry>());
      expect(
        (scene.geometry.completeness as IncompleteGeometry).issues.any(
          (i) => i.reason.contains('per-source evidence postpass'),
        ),
        true,
      );
      scene.dispose();
    },
  );

  test('inline XHTML siblings share one host line and hidden SVG exports no visibility', () async {
    for (final hidden in [false, true]) {
      final s = sample(
        '<span xmlns="$xhtml">A</span><span xmlns="$xhtml">B</span>',
        attrs: hidden ? 'visibility="hidden"' : '',
      );
      final scene = await plan(
        s,
        service(s),
      ).prepare(budget: SceneResourceBudget());
      expect(scene.capability.isComplete, true);
      final texts = scene.geometry.fragments
          .where((f) => f.kind == SourceFragmentKind.xhtmlText)
          .toList();
      expect(texts, hasLength(2));
      expect(
        texts.first.clusters.single.baselineStart.y,
        texts.last.clusters.single.baselineStart.y,
      );
      expect(
        texts.last.clusters.single.baselineStart.x,
        greaterThan(texts.first.clusters.single.baselineStart.x),
      );
      expect(texts.every((f) => f.effectiveOpacity == (hidden ? 0 : 1)), true);
      if (hidden) {
        expect(
          scene.geometry.paint.every((p) => p.effectiveOpacity == 0),
          true,
        );
      }
      scene.dispose();
    }
  });

  test(
    'repeated foreignObject references keep distinct clips and paint ordinals',
    () async {
      final s = sample(
        '<div xmlns="$xhtml">A</div>',
        attrs: 'id="foreign"',
        tail: '<use href="#foreign" x="30"/>',
      );
      final host = service(s), budget = SceneResourceBudget();
      final scene = await plan(s, host).prepare(budget: budget);
      expect(scene.capability.isComplete, true);
      final texts = scene.geometry.fragments
          .where((f) => f.kind == SourceFragmentKind.xhtmlText)
          .toList();
      expect(texts, hasLength(2));
      expect(texts.first.paintOrdinal, isNot(texts.last.paintOrdinal));
      expect(texts.first.clipIds.last, isNot(texts.last.clipIds.last));
      scene.dispose();
      expect(host.releases, 2);
      expect(budget.used.values.every((v) => v == 0), true);
    },
  );

  for (final failure in ['cancel', 'identity']) {
    test('$failure releases host paragraphs and pictures once', () async {
      final s = sample(body),
          host = service(
            s,
            cancel: failure == 'cancel',
            invalid: failure == 'identity',
          );
      final budget = SceneResourceBudget();
      if (failure == 'cancel') {
        await expectLater(
          plan(
            s,
            host,
          ).prepare(budget: budget, cancellation: PublicationCancellation()),
          throwsA(isA<PreparationCancelled>()),
        );
      } else {
        final scene = await plan(s, host).prepare(budget: budget);
        expect(
          scene.capability.constructs.single.identifier,
          'svg-foreignObject-source-identity',
        );
        scene.dispose();
      }
      expect(host.releases, 1);
      expect(budget.used.values.every((v) => v == 0), true);
    });
  }

  for (final (content, attrs, identifier) in [
    ('<div xmlns="urn:wrong"/>', '', 'svg-foreignObject-namespace'),
    ('<script xmlns="$xhtml"/>', '', 'svg-foreignObject-script'),
    ('<form xmlns="$xhtml"/>', '', 'svg-foreignObject-form'),
    ('<input xmlns="$xhtml"/>', '', 'svg-foreignObject-input'),
    ('<iframe xmlns="$xhtml"/>', '', 'svg-foreignObject-iframe'),
    (
      '<div xmlns="$xhtml" onclick="bad()"/>',
      '',
      'svg-foreignObject-active-attribute',
    ),
    (
      '<div xmlns="$xhtml"/>',
      'requiredExtensions="urn:unsupported"',
      'svg-foreignObject-requiredExtensions',
    ),
    (
      '<div xmlns="$xhtml"/>',
      'overflow="visible"',
      'svg-foreignObject-overflow-visible',
    ),
  ]) {
    test('admission refuses $identifier without host layout', () {
      final s = sample(body), host = service(s);
      final document = const SourceParser().parse(
        '<svg xmlns="http://www.w3.org/2000/svg" '
        'width="100" height="100"><foreignObject width="80" height="80" $attrs>'
        '$content</foreignObject></svg>',
        mediaType: 'image/svg+xml',
        protect: false,
      );
      final p = SvgGraphicsPlan.inspect(
        document: document,
        rootIndex: document.documentElementIndex,
        page: contractPage(),
        size: AuthoredPageSize(100, 100),
        host: SvgFeatureHost(
          foreignObject: host,
          text: const SvgUnavailableTextFontService(),
        ),
      );
      expect(p.capability.constructs.single.identifier, identifier);
      expect(host.calls, 0);
    });
  }

  test('zero viewport needs no host allocation', () async {
    final s = sample(body);
    final document = const SourceParser().parse(
      '<svg xmlns="http://www.w3.org/2000/svg" '
      'width="100" height="100"><foreignObject width="0" height="80"/></svg>',
      mediaType: 'image/svg+xml',
    );
    final host = service(s);
    final p = SvgGraphicsPlan.inspect(
      document: document,
      rootIndex: document.documentElementIndex,
      page: contractPage(),
      size: AuthoredPageSize(100, 100),
      host: SvgFeatureHost(
        foreignObject: host,
        text: const SvgUnavailableTextFontService(),
      ),
    );
    final scene = await p.prepare(budget: SceneResourceBudget());
    expect(scene.capability.isComplete, true);
    expect(host.calls, 0);
    scene.dispose();
  });

  test('negative viewport is malformed before host allocation', () {
    final s = sample(body), host = service(s);
    final document = const SourceParser().parse(
      '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">'
      '<foreignObject width="-1" height="80"/></svg>',
      mediaType: 'image/svg+xml',
    );
    final p = SvgGraphicsPlan.inspect(
      document: document,
      rootIndex: document.documentElementIndex,
      page: contractPage(),
      size: AuthoredPageSize(100, 100),
      host: SvgFeatureHost(
        foreignObject: host,
        text: const SvgUnavailableTextFontService(),
      ),
    );
    expect(p.capability, isA<MalformedSectionCapability>());
    expect(p.capability.constructs.single.identifier, 'svg-foreignObject-size');
    expect(host.calls, 0);
  });

  test(
    'fixed whole-unit sourceNodes includes repeated SVG reference charges',
    () {
      final uses = List.filled(30, '<use href="#shape"/>').join();
      final s = sample(
        body,
        tail:
            '<defs><g id="shape"><rect width="1" height="1"/>'
            '<rect x="2" width="1" height="1"/></g></defs>$uses',
      );
      final source = FixedSourceLease(
        page: contractPage(),
        document: s.document,
        styles: s.styled,
        rendition: sectionRendition(s.book, 0),
        resources: _Resources(),
        retainedSourceBytes: 1024,
        releaseSource: () {},
      );
      addTearDown(source.dispose);
      final p = FixedPreparationPlan.inspect(source);
      final svgNodes = p.svgPlans.fold(
        0,
        (sum, p) => sum + p.resources[SceneResource.sourceNodes]!,
      );
      expect(svgNodes, greaterThan(s.document.nodes.length));
      expect(
        p.resources[SceneResource.sourceNodes],
        greaterThanOrEqualTo(svgNodes),
      );
      expect(
        p.resources[SceneResource.sourceNodes],
        greaterThan(s.document.nodes.length),
      );
      expect(p.svgFeatureHost.foreignObject.available, true);
      expect(p.svgFeatureHost.text.available, false);
      final tooSmall = SceneResourceBudget(
        limits: {
          ...SceneResourceBudget.provisionalLimits,
          SceneResource.sourceNodes: s.document.nodes.length,
        },
      );
      expect(
        () => tooSmall.reserveUnit(sourcePages: 1, resources: p.resources),
        throwsA(isA<SceneAdmissionException>()),
      );
    },
  );
}
