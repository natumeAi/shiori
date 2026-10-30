import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/geometry/affine_transform.dart';
import 'package:shiori/features/reader/data/geometry/cluster_geometry.dart';
import 'package:shiori/features/reader/data/geometry/paint_geometry.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/resources/archive_reader_resource_source.dart';
import 'package:shiori/features/reader/data/source/source_parser.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_scene_admission.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_section_preparer.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_source_lease.dart';
import 'package:shiori/features/reader/engine/fixed/svg/svg_graphics.dart';
import 'package:shiori/features/reader/engine/fixed/svg/svg_presentation.dart';
import 'package:shiori/features/reader/engine/layout/font_registry.dart';
import 'package:shiori/features/reader/engine/layout/process_font_budget.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/support/layout_flags.dart';

import '../../../tool/reader/fixed_layout_spike_pixels.dart';
import '../../../tool/reader/fixed_layout_svg_samples.dart';
import '../../features/reader/contract_test_values.dart';
import '../../features/reader/engine/style/style_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final filterOn in ['attribute', 'style', 'ancestor']) {
    test('D9 requires exact feFlood output via $filterOn', () async {
      final attribute = filterOn == 'attribute' ? 'filter="url(#f)"' : '';
      final style = filterOn == 'style' ? 'style="filter:url(#f)"' : '';
      final document = const SourceParser().parse(
        '<svg xmlns="http://www.w3.org/2000/svg" width="320" height="240">'
        '<defs><linearGradient id="g"><stop stop-color="red"/>'
        '<stop offset="1" stop-color="blue"/></linearGradient>'
        '<filter id="f" filterUnits="userSpaceOnUse" x="0" y="0" '
        'width="100" height="100"><feFlood flood-color="red"/></filter></defs>'
        '<rect width="100" height="100" fill="black"/>'
        '<g id="parent" ${filterOn == 'ancestor' ? 'filter="url(#f)"' : ''}>'
        '<rect id="filtered" width="100" height="100" fill="url(#g)" '
        '$attribute $style/></g>'
        '<rect x="120" width="100" height="100" fill="black"/>'
        '<rect id="top" x="120" width="100" height="100" '
        'fill="url(#g)" filter="none"/></svg>',
        mediaType: 'image/svg+xml',
      );
      final budget = SceneResourceBudget();
      final presentation = SvgPresentation.resolve(
        document,
        const [],
        viewportWidth: 320,
        viewportHeight: 240,
      );
      final scene = await SvgGraphicsPlan.inspect(
        document: document,
        rootIndex: document.documentElementIndex,
        page: contractPage(),
        size: AuthoredPageSize(320, 240),
        resolvedPresentation: presentation.values,
        presentationProblems: presentation.problems,
      ).prepare(budget: budget);
      try {
        expect(scene.capability.isComplete, true);
        final image = await scene.picture!.toImage(320, 240);
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        ))!.buffer.asUint8List();
        image.dispose();
        final filteredNode = document.nodes.singleWhere(
          (n) => n.id == (filterOn == 'ancestor' ? 'parent' : 'filtered'),
        );
        final output = scene.geometry.paint.singleWhere(
          (p) => p.nodeIndex == filteredNode.index,
        );
        expect(output.kind, GeometryPaintKind.image);
        expect(output.role, GeometryPaintRole.combined);
        expect(output.exactCoverage, true);
        expect(output.alphaFootprint!.alphaAt(GeometryPoint(20.5, 20.5)), 255);
        const offset = (20 * 320 + 20) * 4;
        expect(bytes.sublist(offset, offset + 4), [255, 0, 0, 255]);
        final reference = <int, Map<String, Object?>>{
          for (final node in document.nodes.where((n) => n.localName != null))
            node.index: {
              'fill': node.attribute('fill') ?? 'black',
              'stroke': 'none',
              if (filterOn == 'style')
                'filter': node.index == filteredNode.index ? 'url(#f)' : 'none',
            },
        };
        List<SpikeSampleRecord> classify(Uint8List actual) =>
            classifySvgSamples(
              document: document,
              elements: scene.elements,
              clips: scene.geometry.clips,
              fragments: scene.geometry.fragments,
              paints: scene.geometry.paint,
              referenceComputedPaint: reference,
              samples: [
                {
                  'x': 20,
                  'y': 20,
                  'rgba': [255, 0, 0, 255],
                },
                {
                  'x': 140,
                  'y': 20,
                  'rgba': bytes.sublist(
                    (20 * 320 + 140) * 4,
                    (20 * 320 + 140) * 4 + 4,
                  ),
                },
              ],
              actual: actual,
            );
        final changed = Uint8List.fromList(bytes)..[offset] = 254;
        final gradientOffset = (20 * 320 + 140) * 4;
        changed[gradientOffset] += changed[gradientOffset] == 255 ? -1 : 1;
        final records = classify(changed);
        expect(records.first.maximumChannelDelta, 1);
        expect(records.first.pass, false);
        expect(records.first.classification, SpikeSamplePaintClass.solid);
        expect(
          (compareSpikePixels(changed, bytes, samples: records)['d4']
              as Map)['samples']['pass'],
          false,
        );
        expect(
          (records.first.provenance['native'] as Map)['filterNodeIndex'],
          filteredNode.index,
        );
        expect(records.last.maximumChannelDelta, 1);
        expect(records.last.classification, SpikeSamplePaintClass.gradient);
        expect(records.last.pass, true);
        expect((records.last.provenance['native'] as Map)['role'], 'fill');
        final exact = classify(bytes).first;
        expect(exact.classification, SpikeSamplePaintClass.solid);
        expect(exact.maximumChannelDelta, 0);
        expect(exact.pass, true);
        expect(
          compareSpikePixels(bytes, bytes, samples: [exact])['pass'],
          true,
        );
      } finally {
        scene.dispose();
      }
      expect(budget.used.values.every((value) => value == 0), true);
    });
  }
  test(
    'solid marker coverage remains above fill and gradient stroke',
    () async {
      final document = const SourceParser().parse(
        '<svg xmlns="http://www.w3.org/2000/svg" width="320" height="240">'
        '<defs><linearGradient id="g"><stop stop-color="red"/><stop offset="1" stop-color="blue"/></linearGradient>'
        '<marker id="m" markerUnits="userSpaceOnUse" markerWidth="20" markerHeight="20" refX="10" refY="10">'
        '<rect width="20" height="20" fill="black"/></marker></defs>'
        '<path d="M20 30H100V90H20Z" fill="url(#g)" stroke="url(#g)" stroke-width="8" marker-start="url(#m)"/></svg>',
        mediaType: 'image/svg+xml',
      );
      final budget = SceneResourceBudget();
      final scene = await SvgGraphicsPlan.inspect(
        document: document,
        rootIndex: document.documentElementIndex,
        page: contractPage(),
        size: AuthoredPageSize(320, 240),
      ).prepare(budget: budget);
      try {
        expect(scene.capability.isComplete, true);
        final image = await scene.picture!.toImage(320, 240);
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        ))!.buffer.asUint8List();
        image.dispose();
        final marker = scene.elements.singleWhere(
          (e) => document.node(e.nodeIndex).localName == 'rect',
        );
        final path = scene.elements.singleWhere(
          (e) => document.node(e.nodeIndex).localName == 'path',
        );
        expect(marker.paintOrdinal, greaterThan(path.paintOrdinal));
        final record = classifySvgSamples(
          document: document,
          elements: scene.elements,
          clips: scene.geometry.clips,
          fragments: scene.geometry.fragments,
          paints: scene.geometry.paint,
          referenceComputedPaint: {
            marker.nodeIndex: {'fill': 'black', 'stroke': 'none'},
            path.nodeIndex: {'fill': 'url(#g)', 'stroke': 'url(#g)'},
          },
          samples: [
            {
              'x': 20,
              'y': 30,
              'rgba': [
                1,
                ...bytes.sublist(
                  (30 * 320 + 20) * 4 + 1,
                  (30 * 320 + 20) * 4 + 4,
                ),
              ],
            },
          ],
          actual: bytes,
        ).single;
        expect(bytes.sublist((30 * 320 + 20) * 4, (30 * 320 + 20) * 4 + 4), [
          0,
          0,
          0,
          255,
        ]);
        expect(record.classification, SpikeSamplePaintClass.solid);
        expect(record.pass, false);
        expect(
          (record.provenance['native'] as Map)['nodeIndex'],
          marker.nodeIndex,
        );
      } finally {
        scene.dispose();
      }
      expect(budget.used.values.every((v) => v == 0), true);
    },
  );
  for (final cap in ['butt', 'round', 'square']) {
    test('D9 requires exact solid fill in a $cap dashed-gradient gap', () async {
      final document = const SourceParser().parse(
        '<svg xmlns="http://www.w3.org/2000/svg" width="320" height="240">'
        '<defs><linearGradient id="g"><stop stop-color="red"/>'
        '<stop offset="1" stop-color="blue"/></linearGradient></defs>'
        '<rect id="mixed" x="20" y="20" width="100" height="60" fill="black" '
        'stroke="url(#g)" stroke-width="10" stroke-dasharray="10 30" '
        'stroke-linecap="$cap"/>'
        '<rect id="stroke" x="20" y="120" width="100" height="60" fill="none" '
        'stroke="url(#g)" stroke-width="10" stroke-dasharray="10 30" '
        'stroke-linecap="$cap"/></svg>',
        mediaType: 'image/svg+xml',
      );
      final budget = SceneResourceBudget();
      final scene = await SvgGraphicsPlan.inspect(
        document: document,
        rootIndex: document.documentElementIndex,
        page: contractPage(),
        size: AuthoredPageSize(320, 240),
      ).prepare(budget: budget);
      try {
        expect(scene.capability.isComplete, true);
        final image = await scene.picture!.toImage(320, 240);
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        ))!.buffer.asUint8List();
        image.dispose();
        expect(bytes.sublist((21 * 320 + 95) * 4, (21 * 320 + 95) * 4 + 4), [
          0,
          0,
          0,
          255,
        ]);
        final mixed = scene.elements.singleWhere(
          (e) => document.node(e.nodeIndex).id == 'mixed',
        );
        final fill = scene.geometry.paint
            .singleWhere(
              (p) =>
                  p.nodeIndex == mixed.nodeIndex &&
                  p.role == GeometryPaintRole.fill,
            )
            .alphaFootprint!;
        final stroke = scene.geometry.paint
            .singleWhere(
              (p) =>
                  p.nodeIndex == mixed.nodeIndex &&
                  p.role == GeometryPaintRole.stroke,
            )
            .alphaFootprint!;
        final strokeOnly = [
          for (var y = 10; y < 90; y++)
            for (var x = 10; x < 130; x++)
              if (fill.alphaAt(GeometryPoint(x + .5, y + .5)) == 0 &&
                  stroke.alphaAt(GeometryPoint(x + .5, y + .5))! > 0)
                (x, y),
        ].first;
        final records = classifySvgSamples(
          document: document,
          elements: scene.elements,
          clips: scene.geometry.clips,
          fragments: scene.geometry.fragments,
          paints: scene.geometry.paint,
          referenceComputedPaint: {
            for (final node in document.nodes.where(
              (n) => n.localName == 'rect',
            ))
              node.index: {'fill': node.attribute('fill'), 'stroke': 'url(#g)'},
          },
          samples: [
            for (final (x, y) in [
              (95, 21),
              (115, 120),
              (60, 50),
              strokeOnly,
              (115, 21),
            ])
              {
                'x': x,
                'y': y,
                'rgba': [
                  bytes[(y * 320 + x) * 4] == 255
                      ? 254
                      : bytes[(y * 320 + x) * 4] + 1,
                  ...bytes.sublist(
                    (y * 320 + x) * 4 + 1,
                    (y * 320 + x) * 4 + 4,
                  ),
                ],
              },
          ],
          actual: bytes,
        );
        expect(records.first.maximumChannelDelta, 1);
        expect(records.first.classification, SpikeSamplePaintClass.solid);
        expect(records.first.pass, false);
        expect(records.map((r) => r.classification), [
          SpikeSamplePaintClass.solid,
          SpikeSamplePaintClass.gradient,
          SpikeSamplePaintClass.solid,
          SpikeSamplePaintClass.gradient,
          SpikeSamplePaintClass.gradient,
        ]);
        expect(records.map((r) => r.pass), [false, true, false, true, true]);
        expect(records.map((r) => (r.provenance['native'] as Map)['role']), [
          'fill',
          'stroke',
          'fill',
          'stroke',
          'stroke',
        ]);
      } finally {
        scene.dispose();
      }
      expect(budget.used.values.every((value) => value == 0), true);
    });
  }
  test(
    'replayed boundary sample needs the actual gradient fill role',
    () async {
      final oracle = jsonDecode(
        File('test/fixtures/reader/fixed_layout/oracle.json')
            .readAsStringSync(),
      ) as Map;
      final boundary = (oracle['cases'] as List).cast<Map>().singleWhere(
        (c) => c['id'] == 'svg-graphics-boundary',
      );
      final sample = (boundary['samples'] as List).cast<Map>().singleWhere(
        (s) => s['x'] == 10 && s['y'] == 10,
      );
      final document = const SourceParser().parse(
        '<svg xmlns="http://www.w3.org/2000/svg" width="320" height="240">'
        '<defs><linearGradient id="grad" gradientUnits="userSpaceOnUse" x2="40" spreadMethod="reflect" gradientTransform="translate(5 0) scale(.7)">'
        '<stop stop-color="red"/><stop offset="1" stop-color="blue"/></linearGradient></defs>'
        '<rect x="5" y="5" width="40" height="40" fill="url(#grad)" stroke="black"/></svg>',
        mediaType: 'image/svg+xml',
      );
      final budget = SceneResourceBudget();
      final scene = await SvgGraphicsPlan.inspect(
        document: document,
        rootIndex: document.documentElementIndex,
        page: contractPage(),
        size: AuthoredPageSize(320, 240),
      ).prepare(budget: budget);
      try {
        expect(scene.capability.isComplete, true);
        final image = await scene.picture!.toImage(320, 240);
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        ))!.buffer.asUint8List();
        image.dispose();
        final rect = scene.elements.singleWhere(
          (e) => document.node(e.nodeIndex).localName == 'rect',
        );
        final reference = <int, Map<String, Object?>>{
          rect.nodeIndex: {'fill': 'url("#grad")', 'stroke': 'rgb(0, 0, 0)'},
        };
        SpikeSampleRecord classify(List<GeometryPaint> paints) =>
            classifySvgSamples(
              document: document,
              elements: scene.elements,
              clips: scene.geometry.clips,
              fragments: scene.geometry.fragments,
              paints: paints,
              referenceComputedPaint: reference,
              samples: [sample],
              actual: bytes,
            ).single;
        final correct = classify(scene.geometry.paint.reversed.toList());
        expect(correct.maximumChannelDelta, 1);
        expect(correct.classification, SpikeSamplePaintClass.gradient);
        expect(correct.pass, true);
        expect((correct.provenance['native'] as Map)['role'], 'fill');
        List<GeometryPaint> relabel(bool combined) => [
          for (final p in scene.geometry.paint)
            GeometryPaint(
              nodeIndex: p.nodeIndex,
              paintOrdinal: p.paintOrdinal,
              region: p.region,
              kind: p.kind,
              effectiveOpacity: p.effectiveOpacity,
              exactCoverage: p.exactCoverage,
              alphaFootprint: p.alphaFootprint,
              clipIds: p.clipIds,
              groupIds: p.groupIds,
              role: combined
                  ? GeometryPaintRole.combined
                  : p.role == GeometryPaintRole.fill
                  ? GeometryPaintRole.stroke
                  : GeometryPaintRole.fill,
            ),
        ];
        for (final paints in [relabel(false), relabel(true)]) {
          final wrong = classify(paints);
          expect(wrong.maximumChannelDelta, 1);
          expect(wrong.classification, SpikeSamplePaintClass.solid);
          expect(wrong.pass, false);
        }
        reference[rect.nodeIndex] = {'fill': 'black', 'stroke': 'rgb(0, 0, 0)'};
        expect(classify(scene.geometry.paint).pass, false);
      } finally {
        scene.dispose();
      }
      expect(budget.used.values.every((v) => v == 0), true);
    },
  );
  for (final text in [true, false]) {
    test(
      'D9 keeps solid ${text ? 'SVG text' : 'foreignObject'} over a gradient exact',
      () async {
        final font = File(
          'tool/oracle/fixtures/styles/EPUB/fonts/Roboto-Regular.ttf',
        ).readAsBytesSync();
        final sample = StyleSample.html(
          '<svg xmlns="http://www.w3.org/2000/svg" width="320" height="240">'
          '<defs><linearGradient id="g"><stop stop-color="red"/>'
          '<stop offset="1" stop-color="blue"/></linearGradient></defs>'
          '<rect id="gradient" width="320" height="240" fill="url(#g)"/>'
          '${text ? '<text x="20" y="60" font-size="40" font-family="Fixture" fill="black">O</text>' : '<foreignObject x="20" y="20" width="80" height="80"><div xmlns="http://www.w3.org/1999/xhtml" id="block" style="width:40px;height:40px;background:black"/></foreignObject>'}'
          '</svg>',
          head: '<meta name="viewport" content="width=320,height=240"/>',
          css:
              '@font-face{font-family:Fixture;src:url(font.ttf)}body{margin:0}',
          files: {'font.ttf': font},
          metadata: '<meta property="rendition:layout">pre-paginated</meta>',
        );
        addTearDown(sample.book.archive.close);
        final source = FixedSourceLease(
          page: contractPage(id: sample.book.sections.single.item.href),
          document: sample.document,
          styles: sample.styled,
          rendition: sectionRendition(sample.book, 0),
          resources: ArchiveReaderResourceSource(sample.book.archive),
          retainedSourceBytes: 1024,
          releaseSource: () {},
        );
        addTearDown(source.dispose);
        final fonts = FontRegistry(processBudget: ProcessFontBudget());
        final preparer = FixedSectionPreparer(
          fonts: fonts,
          drainFonts: fonts.drainFonts,
        );
        final plan = preparer.plan(source), budget = SceneResourceBudget();
        expect(plan.capability.isComplete, true, reason: '${plan.capability}');
        final lease = budget.reserveUnit(
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
            sceneLease: lease,
            pictureBytes: plan.pictureBytes,
            decodedImageBytes: plan.decodedImageBytes,
            reconcilePictureBytes: (_) => true,
            releaseReservations: lease.release,
          ),
        );
        final prepared = await operation.result;
        await operation.drained;
        try {
          final svg = prepared.scene.svgScenes.single;
          for (final paint in svg.geometry.paint.where(
            (p) => p.role != GeometryPaintRole.combined,
          )) {
            final merged = prepared.scene.geometry.paint.where(
              (p) =>
                  p.nodeIndex == paint.nodeIndex &&
                  identical(p.alphaFootprint, paint.alphaFootprint),
            );
            expect(merged.map((p) => p.role), contains(paint.role));
          }
          final foreground = svg.geometry.paint.lastWhere(
            (paint) => text
                ? paint.kind == GeometryPaintKind.text
                : paint.nodeIndex == sample.byId('block'),
          );
          final footprint = foreground.alphaFootprint!;
          final covered = <(int, int)>[], holes = <(int, int)>[];
          for (var y = 20; y < 80; y++) {
            for (var x = 20; x < 80; x++) {
              final alpha = footprint.alphaAt(GeometryPoint(x + .5, y + .5));
              if (alpha == 255) covered.add((x, y));
              if (alpha == 0) holes.add((x, y));
            }
          }
          expect(covered, isNotEmpty);
          expect(holes, isNotEmpty);
          final image = await svg.picture!.toImage(320, 240);
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawStraightRgba,
          ))!.buffer.asUint8List();
          image.dispose();
          final samples = [
            for (final (x, y) in [covered.first, holes.first])
              {
                'x': x,
                'y': y,
                'rgba': [
                  for (var channel = 0; channel < 4; channel++)
                    channel == 0
                        ? (bytes[(y * 320 + x) * 4] == 255
                              ? 254
                              : bytes[(y * 320 + x) * 4] + 1)
                        : bytes[(y * 320 + x) * 4 + channel],
                ],
              },
          ];
          final reference = {
            sample.byId('gradient'): <String, Object?>{'fill': 'url(#g)'},
          };
          List<SpikeSampleRecord> classify(List<GeometryPaint>? paints) =>
              classifySvgSamples(
                document: sample.document,
                elements: svg.elements,
                clips: svg.geometry.clips,
                fragments: svg.geometry.fragments,
                paints: paints,
                referenceComputedPaint: reference,
                samples: samples,
                actual: bytes,
              );
          final records = classify(svg.geometry.paint);
          expect(records.first.maximumChannelDelta, 1);
          expect(records.first.classification, SpikeSamplePaintClass.solid);
          expect(records.first.pass, false);
          expect(records.last.classification, SpikeSamplePaintClass.gradient);
          expect(records.last.pass, true);
          expect(classify(null).every((record) => !record.pass), true);
          for (final coverage in [
            null,
            footprint.placed(AffineTransform(0, 0, 0, 0, 0, 0)),
          ]) {
            final unknown = GeometryPaint(
              nodeIndex: foreground.nodeIndex,
              paintOrdinal: foreground.paintOrdinal,
              region: foreground.region,
              kind: foreground.kind,
              effectiveOpacity: foreground.effectiveOpacity,
              exactCoverage: false,
              alphaFootprint: coverage,
              clipIds: foreground.clipIds,
            );
            final uncertain = classify([
              for (final paint in svg.geometry.paint)
                identical(paint, foreground) ? unknown : paint,
            ]);
            expect(uncertain.every((record) => !record.pass), true);
          }
        } finally {
          prepared.dispose();
        }
        expect(budget.used.values.every((value) => value == 0), true);
      },
    );
  }
}
