import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/worker/publication_layout_facts.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_svg_viewport.dart';

void main() {
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
