import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/source/source_parser.dart';
import 'package:shiori/features/reader/engine/fixed/svg/svg_graphics.dart';
import 'package:shiori/features/reader/engine/fixed/svg/svg_presentation.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';

import '../../../contract_test_values.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final property in ['filter', 'clip-path', 'mask']) {
    for (final reset in ['sheet', 'inline', 'important']) {
      test('$property winning $reset none disables earlier effects', () async {
        final document = const SourceParser().parse(
          '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">'
          '<rect id="r" width="40" height="30" $property="url(#missing)" '
          '${reset == 'inline'
              ? 'style="$property:none"'
              : reset == 'important'
              ? 'style="$property:url(#inlineMissing)"'
              : ''}/></svg>',
          mediaType: 'image/svg+xml',
        );
        final presentation = SvgPresentation.resolve(
          document,
          [
            if (reset == 'important') '#r{$property:none !important}',
            'rect{$property:url(#alsoMissing)}',
            if (reset == 'sheet') '#r{$property:none}',
          ],
          viewportWidth: 100,
          viewportHeight: 100,
        );
        expect(presentation.problems, isEmpty);
        expect(
          presentation.values[document.getElementById('r')!.index]?[property],
          'none',
        );
        final plan = SvgGraphicsPlan.inspect(
          document: document,
          rootIndex: document.documentElementIndex,
          page: contractPage(),
          size: AuthoredPageSize(100, 100),
          resolvedPresentation: presentation.values,
          presentationProblems: presentation.problems,
        );
        final scene = await plan.prepare(budget: SceneResourceBudget());
        try {
          expect(scene.capability.isComplete, true);
          expect(
            scene.elements
                .singleWhere(
                  (element) =>
                      element.nodeIndex == document.getElementById('r')!.index,
                )
                .bounds
                .width,
            40,
          );
        } finally {
          scene.dispose();
        }
      });
    }
  }
  for (final property in ['filter', 'clip-path', 'mask']) {
    test('$property lower priority none leaves winning effect active', () {
      final document = const SourceParser().parse(
        '<svg xmlns="http://www.w3.org/2000/svg"><rect id="r"/></svg>',
        mediaType: 'image/svg+xml',
      );
      final presentation = SvgPresentation.resolve(
        document,
        ['#r{$property:url(#effect)}', 'rect{$property:none}'],
        viewportWidth: 100,
        viewportHeight: 100,
      );
      expect(presentation.problems, isEmpty);
      expect(
        presentation.values[document.getElementById('r')!.index]?[property],
        'url(#effect)',
      );
    });
  }
}
