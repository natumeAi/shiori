/// The two built-in stylesheets of the resolver: a minimal HTML user-agent
/// sheet, and the reference reader overrides generated from
/// [ReaderSettings]. Pure Dart.
library;

import 'package:shiori/features/reader/engine/style/reader_settings.dart';

/// Minimal HTML user-agent stylesheet (WebKit defaults for the style matrix).
/// Table parts are `block` (table layout is not supported); `rt` keeps its
/// 50% size and `rp` is hidden.
const userAgentCss = '''
html, body, address, article, aside, blockquote, center, dd, details, dialog,
dir, div, dl, dt, fieldset, figcaption, figure, footer, form, h1, h2, h3, h4,
h5, h6, header, hgroup, hr, legend, main, menu, nav, ol, p, pre, section,
summary, ul, table, caption, thead, tbody, tfoot, tr, td, th, colgroup, col
  { display: block }
head, link, meta, script, style, title, base, template, noscript, area,
datalist, param, source, track, rp, [hidden]
  { display: none }
li { display: list-item }
ul { list-style-type: disc }
ol { list-style-type: decimal }
ul ul, ol ul { list-style-type: circle }
ul ul ul, ul ol ul, ol ul ul, ol ol ul { list-style-type: square }
html { color: #000000 }
body { margin: 8px }
p, dl, pre, ul, ol, menu, dir { margin-top: 1em; margin-bottom: 1em }
blockquote, figure { margin: 1em 40px }
ul, ol, menu, dir { padding-left: 40px }
ul ul, ul ol, ol ul, ol ol { margin-top: 0; margin-bottom: 0 }
dd { margin-left: 40px }
hr { margin: 0.5em 0; height: 1px; background-color: #808080 }
h1 { font-size: 2em; margin: 0.67em 0 }
h2 { font-size: 1.5em; margin: 0.83em 0 }
h3 { font-size: 1.17em; margin: 1em 0 }
h4 { margin: 1.33em 0 }
h5 { font-size: 0.83em; margin: 1.67em 0 }
h6 { font-size: 0.67em; margin: 2.33em 0 }
h1, h2, h3, h4, h5, h6, b, strong, th { font-weight: bold }
th { text-align: center }
i, em, cite, var, dfn, address { font-style: italic }
u, ins { text-decoration: underline }
s, strike, del { text-decoration: line-through }
a[href] { color: #0000ee; text-decoration: underline }
small { font-size: smaller }
big { font-size: larger }
sub { vertical-align: sub; font-size: smaller }
sup { vertical-align: super; font-size: smaller }
code, kbd, samp, tt, pre { font-family: monospace }
pre { white-space: pre }
mark { background-color: #ffff00; color: #000000 }
rt { font-size: 50% }
center { text-align: center }
[align=center] { text-align: center }
[align=right] { text-align: right }
[align=left] { text-align: left }
[align=justify] { text-align: justify }
[dir=rtl] { direction: rtl }
[dir=ltr] { direction: ltr }
''';

String _hex(int argb) =>
    '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

String _familyList(ReaderFontOption option) => option.cssFamilies
    .map((name) => name.contains(' ') ? '"$name"' : name)
    .join(', ');

/// The CSS the reference injects through `renderer.setStyles`
/// (`getFoliateStyles`, `useReaderSettings.ts:313`): layout CSS unless the
/// book is [fixedLayout], then theme CSS. `::selection` is omitted. Every
/// declaration is `!important`, like the reference, and the sheet is applied
/// after all author styles.
String readerOverrideCss(ReaderSettings settings, {required bool fixedLayout}) {
  final clean = settings.sanitized();
  final family = _familyList(clean.fontOption);
  final theme = clean.theme;
  final spacing = '${_number(clean.letterSpacing)}em';
  final line = _number(clean.lineHeight);
  final layout = fixedLayout
      ? ''
      : '''
html { margin: 0 !important; padding: 0 !important; font-family: $family !important }
body { box-sizing: border-box !important; font-family: $family !important;
  font-size: ${_number(clean.fontSize)}px !important;
  padding-left: 0 !important; padding-right: 0 !important;
  padding-top: 0 !important; padding-bottom: 0 !important;
  line-height: $line !important; letter-spacing: $spacing !important;
  overflow-wrap: anywhere !important }
p, div, section, article, blockquote, li {
  line-height: $line !important; letter-spacing: $spacing !important;
  overflow-wrap: anywhere !important }
img, svg { border-radius: 0 !important; object-fit: contain !important }
''';
  final themeCss =
      '''
html, body { background: ${_hex(theme.background)} !important; color: ${_hex(theme.text)} !important }
a { color: inherit !important }
p, div, section, article, blockquote, li, span { color: ${_hex(theme.text)} !important }
''';
  return layout + themeCss;
}

String _number(double value) {
  final text = value.toString();
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}
