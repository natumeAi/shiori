import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/layout/reading_unit.dart';
import 'package:shiori/features/reader/data/layout/section_rendition.dart';
import 'package:shiori/features/reader/data/layout/source_page_slot.dart';
import 'package:shiori/features/reader/data/geometry/source_geometry.dart';
import 'package:shiori/features/reader/engine/surface/page_surface_pool.dart';

import '../../data/worker/import_test_support.dart' as input;
import 'publication_fixed_test_support.dart';

// Entirely generated: no private source, resource or metadata is used here.
Uint8List syntheticMixedSvgPublication({
  String width = '100%',
  String height = '100%',
  String svgCss = '',
  String wrapperCss = 'width:100%;height:100%',
}) {
  final entries = input.importEntries(
    sources: [
      for (var i = 0; i < 17; i++) input.sourcePage(body: '<p>Example</p>'),
      for (var i = 0; i < 6; i++)
        input.sourcePage(
          head:
              '<meta name="viewport" content="width=320,height=240"/>'
              '<link rel="stylesheet" href="style.css"/>',
          body:
              '<div><svg xmlns="http://www.w3.org/2000/svg" '
              'xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" '
              'width="$width" height="$height" viewBox="0 0 320 240">'
              '<image width="320" height="240" xlink:href="page.png"/>'
              '</svg></div>',
        ),
    ],
    properties: [
      for (var i = 0; i < 17; i++) '',
      for (var i = 0; i < 6; i++)
        'rendition:layout-pre-paginated rendition:spread-none '
            'rendition:page-spread-center'
            '${i < 4 ? ' access:scroll-both access:orientation-landscape' : ''}',
    ],
  );
  entries['EPUB/package.opf'] = entries['EPUB/package.opf']!
      .replaceAll(RegExp(r'<meta property="rendition:[^"]+">[^<]*</meta>'), '')
      .replaceFirst(' page-progression-direction="ltr"', '');
  entries['EPUB/style.css'] =
      'html,body { margin:0; width:100%; height:100%; }'
      'body>div {margin:0;$wrapperCss} svg {$svgCss}';
  return input.importZip(entries);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'mixed SVG wrappers conserve all imported sources in composition',
    () async {
      final h = await PublicationFixedHarness.open(
        syntheticMixedSvgPublication(),
      );
      final sections = h.composition.navigator.sections;
      expect(sections, hasLength(23));
      expect(
        sections.map((s) => s.page.spineIndex),
        orderedEquals(List.generate(23, (i) => i)),
      );
      expect(sections.map((s) => s.page).toSet(), hasLength(23));
      expect(sections.every((s) => s.rendition.isValid), isTrue);
      expect(h.ready.layoutFacts.packageRendition, isEmpty);
      expect(
        sections.where((s) => s.rendition.isFixed == false),
        hasLength(17),
      );
      for (final section in sections.skip(17)) {
        final dimensions = section.dimensions as ResolvedDimensions;
        expect(dimensions.source, DimensionSource.viewportMeta);
        expect(dimensions.size, AuthoredPageSize(320, 240));
      }
      final slots = h.composition.navigator.units
          .expand((u) => u.slots)
          .whereType<RealSourcePageSlot>()
          .toList();
      expect(slots.map((s) => s.page).toSet(), hasLength(23));
      expect(slots, hasLength(23));
      expect(
        h.composition.navigator.units.where(
          (u) => u.kind == ReadingUnitKind.fixedSingle,
        ),
        hasLength(6),
      );
      expect(sections[17].rendition.rawItemref, contains('access:scroll-both'));
    },
  );

  test(
    'unrecognized property names differ from unknown known-property values',
    () {
      final ignored = resolveSectionRendition(
        package: {},
        itemref: [
          'access:scroll-both',
          'access:orientation-landscape',
          'rendition:future-mode',
        ],
      );
      expect(ignored.issues, isEmpty);
      final unknown = resolveSectionRendition(
        package: {
          'layout': 'future',
          'orientation': 'future',
          'spread': 'future',
        },
      );
      expect(unknown.issues, hasLength(3));
      expect(
        unknown.issues.map((i) => i.kind),
        everyElement(RenditionIssueKind.unsupported),
      );
    },
  );

  test(
    'all six percentage SVG constituents prepare with complete geometry',
    () async {
      final h = await PublicationFixedHarness.open(
        syntheticMixedSvgPublication(),
      );
      expect(
        h.composition.navigator.sections.map((s) => s.page).toSet(),
        hasLength(23),
      );
      var prepared = 0;
      for (final unit in h.composition.navigator.units.where(
        (u) => u.kind == ReadingUnitKind.fixedSingle,
      )) {
        final lease = await h.pool.prepareFixedUnit(
          unit,
          layout: h.fixedLayout(unit.activeSource.sectionIndex),
          loadSource: h.sources.unitSources.loadSource,
          fonts: h.fonts,
        );
        expect(lease, isNotNull);
        final fixed = lease!.surface.fixedScenes.single;
        expect(fixed.plan.source.images, hasLength(1));
        expect(fixed.plan.svgPlans.single.size, AuthoredPageSize(320, 240));
        expect(fixed.scene.svgScenes.single.size, AuthoredPageSize(320, 240));
        expect(fixed.geometry.completeness, isA<CompleteGeometry>());
        final box = fixed.scene.boxes.singleWhere((b) => b.svgPlan != null);
        expect(box.contentBox.width, 320);
        expect(box.contentBox.height, 240);
        prepared++;
        lease.release();
      }
      expect(prepared, 6);
      h.composition.dispose();
      expect(h.pool.pictureBytes, 0);
      expect(h.pool.images.totalBytes, 0);
      expect(h.pool.resourceBudget.used.values.every((v) => v == 0), isTrue);
      expect(h.sources.retainedSourceOwners, 0);
    },
  );

  for (final sample in [
    (
      name: '50%/75%',
      width: '50%',
      height: '75%',
      css: '',
      wrapper: 'width:100%;height:100%',
      w: 160.0,
      h: 180.0,
    ),
    (
      name: 'CSS overrides attributes',
      width: '100%',
      height: '100%',
      css: 'width:50%;height:75%',
      wrapper: 'width:100%;height:100%',
      w: 160.0,
      h: 180.0,
    ),
    // CSS 2.1: percentage height in an indefinite normal-flow containing
    // block computes to auto; definite width and intrinsic ratio size it.
    (
      name: 'indefinite height uses auto and intrinsic ratio',
      width: '50%',
      height: '75%',
      css: '',
      wrapper: 'width:80%;height:auto',
      w: 128.0,
      h: 96.0,
    ),
    (
      name: 'absolute attribute units',
      width: '2in',
      height: '72pt',
      css: '',
      wrapper: 'width:100%;height:100%',
      w: 192.0,
      h: 96.0,
    ),
    (
      name: 'CSS auto overrides attribute height',
      width: '50%',
      height: '75%',
      css: 'height:auto',
      wrapper: 'width:100%;height:100%',
      w: 160.0,
      h: 120.0,
    ),
  ]) {
    test(sample.name, () async {
      final h = await PublicationFixedHarness.open(
        syntheticMixedSvgPublication(
          width: sample.width,
          height: sample.height,
          svgCss: sample.css,
          wrapperCss: sample.wrapper,
        ),
      );
      final unit = h.composition.navigator.units.firstWhere(
        (u) => u.kind == ReadingUnitKind.fixedSingle,
      );
      final lease = await h.pool.prepareFixedUnit(
        unit,
        layout: h.fixedLayout(unit.activeSource.sectionIndex),
        loadSource: h.sources.unitSources.loadSource,
        fonts: h.fonts,
      );
      expect(lease, isNotNull);
      final fixed = lease!.surface.fixedScenes.single;
      final expected = AuthoredPageSize(sample.w, sample.h);
      expect(fixed.plan.svgPlans.single.size, expected);
      expect(fixed.scene.svgScenes.single.size, expected);
      final box = fixed.scene.boxes.singleWhere((b) => b.svgPlan != null);
      expect(box.contentBox.width, sample.w);
      expect(box.contentBox.height, sample.h);
      expect(fixed.geometry.completeness, isA<CompleteGeometry>());
      lease.release();
    });
  }
}
