import 'package:csslib/parser.dart' as css;
import 'package:csslib/visitor.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/engine/style/css_selector.dart';
import 'package:shiori/features/reader/engine/style/css_stylesheet.dart';
import 'package:shiori/features/reader/engine/style/style_diagnostic.dart';

/// SVG-specific values, using the existing CSS parser, selector matcher and
/// authored media evaluator. Sheets arrive in author order after local resource
/// collection; the caller remains responsible for imports and linked sheets.
final class SvgPresentation {
  SvgPresentation._(this.values, this.problems);
  final Map<int, Map<String, String>> values;
  final List<String> problems;
  static SvgPresentation resolve(
    SourceDocument document,
    Iterable<String> sheets, {
    required double viewportWidth,
    required double viewportHeight,
  }) {
    final tree = StyleTree(document), sink = StyleDiagnosticSink();
    final media = CssSheetBuilder(
      sink: sink,
      viewportWidth: viewportWidth,
      viewportHeight: viewportHeight,
    );
    final winners = <int, Map<String, (bool, int, int, String)>>{};
    final problems = <String>[];
    var order = 0;
    void declarations(
      DeclarationGroup group,
      List<int> nodes,
      int specificity,
    ) {
      for (final declaration in group.declarations.whereType<Declaration>()) {
        final key = declaration.property.toLowerCase();
        if (!_presentationProperties.contains(key)) continue;
        final raw = declaration.expression?.span?.text;
        if (raw == null) {
          problems.add('svg-css-value');
          continue;
        }
        final value = (declaration.important, specificity, order++, raw.trim());
        for (final node in nodes) {
          final map = winners.putIfAbsent(node, () => {}), old = map[key];
          if (old == null ||
              (value.$1 && !old.$1) ||
              value.$1 == old.$1 &&
                  (value.$2 > old.$2 ||
                      value.$2 == old.$2 && value.$3 > old.$3)) {
            map[key] = value;
          }
        }
      }
    }

    void rules(List<TreeNode> entries) {
      for (final rule in entries) {
        if (rule is RuleSet) {
          for (final selector in compileSelectorGroup(
            rule.selectorGroup,
            sink,
          )) {
            final matches = [
              for (final node in document.nodes)
                if (node.namespaceUri == 'http://www.w3.org/2000/svg' &&
                    selector.matches(tree, node.index))
                  node.index,
            ];
            declarations(rule.declarationGroup, matches, selector.specificity);
          }
        } else if (rule is MediaDirective) {
          // Reuse the project evaluator, including orientation and sizes.
          final printer = CssPrinter();
          rule.visit(printer);
          final text = printer.toString();
          final condition = text
              .substring(text.indexOf('@media') + 6, text.indexOf('{'))
              .trim();
          if (media.matchesMediaAttribute(condition)) rules(rule.rules);
        } else if (rule is! FontFaceDirective &&
            rule is! ImportDirective &&
            rule is! CharsetDirective &&
            rule is! NamespaceDirective) {
          problems.add('svg-css-at-rule');
        }
      }
    }

    for (final sheet in sheets) {
      final errors = <css.Message>[];
      final parsed = css.parse(sheet, errors: errors);
      if (errors.isNotEmpty) problems.add('svg-css-parse');
      rules(parsed.topLevels);
    }
    for (final node in document.nodes) {
      if (node.namespaceUri != 'http://www.w3.org/2000/svg') continue;
      final inline = node.attribute('style');
      if (inline == null) continue;
      final parsed = css.parse('svg{$inline}');
      final rule = parsed.topLevels.whereType<RuleSet>().single;
      declarations(rule.declarationGroup, [node.index], 1 << 24);
    }
    problems.addAll(sink.diagnostics.map((d) => 'svg-css-${d.kind.name}'));
    return SvgPresentation._(
      Map.unmodifiable({
        for (final e in winners.entries)
          e.key: Map<String, String>.unmodifiable({
            for (final p in e.value.entries) p.key: p.value.$4,
          }),
      }),
      List.unmodifiable(problems),
    );
  }
}

const _presentationProperties = {
  'fill',
  'fill-rule',
  'fill-opacity',
  'stroke',
  'stroke-width',
  'stroke-linecap',
  'stroke-linejoin',
  'stroke-miterlimit',
  'stroke-dasharray',
  'stroke-dashoffset',
  'stroke-opacity',
  'color',
  'opacity',
  'visibility',
  'display',
  'overflow',
  'filter',
  'marker-start',
  'marker-mid',
  'marker-end',
  'stop-color',
  'stop-opacity',
};
