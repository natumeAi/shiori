import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/resources/archive_reader_resource_source.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_preparation_plan.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_scene.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_source_lease.dart';
import 'package:shiori/features/reader/engine/layout/paragraph_factory.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/support/layout_flags.dart';

import '../../contract_test_values.dart';
import '../style/style_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final sample in [
    (
      name: 'definite html/body/div chain',
      attrs: 'width="100%" height="100%"',
      wrapper: 'width:100%;height:100%',
      css: '',
      w: 320.0,
      h: 240.0,
    ),
    (
      name: 'percentage attributes',
      attrs: 'width="50%" height="75%"',
      wrapper: 'width:100%;height:100%',
      css: '',
      w: 160.0,
      h: 180.0,
    ),
    (
      name: 'CSS percentage overrides',
      attrs: 'width="100%" height="100%"',
      wrapper: 'width:100%;height:100%',
      css: 'width:50%;height:75%',
      w: 160.0,
      h: 180.0,
    ),
    (
      name: 'CSS absolute overrides',
      attrs: 'width="100%" height="100%"',
      wrapper: 'width:100%;height:100%',
      css: 'width:2in;height:72pt',
      w: 192.0,
      h: 96.0,
    ),
    // CSS 2.1 10.5/10.6.2: percentage height in an indefinite normal-flow
    // containing block computes to auto, then uses definite width / ratio.
    (
      name: 'indefinite height',
      attrs: 'width="50%" height="75%"',
      wrapper: 'width:80%;height:auto',
      css: '',
      w: 128.0,
      h: 96.0,
    ),
    (
      name: 'CSS auto overrides attributes',
      attrs: 'width="50%" height="75%"',
      wrapper: 'width:100%;height:100%',
      css: 'height:auto',
      w: 160.0,
      h: 120.0,
    ),
    (
      name: 'content box excludes padding and border',
      attrs: 'width="50%" height="75%"',
      wrapper:
          'box-sizing:border-box;width:200px;height:160px;'
          'padding:10px;border:2px solid red',
      css: '',
      w: 88.0,
      h: 102.0,
    ),
  ]) {
    test(sample.name, () async {
      final input = StyleSample.html(
        '<div><svg xmlns="http://www.w3.org/2000/svg" ${sample.attrs} '
        'viewBox="20 30 320 240" preserveAspectRatio="none">'
        '<rect x="20" y="30" width="320" height="240" fill="red"/>'
        '</svg></div>',
        head:
            '<meta name="viewport" content="width=320,height=240"/>'
            '<link rel="stylesheet" href="/OEBPS/sizing.css"/>',
        css:
            'html,body{margin:0;width:100%;height:100%}'
            'body>div{${sample.wrapper}}',
        files: {'sizing.css': 'svg{${sample.css}}'},
        metadata: '<meta property="rendition:layout">pre-paginated</meta>',
      );
      addTearDown(input.book.archive.close);
      final source = FixedSourceLease(
        page: contractPage(),
        document: input.document,
        styles: input.styled,
        rendition: sectionRendition(input.book, 0),
        resources: ArchiveReaderResourceSource(input.book.archive),
        retainedSourceBytes: 1024,
        releaseSource: () {},
      );
      final plan = FixedPreparationPlan.inspect(source);
      expect(
        plan.capability.isComplete,
        isTrue,
        reason: plan.capability.reason,
      );
      expect(
        (plan.dimensions as ResolvedDimensions).size,
        AuthoredPageSize(320, 240),
      );
      final svg = plan.svgPlans.single;
      expect(svg.size, AuthoredPageSize(sample.w, sample.h));
      final budget = SceneResourceBudget();
      final scene = await FixedSceneBuilder(
        document: source.document,
        styles: source.styles,
        page: source.page,
        size: (plan.dimensions as ResolvedDimensions).size,
        fonts: ParagraphFonts(),
        budget: budget,
        svgPlans: {svg.rootIndex: svg},
      ).build();
      try {
        expect(
          scene.capability.isComplete,
          isTrue,
          reason: scene.capability.reason,
        );
        final box = scene.boxes.singleWhere((b) => b.svgPlan != null);
        expect(box.contentBox.width, sample.w);
        expect(box.contentBox.height, sample.h);
        final element = scene.svgScenes.single.elements.last;
        expect(element.transform.a, closeTo(sample.w / 320, 1e-8));
        expect(element.transform.d, closeTo(sample.h / 240, 1e-8));
        expect(
          element.transform.e,
          closeTo(box.contentBox.left - 20 * sample.w / 320, 1e-8),
        );
        expect(
          element.transform.f,
          closeTo(box.contentBox.top - 30 * sample.h / 240, 1e-8),
        );
      } finally {
        scene.dispose();
        source.dispose();
      }
      expect(budget.used.values.every((v) => v == 0), isTrue);
    });
  }
}
