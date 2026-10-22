/// Stylesheet parsing with `package:csslib` into compiled rules. Pure Dart.
library;

import 'package:csslib/parser.dart' as css;
import 'package:csslib/visitor.dart';
import 'package:shiori/features/reader/data/epub/epub_url.dart';
import 'package:shiori/features/reader/engine/style/computed_style.dart';
import 'package:shiori/features/reader/engine/style/css_properties.dart';
import 'package:shiori/features/reader/engine/style/css_selector.dart';
import 'package:shiori/features/reader/engine/style/css_values.dart';
import 'package:shiori/features/reader/engine/style/style_diagnostic.dart';

/// One compiled rule: a single selector with its longhand declarations.
final class CssRule {
  const CssRule(this.selector, this.declarations, this.order);

  final CssSelector selector;
  final List<CssDeclaration> declarations;

  /// Position across all stylesheets of the document (source order).
  final int order;
}

/// An `@font-face` rule with unresolved `src` URLs.
final class CssFontFace {
  const CssFontFace({
    required this.family,
    required this.urls,
    required this.basePath,
    this.weight = 400,
    this.style = StyleFontStyle.normal,
  });

  final String family;

  /// `url()` sources in order (raw, relative to [basePath]).
  final List<String> urls;

  /// Archive path of the stylesheet that declared the face.
  final String basePath;
  final int weight;
  final StyleFontStyle style;
}

/// Reads a stylesheet text by archive path; null when absent.
typedef StylesheetReader = String? Function(String path);

/// Accumulates the rules of several stylesheets in cascade order.
final class CssSheetBuilder {
  CssSheetBuilder({this.sink, this.reader, int firstOrder = 0})
    : _order = firstOrder;

  final StyleDiagnosticSink? sink;
  final StylesheetReader? reader;
  int _order;
  final List<CssRule> rules = [];
  final List<CssFontFace> fontFaces = [];

  int get nextOrder => _order;
  static const _maxImportDepth = 4;

  /// Adds the rules of [text], whose archive path is [basePath].
  void addStylesheet(
    String text,
    String basePath, {
    int depth = 0,
    Set<String> active = const {},
  }) {
    final errors = <css.Message>[];
    StyleSheet sheet;
    try {
      sheet = css.parse(text, errors: errors);
    } on Object {
      sink?.add(StyleDiagnosticKind.parseError, 'stylesheet');
      return;
    }
    if (errors.isNotEmpty) {
      sink?.add(StyleDiagnosticKind.parseError, 'css', errors.length);
    }
    _addTopLevels(sheet.topLevels, basePath, depth, {...active, basePath});
  }

  void _addTopLevels(
    List<TreeNode> topLevels,
    String basePath,
    int depth,
    Set<String> active,
  ) {
    for (final top in topLevels) {
      if (top is RuleSet) {
        _addRule(top);
      } else if (top is FontFaceDirective) {
        _addFontFace(top, basePath);
      } else if (top is ImportDirective) {
        _addImport(top, basePath, depth, active);
      } else if (top is MediaDirective) {
        if (_mediaMatches(top.mediaQueries)) {
          _addTopLevels(top.rules, basePath, depth, active);
        } else {
          sink?.add(StyleDiagnosticKind.unsupportedAtRule, '@media');
        }
      } else if (top is CharsetDirective || top is NamespaceDirective) {
        continue;
      } else if (top is PageDirective) {
        sink?.add(StyleDiagnosticKind.unsupportedAtRule, '@page');
      } else if (top is Directive) {
        sink?.add(
          StyleDiagnosticKind.unsupportedAtRule,
          top.runtimeType.toString(),
        );
      }
    }
  }

  void _addImport(
    ImportDirective directive,
    String basePath,
    int depth,
    Set<String> active,
  ) {
    if (!_mediaMatches(directive.mediaQueries, emptyMatches: true)) {
      sink?.add(StyleDiagnosticKind.stylesheetSkipped, '@import media');
      return;
    }
    final href = directive.import;
    if (isExternalUrl(href)) {
      sink?.add(StyleDiagnosticKind.stylesheetSkipped, '@import external');
      return;
    }
    if (depth >= _maxImportDepth) {
      sink?.add(StyleDiagnosticKind.stylesheetSkipped, '@import depth');
      return;
    }
    final path = _stripFragment(resolveUrl(href, basePath));
    if (active.contains(path)) {
      sink?.add(StyleDiagnosticKind.stylesheetSkipped, '@import cycle');
      return;
    }
    final text = reader?.call(path);
    if (text == null) {
      sink?.add(StyleDiagnosticKind.stylesheetNotFound, '@import');
      return;
    }
    addStylesheet(text, path, depth: depth + 1, active: active);
  }

  /// Screen-applicable media: no queries, `all`, or `screen` without feature
  /// expressions; `not`/`only` and expressions are not evaluated.
  bool _mediaMatches(List<MediaQuery> queries, {bool emptyMatches = true}) {
    if (queries.isEmpty) return emptyMatches;
    for (final query in queries) {
      if (query.hasUnary && query.unary == 'not') continue;
      if (query.expressions.isNotEmpty) continue;
      if (!query.hasMediaType) return true;
      final type = query.mediaType.toLowerCase();
      if (type == 'all' || type == 'screen') return true;
    }
    return false;
  }

  void _addRule(RuleSet rule) {
    final declarations = declarationsOf(rule.declarationGroup, sink);
    final selectors = compileSelectorGroup(rule.selectorGroup, sink);
    for (final selector in selectors) {
      rules.add(CssRule(selector, declarations, _order++));
    }
  }

  void _addFontFace(FontFaceDirective directive, String basePath) {
    final collector = _DeclarationCollector();
    directive.visit(collector);
    String? family;
    final urls = <String>[];
    var weight = 400;
    var style = StyleFontStyle.normal;
    for (final declaration in collector.declarations) {
      final tokens = convertExpression(declaration.expression);
      if (tokens == null) continue;
      switch (declaration.property.toLowerCase()) {
        case 'font-family':
          family = [
            for (final t in tokens)
              if (t.kind == CssTokenKind.string || t.kind == CssTokenKind.ident)
                t.kind == CssTokenKind.ident && t.raw.isNotEmpty
                    ? t.raw
                    : t.text,
          ].join(' ');
        case 'src':
          for (final t in tokens) {
            if (t.kind == CssTokenKind.uri) urls.add(t.text);
          }
        case 'font-weight':
          final first = tokens.first;
          if (first.kind == CssTokenKind.number) {
            weight = ((first.number / 100).round() * 100).clamp(100, 900);
          } else if (first.isIdent('bold')) {
            weight = 700;
          }
        case 'font-style':
          if (tokens.first.isIdent('italic') ||
              tokens.first.isIdent('oblique')) {
            style = StyleFontStyle.italic;
          }
      }
    }
    if (family == null || family.isEmpty || urls.isEmpty) {
      sink?.add(StyleDiagnosticKind.invalidValue, '@font-face');
      return;
    }
    fontFaces.add(
      CssFontFace(
        family: family,
        urls: urls,
        basePath: basePath,
        weight: weight,
        style: style,
      ),
    );
  }
}

String _stripFragment(String path) {
  final hash = path.indexOf('#');
  return hash < 0 ? path : path.substring(0, hash);
}

/// Longhand declarations of a declaration block, with invalid or unsupported
/// ones dropped and reported to [sink].
List<CssDeclaration> declarationsOf(
  DeclarationGroup group,
  StyleDiagnosticSink? sink,
) {
  final result = <CssDeclaration>[];
  for (final node in group.declarations) {
    if (node is! Declaration) continue;
    if (node.isIE7) continue;
    final property = node.property.toLowerCase();
    final tokens = convertExpression(node.expression);
    if (tokens == null) {
      sink?.add(StyleDiagnosticKind.invalidValue, property);
      continue;
    }
    final expanded = expandDeclaration(property, tokens, node.important, sink);
    if (expanded != null) result.addAll(expanded);
  }
  return result;
}

/// Declarations of an inline `style` attribute value.
List<CssDeclaration> parseInlineStyle(String text, StyleDiagnosticSink? sink) {
  final errors = <css.Message>[];
  StyleSheet sheet;
  try {
    sheet = css.parse('x{$text}', errors: errors);
  } on Object {
    sink?.add(StyleDiagnosticKind.parseError, 'style attribute');
    return const [];
  }
  if (errors.isNotEmpty) {
    sink?.add(StyleDiagnosticKind.parseError, 'style attribute', errors.length);
  }
  for (final top in sheet.topLevels) {
    if (top is RuleSet) return declarationsOf(top.declarationGroup, sink);
  }
  return const [];
}

class _DeclarationCollector extends Visitor {
  final List<Declaration> declarations = [];

  @override
  void visitDeclaration(Declaration node) {
    declarations.add(node);
  }
}
