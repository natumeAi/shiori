import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/layout/authored_dimension_resolver.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/layout/section_source_facts.dart';
import 'package:shiori/features/reader/data/layout/verified_raster_wrapper.dart';
import 'package:shiori/features/reader/data/source/source_parser.dart';
import 'package:shiori/features/reader/data/worker/publication_layout_facts.dart';

import '../worker/import_test_support.dart';
import 'fixed_layout_test_support.dart';

SectionSourceFacts source({
  List<String> viewports = const [],
  List<SvgSourceDimensions> svg = const [],
  int? root,
}) => SectionSourceFacts(
  viewports: viewports,
  sourceViewports: const [],
  svgDimensions: svg,
  rootSvgNodeIndex: root,
);
SvgSourceDimensions svg({
  String? w,
  String? h,
  String? box = '20 30 320 240',
}) => SvgSourceDimensions(nodeIndex: 0, width: w, height: h, viewBox: box);

void main() {
  final oracle = {for (final c in readCases('oracle')) c['id']: c};
  for (final fixture in readCases(
    'corpus',
  ).where((c) => c['row'] == 'dimensions')) {
    test('${fixture['id']} dimensions agree with measured outcome', () {
      final input = FixedCorpusInput(fixture);
      final result = input.sections.single.dimensions!;
      final measured = jsonObject(oracle[fixture['id']]!['dimensions']);
      final facts = input.sourceFacts;
      expect(facts.viewports.single, measured['viewport']);
      expect(facts.svgDimensions.single.width, measured['rootWidth']);
      expect(facts.svgDimensions.single.height, measured['rootHeight']);
      expect(
        facts.svgDimensions.single.viewBox!.split(' ').map(double.parse),
        measured['viewBox'],
      );
      switch (fixture['variant']) {
        case 'positive':
        case 'nested':
          expect(result, isA<ResolvedDimensions>());
          final resolved = result as ResolvedDimensions;
          expect(resolved.source, DimensionSource.viewportMeta);
          final cssSize = (measured['computedSize'] as List)
              .map((v) => double.parse((v as String).replaceAll('px', '')))
              .toList();
          expect(resolved.size.width, closeTo(cssSize[0], .5));
          expect(resolved.size.height, closeTo(cssSize[1], .5));
          final svgResult = resolveSvgDimensions(
            facts.svgDimensions.single,
          ) as ResolvedDimensions;
          expect(svgResult.size, resolved.size);
        case 'boundary':
          expect(result, isA<MalformedDimensions>());
        case 'unsupported':
          expect(result, isA<UnsupportedDimensions>());
      }
      expect(result.reason, isNotEmpty);
    });
  }
  test('precedence: source viewport, package viewport, verified raster', () {
    final document = const SourceParser().parse(
      sourcePage(body: '<img src="page.png"/>'),
    );
    final wrapper = VerifiedRasterWrapper.verify(
      document: document,
      resource: 'page.png',
      mediaType: 'image/png',
      intrinsicSize: AuthoredPageSize(640, 480),
    );
    expect(wrapper, isNotNull);
    final raster = resolveAuthoredDimensions(
      source: source(),
      rasterWrapper: wrapper,
    ) as ResolvedDimensions;
    expect(raster.size, AuthoredPageSize(640, 480));
    expect(raster.source, DimensionSource.rasterIntrinsic);
    final package = resolveAuthoredDimensions(
      source: source(),
      rasterWrapper: wrapper,
      packageRendition: {'viewport': 'width=800,height=600'},
    ) as ResolvedDimensions;
    expect(package.size, AuthoredPageSize(800, 600));
    final local = resolveAuthoredDimensions(
      source: source(viewports: ['width=320,height=240']),
      packageRendition: {'viewport': 'width=800,height=600'},
      rasterWrapper: wrapper,
    ) as ResolvedDimensions;
    expect(local.size, AuthoredPageSize(320, 240));
    expect(
      resolveAuthoredDimensions(
        source: source(viewports: ['width=0,height=NaN']),
        rasterWrapper: wrapper,
      ),
      isA<MalformedDimensions>(),
    );
    expect(
      resolveAuthoredDimensions(source: source()),
      isA<UnsupportedDimensions>(),
    );
  });
  test(
    'raster wrapper rejects arbitrary images, non-raster and wrong resource',
    () {
      for (final body in [
        '<p>Text</p><img src="page.png"/>',
        '<img src="other.png"/>',
        '<img src="page.png"/><img src="page.png"/>',
      ]) {
        expect(
          VerifiedRasterWrapper.verify(
            document: const SourceParser().parse(sourcePage(body: body)),
            resource: 'page.png',
            mediaType: 'image/png',
            intrinsicSize: AuthoredPageSize(10, 20),
          ),
          isNull,
        );
      }
      expect(
        VerifiedRasterWrapper.verify(
          document: const SourceParser().parse(
            sourcePage(body: '<img src="a.svg"/>'),
          ),
          resource: 'a.svg',
          mediaType: 'image/svg+xml',
          intrinsicSize: AuthoredPageSize(10, 20),
        ),
        isNull,
      );
    },
  );
  test('SVG roots: absolute viewport before viewBox, origin never adds size', () {
    final result = resolveAuthoredDimensions(
      source: source(
        root: 0,
        svg: [svg(w: '1in', h: '72pt')],
      ),
      packageRendition: {'viewport': 'width=800,height=600'},
    ) as ResolvedDimensions;
    expect(result.size, AuthoredPageSize(96, 96));
    expect(result.source, DimensionSource.svgSize);
    final box = resolveSvgDimensions(svg()) as ResolvedDimensions;
    expect(box.size, AuthoredPageSize(320, 240));
    expect(box.source, DimensionSource.svgViewBox);
    // Different viewBox extents are a scale, not contradictory viewport sizes.
    expect(
      resolveSvgDimensions(svg(w: '640', h: '480')),
      isA<ResolvedDimensions>(),
    );
    for (final unit in ['px', 'in', 'cm', 'mm', 'q', 'pt', 'pc']) {
      expect(
        resolveSvgDimensions(svg(w: '2$unit', h: '3$unit')),
        isA<ResolvedDimensions>(),
      );
    }
    final document = const SourceParser().parse(
      '<svg xmlns="http://www.w3.org/2000/svg" '
      'viewBox="20 30 320 240" preserveAspectRatio="xMinYMax slice"/>',
      mediaType: 'image/svg+xml',
    );
    final facts = extractSectionSourceFacts(document);
    expect(facts.rootSvgNodeIndex, document.documentElementIndex);
    expect(facts.svgDimensions.single.preserveAspectRatio, 'xMinYMax slice');
  });
  test(
    'malformed, relative, duplicate and conflicting declarations fail closed',
    () {
      for (final raw in [
        'width=0,height=240',
        'width=Infinity,height=240',
        'width=320,height=NaN',
        'width=-1,height=240',
        'width=320',
        'width=320,width=640,height=240',
        'notwidth=320,height=240',
        'width=320,height=240,width=',
        'width=320,height=240,width',
      ]) {
        expect(
          resolveAuthoredDimensions(source: source(viewports: [raw])),
          isA<MalformedDimensions>(),
          reason: raw,
        );
      }
      expect(
        resolveAuthoredDimensions(
          source: source(
            viewports: ['width=320,height=240', 'width=640,height=480'],
          ),
        ),
        isA<MalformedDimensions>(),
      );
      expect(
        resolveAuthoredDimensions(
          source: source(viewports: ['width=device-width,height=240']),
        ),
        isA<UnsupportedDimensions>(),
      );
      for (final item in [
        svg(w: '0', h: '2'),
        svg(w: '1e999', h: '2'),
        svg(w: '2'),
        svg(box: '0 0 0 240'),
        svg(box: 'NaN 0 320 240'),
        svg(box: '0 0 320'),
      ]) {
        expect(resolveSvgDimensions(item), isA<MalformedDimensions>());
      }
      for (final unit in ['%', 'em', 'vw', 'future']) {
        expect(
          resolveSvgDimensions(svg(w: '50$unit', h: '75$unit')),
          isA<UnsupportedDimensions>(),
        );
      }
    },
  );
}
