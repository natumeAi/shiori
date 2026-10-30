import 'package:csslib/parser.dart' as css;
import 'package:csslib/visitor.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/source/source_node.dart';
import 'package:shiori/features/reader/engine/fixed/svg/svg_graphics.dart';
import 'package:shiori/features/reader/engine/style/css_selector.dart';
import 'package:shiori/features/reader/engine/style/css_stylesheet.dart';
import 'package:shiori/features/reader/engine/style/style_diagnostic.dart';

/// SVG-specific values, using the existing CSS parser, selector matcher and
/// authored media evaluator. Sheets arrive in author order after local resource
/// collection; the caller remains responsible for imports and linked sheets.
final class SvgPresentation {
  SvgPresentation._(this.values, this.problems, this.handedOffDiagnostics);
  final Map<int, Map<String, String>> values;
  final List<String> problems;

  /// Aggregated XHTML diagnostics whose declarations match only SVG elements.
  final Set<(StyleDiagnosticKind, String)> handedOffDiagnostics;

  /// Parse standard SVG filter declarations without csslib's legacy IE filter
  /// parser, which consumes `none !important` as an unterminated function.
  /// Keep offsets intact and restore only the property identifiers we changed.
  static StyleSheet parseStylesheet(String text, {List<css.Message>? errors}) {
    final offsets = <int>{};
    final input = text.replaceAllMapped(
      RegExp(
        r'''/\*.*?\*/|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|([;{](?:\s|/\*.*?\*/)*)filter((?:\s|/\*.*?\*/)*:)''',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) {
        final prefix = match.group(1);
        if (prefix == null) return match[0]!;
        offsets.add(match.start + prefix.length);
        return '${prefix}filt_r${match[2]}';
      },
    );
    final sheet = css.parse(input, errors: errors);
    sheet.visit(_RestoreFilterProperties(offsets));
    return sheet;
  }

  static SvgPresentation resolve(
    SourceDocument document,
    Iterable<String> sheets, {
    required double viewportWidth,
    required double viewportHeight,
    SvgFeatureRegistry? features,
  }) {
    final registry = features ?? SvgFeatureRegistry.defaults;
    final tree = StyleTree(document), sink = StyleDiagnosticSink();
    final media = CssSheetBuilder(
      sink: sink,
      viewportWidth: viewportWidth,
      viewportHeight: viewportHeight,
    );
    final winners = <int, Map<String, (bool, int, int, String)>>{};
    final problems = <String>[];
    final svgDiagnostics = <(StyleDiagnosticKind, String)>{};
    final otherDiagnostics = <(StyleDiagnosticKind, String)>{};
    void diagnose(DeclarationGroup group, List<int> nodes) {
      final diagnostics = StyleDiagnosticSink();
      declarationsOf(group, diagnostics);
      final onlySvg =
          nodes.isNotEmpty &&
          nodes.every(
            (i) =>
                document.node(i).namespaceUri == 'http://www.w3.org/2000/svg',
          );
      for (final diagnostic in diagnostics.diagnostics) {
        (onlySvg ? svgDiagnostics : otherDiagnostics).add((
          diagnostic.kind,
          diagnostic.detail,
        ));
        if (onlySvg &&
            diagnostic.kind == StyleDiagnosticKind.unsupportedProperty &&
            registry.presentationOwner(diagnostic.detail) == null &&
            !_presentationProperties.contains(diagnostic.detail) &&
            !registry.ownsAttribute(diagnostic.detail)) {
          problems.add('svg-css-${diagnostic.detail}');
        }
      }
    }

    var order = 0;
    void declarations(
      DeclarationGroup group,
      List<int> nodes,
      int specificity,
    ) {
      for (final declaration in group.declarations.whereType<Declaration>()) {
        final key = declaration.property.toLowerCase();
        var raw = _declarationValue(declaration);
        final owner = registry.presentationOwner(key);
        final ownedAttribute = registry.ownsAttribute(key);
        if (owner == null &&
            !_presentationProperties.contains(key) &&
            !ownedAttribute) {
          if (_renderingProperties.contains(key) &&
              nodes.isNotEmpty &&
              (raw == null ||
                  !const {
                    'none',
                    'normal',
                    'auto',
                    'initial',
                    'unset',
                  }.contains(raw.toLowerCase()))) {
            problems.add(raw == null ? 'svg-css-value' : 'svg-css-$key');
          }
          continue;
        }
        if (raw == null) {
          if (nodes.isNotEmpty) problems.add('svg-css-value');
          continue;
        }
        if (owner != null) {
          if (owner.presentationIgnored(key, raw)) {
            // A no-effect value still participates in the cascade: the winner
            // must override earlier rules and presentation attributes.
            raw = 'none';
          } else {
            final refusal = owner.presentationRefusal(key, raw);
            if (refusal != null) {
              if (nodes.isNotEmpty) problems.add(refusal);
              continue;
            }
          }
        } else if (key == 'd') {
          raw = _cssPathValue(raw);
        }
        final value = (declaration.important, specificity, order++, raw);
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
          final selectors = compileSelectorGroup(rule.selectorGroup, sink);
          diagnose(rule.declarationGroup, [
            for (final node in document.nodes)
              if (node.kind == SourceNodeKind.element &&
                  selectors.any(
                    (selector) => selector.matches(tree, node.index),
                  ))
                node.index,
          ]);
          for (final selector in selectors) {
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
      final parsed = parseStylesheet(sheet, errors: errors);
      if (errors.isNotEmpty) problems.add('svg-css-parse');
      rules(parsed.topLevels);
    }
    for (final node in document.nodes) {
      final inline = node.attribute('style');
      if (inline == null) continue;
      final parsed = parseStylesheet('svg{$inline}');
      final rule = parsed.topLevels.whereType<RuleSet>().single;
      diagnose(rule.declarationGroup, [node.index]);
      if (node.namespaceUri != 'http://www.w3.org/2000/svg') continue;
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
      Set.unmodifiable(svgDiagnostics.difference(otherDiagnostics)),
    );
  }
}

final class _RestoreFilterProperties extends Visitor {
  _RestoreFilterProperties(this.offsets);
  final Set<int> offsets;

  @override
  void visitIdentifier(Identifier node) {
    if (node.name == 'filt_r' && offsets.contains(node.span?.start.offset)) {
      node.name = 'filter';
    }
  }
}

/// Declaration spans in csslib cover the whole source declaration even though
/// `expression.span` stops at the first token for function values. Keep the
/// authored value text, including `url(...)`, `translate(...)` and lists.
String? _declarationValue(Declaration declaration) {
  final text = declaration.span.text;
  final colon = text.indexOf(':');
  if (colon >= 0) {
    var value = text
        .substring(colon + 1)
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), ' ');
    if (declaration.important) {
      value = value.replaceFirst(
        RegExp(r'!\s*important\s*$', caseSensitive: false),
        '',
      );
    }
    value = value.trim();
    if (value.isNotEmpty) return value;
  }
  final expression = declaration.expression;
  if (expression == null) return null;
  final printer = CssPrinter();
  expression.visit(printer);
  final printed = printer.toString().trim();
  return printed.isEmpty ? null : printed;
}

/// CSS `d` uses `path("...")`; the shape builder accepts authored path data.
String _cssPathValue(String raw) {
  final match = RegExp(
    r'''^path\(\s*(["'])(.*)\1\s*\)$''',
    dotAll: true,
  ).firstMatch(raw.trim());
  return match?.group(2) ?? raw;
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
  'transform',
  'marker-start',
  'marker-mid',
  'marker-end',
  'stop-color',
  'stop-opacity',
  // SVG 2 geometry properties, applied where the equivalent attribute exists.
  'x',
  'y',
  'width',
  'height',
  'cx',
  'cy',
  'r',
  'rx',
  'ry',
  'd',
};

/// Every SVG rendering/geometry presentation property this module might meet.
/// A property outside [_presentationProperties] and not owned by a feature is
/// refused, never silently dropped.
const _renderingProperties = {
  'alignment-baseline',
  'baseline-shift',
  'clip',
  'clip-path',
  'clip-rule',
  'color-interpolation',
  'color-interpolation-filters',
  'color-rendering',
  'direction',
  'dominant-baseline',
  'enable-background',
  'filter',
  'flood-color',
  'flood-opacity',
  'font-family',
  'font-feature-settings',
  'font-kerning',
  'font-size',
  'font-size-adjust',
  'font-stretch',
  'font-style',
  'font-variant',
  'font-variant-caps',
  'font-variant-east-asian',
  'font-variant-ligatures',
  'font-variant-numeric',
  'font-weight',
  'glyph-orientation-horizontal',
  'glyph-orientation-vertical',
  'image-rendering',
  'isolation',
  'kerning',
  'letter-spacing',
  'lighting-color',
  'marker',
  'mask',
  'mask-type',
  'mix-blend-mode',
  'paint-order',
  'shape-rendering',
  'stroke-alignment',
  'text-anchor',
  'text-decoration',
  'text-decoration-color',
  'text-decoration-line',
  'text-decoration-style',
  'text-rendering',
  'transform-box',
  'transform-origin',
  'unicode-bidi',
  'vector-effect',
  'white-space',
  'word-spacing',
  'writing-mode',
};
