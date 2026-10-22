import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/engine/style/computed_style.dart';
import 'package:shiori/features/reader/engine/style/style_diagnostic.dart';

import 'style_test_support.dart';

const _body = '''
<div id="d" class="a b" lang="zh-CN" data-k="v1 v2" data-p="pre-fix">
  <p id="p1"><span id="s1">x</span><em id="e1">y</em></p>
  <p id="p2"></p>
  <p id="p3" class="c"><span id="s2">z</span></p>
</div>
<section id="sec"><p id="only">solo</p></section>
<a id="link" href="#d">l</a><a id="nolink">n</a>
''';

/// The ids (among the probe elements) matched by [selector].
Set<String> _matched(String selector) {
  final sample = StyleSample.html(_body, css: '$selector { margin-left: 7px }');
  return {
    for (final id in const [
      'd',
      'p1',
      'p2',
      'p3',
      's1',
      's2',
      'e1',
      'sec',
      'only',
      'link',
      'nolink',
    ])
      if (sample[id].margin.left == const StyleLength.px(7)) id,
  };
}

void main() {
  group('selector forms', () {
    test('type', () => expect(_matched('em'), {'e1'}));
    test('universal does not require a name', () {
      expect(_matched('#d *'), {'p1', 'p2', 'p3', 's1', 's2', 'e1'});
    });
    test('class', () {
      expect(_matched('.a'), {'d'});
      expect(_matched('.b.a'), {'d'});
      expect(_matched('p.c'), {'p3'});
    });
    test('id', () => expect(_matched('#p2'), {'p2'}));
    test('descendant', () {
      expect(_matched('div span'), {'s1', 's2'});
      expect(_matched('div em'), {'e1'});
      expect(_matched('section span'), isEmpty);
    });
    test('child', () {
      expect(_matched('div > span'), isEmpty);
      expect(_matched('p > span'), {'s1', 's2'});
      expect(_matched('div > p'), {'p1', 'p2', 'p3'});
    });
    test('comma list', () {
      expect(_matched('em, #sec'), {'e1', 'sec'});
      expect(_matched('.a, .c, #only'), {'d', 'p3', 'only'});
    });
    test(':not()', () {
      expect(_matched('#d > p:not(.c)'), {'p1', 'p2'});
      expect(_matched('div p:not(#p2)'), {'p1', 'p3'});
      expect(_matched('#d span:not(:first-child)'), isEmpty);
      expect(_matched('#d > *:not(p)'), isEmpty);
    });
    test(':first-child / :last-child', () {
      expect(_matched('#d > p:first-child'), {'p1'});
      expect(_matched('#d > p:last-child'), {'p3'});
      expect(_matched('p span:first-child'), {'s1', 's2'});
      expect(_matched('p *:last-child'), {'e1', 's2'});
    });
    test('attribute presence and equality', () {
      expect(_matched('[lang]'), {'d'});
      expect(_matched('[lang=zh-CN]'), {'d'});
      expect(_matched('[lang="zh-CN"]'), {'d'});
      expect(_matched("[lang='zh']"), isEmpty);
      expect(_matched('a[href]'), {'link'});
      expect(_matched('div[data-k=v1]'), isEmpty);
    });
    test('further attribute operators', () {
      expect(_matched('[data-k~=v2]'), {'d'});
      expect(_matched('[lang|=zh]'), {'d'});
      expect(_matched('[data-p^=pre]'), {'d'});
      expect(_matched(r'[data-p$=fix]'), {'d'});
      expect(_matched('[data-p*=e-f]'), {'d'});
    });
    test('sibling combinators', () {
      expect(_matched('p + p'), {'p2', 'p3'});
      expect(_matched('#p1 ~ p'), {'p2', 'p3'});
      expect(_matched('#p1 + #p3'), isEmpty);
    });
    test('other structural pseudo-classes', () {
      expect(_matched('#sec > p:only-child'), {'only'});
      expect(_matched('#d > p:first-of-type'), {'p1'});
      expect(_matched('#d > p:last-of-type'), {'p3'});
      expect(_matched('p:empty'), {'p2'});
      expect(_matched('a:link'), {'link'});
    });
    test('specificity counts :not() and attributes', () {
      final sample = StyleSample.html(
        '<p id="x" class="k">t</p>',
        css:
            'p:not(.zz) { margin-left: 1px } '
            '.k { margin-left: 2px } '
            'p[class] { margin-left: 3px }',
      );
      // p:not(.zz) (0,1,1) vs .k (0,1,0) vs p[class] (0,1,1): last wins.
      expect(sample['x'].margin.left, const StyleLength.px(3));
    });
  });

  group('unsupported selectors', () {
    test('are dropped and reported, never matching', () {
      final sample = StyleSample.html(
        '<p id="x">t</p><p id="y">t</p>',
        css:
            'p:nth-child(2) { margin-left: 5px } '
            'p::before { margin-left: 6px } '
            'p:first-line { margin-left: 8px } '
            'p:lang(zh) { margin-left: 9px }',
      );
      expect(sample['x'].margin.left, StyleLength.zero);
      expect(sample['y'].margin.left, StyleLength.zero);
      final selectors = sample.styled.diagnostics.where(
        (d) => d.kind == StyleDiagnosticKind.unsupportedSelector,
      );
      expect(selectors.map((d) => d.detail), isNotEmpty);
      expect(
        sample.styled.count(StyleDiagnosticKind.unsupportedSelector),
        greaterThanOrEqualTo(3),
      );
    });

    test('a dropped alternative does not drop the rest of the list', () {
      final sample = StyleSample.html(
        '<p id="x">t</p><span id="y">t</span>',
        css: 'p::before, span { margin-left: 5px }',
      );
      expect(sample['y'].margin.left, const StyleLength.px(5));
      expect(sample['x'].margin.left, StyleLength.zero);
    });

    test('dynamic pseudo-classes are valid and never match', () {
      final sample = StyleSample.html(
        '<a id="x" href="#x">t</a>',
        css: 'a:hover { margin-left: 5px } a:visited { margin-left: 6px }',
      );
      expect(sample['x'].margin.left, StyleLength.zero);
      expect(sample.styled.count(StyleDiagnosticKind.unsupportedSelector), 0);
    });
  });
}
