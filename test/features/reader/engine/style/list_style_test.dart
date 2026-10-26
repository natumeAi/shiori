import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/engine/style/computed_style.dart';

import 'style_test_support.dart';

void main() {
  group('list-style-type', () {
    test('user-agent defaults: disc, decimal, circle then square', () {
      final sample = StyleSample.html(
        '<ul id="a"><li id="la">x<ul id="b"><li id="lb">y<ul id="c">'
        '<li id="lc">z</li></ul></li></ul></li></ul>'
        '<ol id="d"><li id="ld">q</li></ol>',
      );
      expect(sample['la'].listStyleType, StyleListStyleType.disc);
      expect(sample['lb'].listStyleType, StyleListStyleType.circle);
      expect(sample['lc'].listStyleType, StyleListStyleType.square);
      expect(sample['ld'].listStyleType, StyleListStyleType.decimal);
    });

    test(
      'the property and the shorthand type part are parsed and inherited',
      () {
        final sample = StyleSample.html(
          '<ul id="a"><li id="la">x</li></ul>'
          '<ol id="b"><li id="lb">y</li><li id="own">z</li></ol>'
          '<ul id="c"><li id="lc">w</li></ul>',
          css:
              '#a { list-style-type: none } '
              '#b { list-style: upper-roman inside } '
              '#own { list-style-type: lower-latin } '
              '#c { list-style: url(x.png) outside }',
        );
        expect(sample['la'].listStyleType, StyleListStyleType.none);
        expect(sample['lb'].listStyleType, StyleListStyleType.upperRoman);
        expect(sample['own'].listStyleType, StyleListStyleType.lowerAlpha);
        // A shorthand without a type leaves the type alone.
        expect(sample['lc'].listStyleType, StyleListStyleType.disc);
      },
    );
  });
}
