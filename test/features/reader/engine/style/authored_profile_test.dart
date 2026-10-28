import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/engine/style/computed_style.dart';
import 'package:shiori/features/reader/engine/style/css_style_resolver.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';

import 'style_test_support.dart';

void main() {
  test('authored viewport evaluates imported and attribute media queries', () {
    final sample = StyleSample.html(
      '<div id="x">Ab</div>',
      css: "@import url('imported.css'); @media (max-width:320px){#x{padding-left:3px!important}}",
      head: '<link rel="stylesheet" href="linked.css" media="screen and (min-width:300px) and (orientation:landscape)"/>',
      files: {
        'linked.css': '#x{margin-left:12px;color:red!important}',
        'imported.css': '@media all{#x{font-size:20px}}',
      },
      metadata: '<meta property="rendition:layout">pre-paginated</meta>',
    );
    final styled = const CssStyleResolver().resolve(
      sample.book,
      0,
      sample.document,
      const ReaderSettings(fontSize: 40, themeId: 'dark'),
      authoredViewport: AuthoredPageSize(320, 240),
    );
    final style = styled.styleOf(sample.byId('x'))!;
    expect(style.margin.left, const StyleLength.px(12));
    expect(style.padding.left, const StyleLength.px(3));
    expect(style.fontSize, 20);
    expect(style.color, 0xFFFF0000);
    expect(styled.diagnostics, isEmpty);
    final portrait = const CssStyleResolver().resolve(
      sample.book,
      0,
      sample.document,
      const ReaderSettings(),
      authoredViewport: AuthoredPageSize(240, 320),
    );
    expect(portrait.styleOf(sample.byId('x'))!.margin.left, StyleLength.zero);
  });
  test('fixed profile preserves authored body margins and inherited paint', () {
    final sample = StyleSample.html(
      '<div id="x"><span id="y">Ab</span></div>',
      css: 'body{margin:7px;padding:9px;background:yellow;color:blue;font:20px Fixture}#x{position:relative;visibility:hidden;opacity:.7;transform:translate(3px,4px) rotate(10deg);transform-origin:25% 10px}#y{visibility:visible;opacity:inherit;min-width:2em;border:4px solid red;border-radius:12px}',
      metadata: '<meta property="rendition:layout">pre-paginated</meta>',
    );
    expect(sample.styled.rootStyle.margin.left, const StyleLength.px(7));
    expect(sample.styled.rootStyle.padding.left, const StyleLength.px(9));
    expect(sample['x'].color, 0xFF0000FF);
    expect(sample['x'].authored.position, AuthoredPosition.relative);
    expect(sample['x'].authored.transforms, hasLength(2));
    expect(sample['y'].authored.visibility, AuthoredVisibility.visible);
    expect(sample['y'].authored.opacity, .7);
    expect(sample['y'].authored.minimum('width'), const StyleLength.px(40));
    expect(sample['y'].authored.borderColor('top', 0), 0xFFFF0000);
    expect(sample['y'].authored.radius('top-left'), const StyleLength.px(12));
  });
}
