import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/worker/publication_layout_facts.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_svg_viewport.dart';

import '../style/style_test_support.dart';

void main() {
  for (final vector in <(String, double, double)>[
    ('width:100%;height:auto;max-width:100px', 100, 75),
    ('width:auto;height:100%;max-height:60px', 80, 60),
    ('width:40px;height:auto;min-width:80px', 80, 60),
    ('width:auto;height:30px;min-height:60px', 80, 60),
    ('width:100px;height:100px;max-width:80px', 80, 100),
    ('width:100px;height:auto;min-height:100px', 100, 100),
    ('width:auto;height:auto;max-width:100px', 100, 75),
    ('width:auto;height:auto;max-height:60px', 80, 60),
    ('width:auto;height:auto;min-width:400px', 400, 300),
    ('width:auto;height:auto;min-height:300px', 400, 300),
    ('width:auto;height:auto;max-width:100px;max-height:60px', 80, 60),
    ('width:auto;height:auto;min-width:400px;min-height:400px', 1600 / 3, 400),
    ('width:auto;height:auto;min-width:400px;max-height:60px', 400, 60),
    ('width:auto;height:auto;max-width:100px;min-height:300px', 100, 300),
    ('width:auto;height:auto;min-width:400px;max-height:240px', 400, 240),
    ('width:auto;height:auto;max-width:100px;min-height:100px', 100, 100),
    ('width:auto;height:auto;max-width:100px;max-height:100px', 100, 75),
    ('width:auto;height:auto;min-width:400px;min-height:200px', 400, 300),
    ('width:auto;height:auto;min-width:400px;max-width:100px', 400, 300),
  ]) {
    test('replaced constraints ${vector.$1}', () {
      final sample = StyleSample.html('<svg id="s"/>', css: '#s{${vector.$1}}');
      addTearDown(sample.book.archive.close);
      final viewport = FixedSvgViewport.resolveInline(
        SvgSourceDimensions(
          nodeIndex: 1,
          width: null,
          height: null,
          viewBox: '0 0 4 3',
        ),
        style: sample['s'],
        containingWidth: 320,
        containingHeight: 240,
        cssWidth: true,
        cssHeight: true,
      );
      final size = (viewport.dimensions as ResolvedDimensions).size;
      expect(size.width, closeTo(vector.$2, 1e-9));
      expect(size.height, closeTo(vector.$3, 1e-9));
    });
  }
  FixedSvgViewport resolve({
    String width = '200',
    String height = '200',
    String? box = '20 30 100 50',
    String? aspect,
  }) => FixedSvgViewport.resolve(
    SvgSourceDimensions(
      nodeIndex: 1,
      width: width,
      height: height,
      viewBox: box,
      preserveAspectRatio: aspect,
    ),
  );
  test('nonzero origin, default meet and all alignment edges are in scene transform', () {
    final center = resolve(),
        minimum = resolve(aspect: 'xMinYMin meet'),
        maximum = resolve(aspect: 'xMaxYMax meet');
    expect(center.dimensions, isA<ResolvedDimensions>());
    expect(center.transform!.a, 2);
    expect(center.transform!.d, 2);
    expect(center.transform!.e, -40);
    expect(center.transform!.f, -10);
    expect(minimum.transform!.f, -60);
    expect(maximum.transform!.f, 40);
  });
  test('slice uses larger scale and clips in the unchanged viewport', () {
    final viewport = resolve(aspect: 'xMidYMid slice');
    expect(viewport.transform!.a, 4);
    expect(viewport.transform!.d, 4);
    expect(viewport.transform!.e, -180);
    expect(viewport.transform!.f, -120);
    final size = (viewport.dimensions as ResolvedDimensions).size;
    expect(size.width, 200);
    expect(size.height, 200);
  });
  test('none scales axes independently without discarding viewBox origin', () {
    final viewport = resolve(aspect: 'none');
    expect(viewport.transform!.a, 2);
    expect(viewport.transform!.d, 4);
    expect(viewport.transform!.e, -40);
    expect(viewport.transform!.f, -120);
  });
  test('invalid size/aspect is typed and never supplies a transform', () {
    for (final viewport in [
      resolve(width: '0'),
      resolve(box: '0 0 1 0'),
      resolve(aspect: 'xMidYMid future'),
      resolve(aspect: ''),
    ]) {
      expect(viewport.dimensions, isA<MalformedDimensions>());
      expect(viewport.transform, null);
    }
    final relative = resolve(width: '50%');
    expect(relative.dimensions, isA<UnsupportedDimensions>());
    expect(relative.transform, null);
  });
}
