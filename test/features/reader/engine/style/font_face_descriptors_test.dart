import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/engine/style/computed_style.dart';
import 'package:shiori/features/reader/engine/style/css_stylesheet.dart';
import 'package:shiori/features/reader/engine/style/style_diagnostic.dart';

void main() {
  test(
    'font-face retains ordered resource alternatives and face descriptors',
    () {
      final sink = StyleDiagnosticSink();
      final sheet = CssSheetBuilder(sink: sink)
        ..addStylesheet('''
      @font-face {font-family:Fixture;src:url(regular.ttf);font-weight:normal;font-style:normal}
      @font-face {font-family:Fixture;src:url(bold.woff),url(bold.ttf);font-weight:700;font-style:italic}
      @font-face {font-family:"Other Family";src:url(other.ttf);font-weight:500;font-style:normal}
    ''', 'styles/main.css');
      expect(sink.diagnostics, isEmpty);
      expect(sheet.fontFaces.map((f) => f.family), [
        'Fixture',
        'Fixture',
        'Other Family',
      ]);
      expect(sheet.fontFaces.map((f) => f.weight), [400, 700, 500]);
      expect(sheet.fontFaces.map((f) => f.style), [
        StyleFontStyle.normal,
        StyleFontStyle.italic,
        StyleFontStyle.normal,
      ]);
      expect(sheet.fontFaces[1].urls, ['bold.woff', 'bold.ttf']);
      expect(
        sheet.fontFaces.every((f) => f.basePath == 'styles/main.css'),
        true,
      );
    },
  );
  test('unsupported face descriptor ranges and angles are diagnosed', () {
    for (final declaration in [
      'font-weight:100 900',
      'font-weight:450',
      'font-weight:future',
      'font-style:oblique 20deg',
      'font-style:future',
    ]) {
      final sink = StyleDiagnosticSink();
      CssSheetBuilder(sink: sink).addStylesheet(
        '@font-face{font-family:Fixture;src:url(font.ttf);$declaration}',
        'main.css',
      );
      expect(sink.diagnostics, isNotEmpty, reason: declaration);
      expect(
        sink.diagnostics.every((d) => d.detail.startsWith('@font-face')),
        true,
      );
    }
  });
}
