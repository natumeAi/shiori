import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/core/config/content_identity.dart';
import 'package:shiori/core/config/server_endpoint.dart';
import 'package:shiori/core/config/server_key.dart';
import 'package:shiori/features/reader/data/geometry/affine_transform.dart';
import 'package:shiori/features/reader/data/geometry/cluster_geometry.dart';
import 'package:shiori/features/reader/data/geometry/paint_geometry.dart';
import 'package:shiori/features/reader/data/geometry/source_fragment.dart';
import 'package:shiori/features/reader/data/geometry/source_geometry.dart';
import 'package:shiori/features/reader/data/layout/source_page_id.dart';
import 'package:shiori/features/reader/data/source/source_parser.dart';
import 'package:shiori/features/reader/engine/fixed/svg/svg_graphics.dart';

import '../../../tool/reader/fixed_layout_spike_pixels.dart';
import '../../../tool/reader/fixed_layout_svg_harness.dart';
import '../../../tool/reader/fixed_layout_svg_samples.dart';

SourcePageId _page(String stableId) => SourcePageId(
  content: ContentIdentity(
    BookKey(
      ServerKey(
        ServerEndpoint.parse('https://svg-geometry.example.test/').endpoint!,
      ),
      1,
    ),
    '0' * 64,
  ),
  sectionIndex: 0,
  spineIndex: 0,
  stableId: stableId,
);

SourceFragment _elementFragment(
  SourcePageId page,
  int node,
  int ordinal, {
  double opacity = 1,
}) => SourceFragment(
  page: page,
  nodeIndex: node,
  kind: SourceFragmentKind.element,
  textRange: null,
  clusters: const [],
  elementAnchor: SourceElementAnchor(nodeIndex: node),
  sourceToUnit: const AffineTransform.identity(),
  clipIds: const [],
  maskIds: const [],
  paintOrdinal: ordinal,
  effectiveOpacity: opacity,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, Object?> recordedReport;
  setUpAll(() async {
    recordedReport = await FixedLayoutSvgHarness().run();
  });
  test('replayed matching graphics failures fail the fidelity gate', () {
    final replay = jsonDecode(jsonEncode(recordedReport)) as Map;
    final boundary = (replay['cases'] as List).cast<Map>().singleWhere(
      (c) => c['id'] == 'svg-graphics-boundary',
    );
    boundary['pass'] = false;
    (boundary['pixels'] as Map)['pass'] = false;
    final fixed = boundary['fixed'] as Map;
    fixed['pixelPass'] = false;
    (fixed['pixels'] as Map)['pass'] = false;
    // Agreement is deliberately retained: identical failure is not fidelity.
    expect(fixed['parityPass'], true);
    replay['pass'] = false;
    expect(() => _expectGraphicsGate(replay), throwsA(isA<TestFailure>()));
  });
  for (final path in [
    ['geometry', 'pass'],
    ['pixels', 'pass'],
    ['fixed', 'geometry', 'pass'],
    ['fixed', 'pixelPass'],
    ['fixed', 'pixels', 'pass'],
    ['fixed', 'parityPass'],
  ]) {
    test('graphics gate independently requires ${path.join('.')}', () {
      final replay = jsonDecode(jsonEncode(recordedReport)) as Map;
      final boundary = (replay['cases'] as List).cast<Map>().singleWhere(
        (c) => c['id'] == 'svg-graphics-boundary',
      );
      // Replay one failed channel while all aggregate verdicts claim success.
      replay['pass'] = replay['fixedPass'] = boundary['pass'] = true;
      final fixed = boundary['fixed'] as Map;
      fixed['pass'] = fixed['pixelPass'] = fixed['parityPass'] = true;
      (boundary['geometry'] as Map)['pass'] = true;
      (boundary['pixels'] as Map)['pass'] = true;
      (fixed['geometry'] as Map)['pass'] = true;
      (fixed['pixels'] as Map)['pass'] = true;
      expect(() => _expectGraphicsGate(replay), returnsNormally);
      var target = boundary;
      for (final key in path.take(path.length - 1)) {
        target = target[key] as Map;
      }
      target[path.last] = false;
      expect(() => _expectGraphicsGate(replay), throwsA(isA<TestFailure>()));
    });
  }
  test(
    'production SVG graphics reports every required channel and refusal',
    () async {
      final report = recordedReport;
      expect(report['geometryToleranceCssPx'], .5);
      expect(report['d7ComponentAlphaThreshold'], 32);
      final cases = (report['cases'] as List).cast<Map>();
      expect(cases, hasLength(4));
      _expectGraphicsGate(report);
      for (final c in cases) {
        expect(
          c['typedCapabilityPass'],
          true,
          reason: '${c['id']}: ${c['constructs']}',
        );
        final fixed = c['fixed'] as Map;
        expect(fixed['parityPass'], true, reason: '${c['id']}');
        if (c['required'] == true) {
          expect(c['sourceGeometryComplete'], true);
          expect((c['geometry'] as Map)['comparisons'], greaterThan(0));
          expect((c['pixels'] as Map)['d4'], isA<Map>());
          expect(fixed['status'], 'prepared');
          expect((fixed['pixels'] as Map)['d4'], isA<Map>());
          expect(
            File('build/fixed-layout-svg/fixed-${c['id']}.png').existsSync(),
            true,
          );
          expect(
            (c['referencePaintStability']
                as Map)['twoAnimationFramesIdentical'],
            true,
          );
          expect(
            File('build/fixed-layout-svg/${c['id']}.png').existsSync(),
            true,
          );
        } else {
          expect(c['capability'], 'UnsupportedSectionCapability');
          expect(c['sourceFragments'], 0);
          expect(c['constructs'], contains('svg-filter'));
          expect(fixed['status'], 'refused');
          expect(fixed['picture'], false);
          expect(fixed['elements'], 0);
          expect(fixed['fragments'], 0);
        }
      }
    },
  );
  test('SVG geometry rejects a dropped use-instance fragment or swapped paint order', () {
    const source =
        '<html xmlns="http://www.w3.org/1999/xhtml"><body>'
        '<svg xmlns="http://www.w3.org/2000/svg" width="320" height="240" '
        'viewBox="0 0 320 240"><defs><rect id="r" x="5" y="5" width="40" '
        'height="40"/></defs><use href="#r" x="100" y="100"/></svg>'
        '</body></html>';
    final document = const SourceParser().parse(source);
    final svgNode = document.nodes.singleWhere((n) => n.localName == 'svg');
    final rectNode = document.nodes.singleWhere(
      (n) => n.localName == 'rect' && n.id == 'r',
    );
    final useNode = document.nodes.singleWhere((n) => n.localName == 'use');
    final page = _page('svg-geometry-negative');
    SourceFragment fragment(int node, int ordinal) =>
        _elementFragment(page, node, ordinal);
    List<SvgGraphicsElement> elements({required bool swapPaintOrder}) => [
      SvgGraphicsElement(
        svgNode.index,
        const [],
        const AffineTransform.identity(),
        swapPaintOrder ? 3 : 0,
        ui.Rect.fromLTWH(0, 0, 320, 240),
        const {'fill': 'black'},
        const [],
      ),
      SvgGraphicsElement(
        useNode.index,
        const [],
        const AffineTransform.identity(),
        swapPaintOrder ? 0 : 1,
        ui.Rect.fromLTWH(100, 100, 40, 40),
        const {'fill': 'black'},
        const [],
      ),
      SvgGraphicsElement(
        rectNode.index,
        [useNode.index],
        AffineTransform(1, 0, 0, 1, 100, 100),
        2,
        ui.Rect.fromLTWH(5, 5, 40, 40),
        const {'fill': 'black'},
        const [],
      ),
    ];
    List<SourceFragment> fragments({required bool dropped}) => [
      fragment(svgNode.index, 0),
      fragment(useNode.index, 1),
      if (!dropped) fragment(rectNode.index, 2),
    ];
    final reference = <String, Object?>{
      'graphics': {
        'elements': [
          {
            'tag': 'svg',
            'id': null,
            'ordinal': 0,
            'bounds': [0, 0, 320, 240],
            'screenCTM': [1, 0, 0, 1, 0, 0],
          },
          {
            'tag': 'defs',
            'id': null,
            'ordinal': 1,
            'bounds': [0, 0, 0, 0],
            'screenCTM': [1, 0, 0, 1, 0, 0],
          },
          {
            'tag': 'rect',
            'id': 'r',
            'ordinal': 2,
            'bounds': [5, 5, 40, 40],
            'screenCTM': [1, 0, 0, 1, 0, 0],
          },
          {
            'tag': 'use',
            'id': null,
            'ordinal': 3,
            'bounds': [100, 100, 40, 40],
            'screenCTM': [1, 0, 0, 1, 0, 0],
          },
        ],
      },
    };
    Map<String, Object?> evidence({
      bool dropped = false,
      bool swapped = false,
    }) => compareSvgGeometryEvidence(
      document: document,
      page: page,
      elements: elements(swapPaintOrder: swapped),
      fragments: fragments(dropped: dropped),
      completeness: const CompleteGeometry(),
      reference: reference,
    );
    final good = evidence();
    expect(good['pass'], true, reason: good.toString());
    expect(good['fragmentCoveragePass'], true);
    expect(good['useInstancePass'], true);
    expect(good['paintOrderPass'], true);
    final dropped = evidence(dropped: true);
    expect(dropped['pass'], false);
    expect(dropped['fragmentCoveragePass'], false);
    final swapped = evidence(swapped: true);
    expect(swapped['pass'], false);
    expect(swapped['paintOrderPass'], false);
  });
  test('D9 ignores hidden, clipped and transparent gradient paint', () {
    final page = _page('svg-samples-hidden');
    final actual = Uint8List(320 * 240 * 4);
    actual.setRange((10 * 320 + 10) * 4, (10 * 320 + 10) * 4 + 4, [
      0,
      0,
      0,
      255,
    ]);
    SpikeSampleRecord classify(
      String gradientAttributes, {
      double opacity = 1,
      bool clipped = false,
    }) {
      final document = const SourceParser().parse(
        '<html xmlns="http://www.w3.org/1999/xhtml"><body>'
        '<svg xmlns="http://www.w3.org/2000/svg" width="320" height="240">'
        '<defs><linearGradient id="g"/></defs>'
        '<rect id="solid" x="0" y="0" width="20" height="20" fill="black"/>'
        '<rect id="grad" x="0" y="0" width="20" height="20" '
        '$gradientAttributes/></svg></body></html>',
      );
      final solid = document.nodes.singleWhere((n) => n.id == 'solid');
      final gradient = document.nodes.singleWhere((n) => n.id == 'grad');
      final path = ui.Path()..addRect(ui.Rect.fromLTWH(0, 0, 20, 20));
      final gradientPaint = <String, String>{'fill': 'url(#g)'};
      if (gradientAttributes.contains('fill-opacity="0"')) {
        gradientPaint['fill-opacity'] = '0';
      }
      if (gradientAttributes.contains('visibility="hidden"')) {
        gradientPaint['visibility'] = 'hidden';
      }
      return classifySvgSamples(
        document: document,
        elements: [
          SvgGraphicsElement(
            solid.index,
            const [],
            const AffineTransform.identity(),
            1,
            ui.Rect.fromLTWH(0, 0, 20, 20),
            const {'fill': 'rgb(0, 0, 0)'},
            const [],
            fillPath: path,
          ),
          SvgGraphicsElement(
            gradient.index,
            const [],
            const AffineTransform.identity(),
            2,
            ui.Rect.fromLTWH(0, 0, 20, 20),
            gradientPaint,
            const [],
            fillPath: path,
            clipIds: clipped ? const ['out'] : const [],
          ),
        ],
        clips: clipped
            ? [
                GeometryClip(
                  id: 'out',
                  region: GeometryRegion(
                    left: 100,
                    top: 100,
                    width: 10,
                    height: 10,
                    transform: const AffineTransform.identity(),
                  ),
                ),
              ]
            : const [],
        fragments: [
          _elementFragment(page, solid.index, 1),
          _elementFragment(page, gradient.index, 2, opacity: opacity),
        ],
        paints: [
          for (final (node, ordinal, paintOpacity, ids, alpha) in [
            (solid.index, 1, 1.0, <String>[], 255),
            (
              gradient.index,
              2,
              opacity,
              clipped ? ['out'] : <String>[],
              gradientPaint['fill-opacity'] == '0' ? 0 : 255,
            ),
          ])
            GeometryPaint(
              nodeIndex: node,
              paintOrdinal: ordinal,
              region: GeometryRegion(
                left: 0,
                top: 0,
                width: 20,
                height: 20,
                transform: const AffineTransform.identity(),
              ),
              kind: GeometryPaintKind.image,
              effectiveOpacity: paintOpacity,
              exactCoverage: true,
              clipIds: ids,
              alphaFootprint: GeometryAlphaFootprint.uniform(
                width: 20,
                height: 20,
                pixelSize: 1,
                origin: GeometryPoint(0, 0),
                alpha: alpha,
              ),
            ),
        ],
        referenceComputedPaint: {
          solid.index: {'fill': 'rgb(0, 0, 0)'},
          gradient.index: gradientPaint,
        },
        samples: [
          {
            'x': 10,
            'y': 10,
            'rgba': [0, 0, 0, 255],
          },
        ],
        actual: actual,
      ).single;
    }

    expect(
      classify('visibility="visible" fill="url(#g)"').classification,
      SpikeSamplePaintClass.gradient,
    );
    for (final hidden in [
      classify('visibility="hidden" fill="url(#g)"'),
      classify('display="none" fill="url(#g)"'),
      classify('fill="url(#g)"', opacity: 0),
      classify('fill-opacity="0" fill="url(#g)"'),
      classify('fill="url(#g)"', clipped: true),
    ]) {
      expect(hidden.classification, SpikeSamplePaintClass.solid);
    }
  });
  test(
    'SVG geometry rejects two complete instance sequences swapping order',
    () {
      const source =
          '<html xmlns="http://www.w3.org/1999/xhtml"><body>'
          '<svg xmlns="http://www.w3.org/2000/svg" width="320" height="240">'
          '<defs><rect id="r" x="5" y="5" width="40" height="40"/>'
          '<circle id="c" cx="10" cy="10" r="10"/></defs>'
          '<use id="u1" href="#r" x="100" y="100"/>'
          '<use id="u2" href="#c" x="200" y="100"/>'
          '</svg></body></html>';
      final document = const SourceParser().parse(source);
      final svg = document.nodes.singleWhere((n) => n.localName == 'svg');
      final rect = document.nodes.singleWhere((n) => n.id == 'r');
      final circle = document.nodes.singleWhere((n) => n.id == 'c');
      final u1 = document.nodes.singleWhere((n) => n.id == 'u1');
      final u2 = document.nodes.singleWhere((n) => n.id == 'u2');
      final page = _page('svg-order-negative');
      List<SvgGraphicsElement> elements({required bool swapped}) => [
        SvgGraphicsElement(
          svg.index,
          const [],
          const AffineTransform.identity(),
          0,
          ui.Rect.fromLTWH(0, 0, 320, 240),
          const {'fill': 'black'},
          const [],
        ),
        SvgGraphicsElement(
          u1.index,
          const [],
          const AffineTransform.identity(),
          1,
          ui.Rect.fromLTWH(100, 100, 40, 40),
          const {'fill': 'black'},
          const [],
        ),
        SvgGraphicsElement(
          u2.index,
          const [],
          const AffineTransform.identity(),
          swapped ? 2 : 3,
          ui.Rect.fromLTWH(200, 100, 20, 20),
          const {'fill': 'black'},
          const [],
        ),
        SvgGraphicsElement(
          rect.index,
          [u1.index],
          AffineTransform(1, 0, 0, 1, 100, 100),
          swapped ? 3 : 2,
          ui.Rect.fromLTWH(5, 5, 40, 40),
          const {'fill': 'black'},
          const [],
        ),
        SvgGraphicsElement(
          circle.index,
          [u2.index],
          AffineTransform(1, 0, 0, 1, 200, 100),
          4,
          ui.Rect.fromLTWH(0, 0, 20, 20),
          const {'fill': 'black'},
          const [],
        ),
      ];
      List<SourceFragment> fragments({required bool swapped}) => [
        _elementFragment(page, svg.index, 0),
        _elementFragment(page, u1.index, 1),
        _elementFragment(page, u2.index, swapped ? 2 : 3),
        _elementFragment(page, rect.index, swapped ? 3 : 2),
        _elementFragment(page, circle.index, 4),
      ];
      final reference = <String, Object?>{
        'graphics': {
          'elements': [
            {
              'tag': 'svg',
              'id': null,
              'ordinal': 0,
              'bounds': [0, 0, 320, 240],
              'screenCTM': [1, 0, 0, 1, 0, 0],
            },
            {
              'tag': 'defs',
              'id': null,
              'ordinal': 1,
              'bounds': [0, 0, 0, 0],
              'screenCTM': [1, 0, 0, 1, 0, 0],
            },
            {
              'tag': 'rect',
              'id': 'r',
              'ordinal': 2,
              'bounds': [5, 5, 40, 40],
              'screenCTM': [1, 0, 0, 1, 0, 0],
            },
            {
              'tag': 'circle',
              'id': 'c',
              'ordinal': 3,
              'bounds': [0, 0, 20, 20],
              'screenCTM': [1, 0, 0, 1, 0, 0],
            },
            {
              'tag': 'use',
              'id': 'u1',
              'ordinal': 4,
              'bounds': [100, 100, 40, 40],
              'screenCTM': [1, 0, 0, 1, 0, 0],
            },
            {
              'tag': 'use',
              'id': 'u2',
              'ordinal': 5,
              'bounds': [200, 100, 20, 20],
              'screenCTM': [1, 0, 0, 1, 0, 0],
            },
          ],
        },
      };
      Map<String, Object?> evidence({required bool swapped}) =>
          compareSvgGeometryEvidence(
            document: document,
            page: page,
            elements: elements(swapped: swapped),
            fragments: fragments(swapped: swapped),
            completeness: const CompleteGeometry(),
            reference: reference,
          );
      final good = evidence(swapped: false);
      expect(good['pass'], true, reason: good.toString());
      final swapped = evidence(swapped: true);
      expect(swapped['pass'], false);
      expect(swapped['paintOrderPass'], false);
    },
  );
}

void _expectGraphicsGate(Map report) {
  final cases = (report['cases'] as List).cast<Map>();
  final failures = [
    for (final c in cases.where((c) => c['pass'] != true))
      {
        'id': c['id'],
        'geometry': (c['geometry'] as Map)['pass'],
        'pixels': (c['pixels'] as Map)['pass'],
        'samples': ((c['pixels'] as Map)['d4'] as Map?)?['samples'],
        'fixedPass': (c['fixed'] as Map?)?['pass'],
        'parityPass': (c['fixed'] as Map?)?['parityPass'],
      },
  ];
  expect(report['pass'], true, reason: jsonEncode(failures));
  expect(report['fixedPass'], true);
  for (final c in cases) {
    final fixed = c['fixed'] as Map;
    expect(c['pass'], true, reason: '${c['id']}');
    expect(fixed['pass'], true, reason: '${c['id']}: $fixed');
    expect(fixed['parityPass'], true, reason: '${c['id']}');
    if (c['required'] == true) {
      expect(
        (c['geometry'] as Map)['pass'],
        true,
        reason: '${c['id']} geometry',
      );
      expect((c['pixels'] as Map)['pass'], true, reason: '${c['id']} pixels');
      expect(
        (fixed['geometry'] as Map)['pass'],
        true,
        reason: '${c['id']} fixed geometry',
      );
      expect(fixed['pixelPass'], true, reason: '${c['id']} fixed pixels');
      expect(
        (fixed['pixels'] as Map)['pass'],
        true,
        reason: '${c['id']} fixed pixels',
      );
    }
  }
}
