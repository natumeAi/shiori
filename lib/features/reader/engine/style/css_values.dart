/// Declaration values normalized from `package:csslib` terms into a small
/// token model. Pure Dart.
library;

import 'package:csslib/visitor.dart';

enum CssTokenKind {
  ident,
  string,
  number,
  length,
  percent,
  color,
  uri,
  function,
  comma,
  slash,
}

/// One value token. [unit] is the lowercase unit for [CssTokenKind.length]
/// (`px`, `pt`, `pc`, `in`, `cm`, `mm`, `em`, `rem`, `ex`, `ch`, `vw`, ...).
final class CssToken {
  const CssToken(
    this.kind, {
    this.text = '',
    this.raw = '',
    this.number = 0,
    this.unit = '',
    this.color = 0,
    this.arguments = const [],
  });

  /// Lowercase for identifiers; unquoted for strings; the path for `url()`;
  /// the lowercase name for functions.
  final CssTokenKind kind;
  final String text;

  /// The identifier as written (case preserved); empty for other kinds.
  final String raw;
  final double number;
  final String unit;

  /// 0xAARRGGBB for [CssTokenKind.color].
  final int color;
  final List<CssToken> arguments;

  bool isIdent(String name) => kind == CssTokenKind.ident && text == name;

  static const comma = CssToken(CssTokenKind.comma);
  static const slash = CssToken(CssTokenKind.slash);
}

/// Converts the parsed expression of a declaration. Null when a term has no
/// representation (the declaration is then invalid).
List<CssToken>? convertExpression(Expression? expression) {
  if (expression == null) return null;
  final terms = expression is Expressions
      ? expression.expressions
      : <Expression>[expression];
  final tokens = <CssToken>[];
  for (final term in terms) {
    final token = _convert(term);
    if (token == null) return null;
    tokens.add(token);
  }
  return tokens.isEmpty ? null : tokens;
}

CssToken? _convert(Expression term) {
  switch (term) {
    case OperatorComma():
      return CssToken.comma;
    case OperatorSlash():
      return CssToken.slash;
    case HexColorTerm():
      final color = _hexColor(term.text);
      return color == null ? null : CssToken(CssTokenKind.color, color: color);
    case FunctionTerm():
      return _function(term);
    case CalcTerm():
      return const CssToken(CssTokenKind.function, text: 'calc');
    case UriTerm():
      return CssToken(CssTokenKind.uri, text: term.value.toString());
    case PercentageTerm():
      return CssToken(
        CssTokenKind.percent,
        number: _number(term.value),
        unit: '%',
      );
    case EmTerm():
      return CssToken(
        CssTokenKind.length,
        number: _number(term.value),
        unit: 'em',
      );
    case ExTerm():
      return CssToken(
        CssTokenKind.length,
        number: _number(term.value),
        unit: 'ex',
      );
    case RemTerm():
      return CssToken(
        CssTokenKind.length,
        number: _number(term.value),
        unit: 'rem',
      );
    case UnitTerm():
      // Absolute lengths, `ch`, viewport units, line-height units, and
      // angles/times/frequencies/resolutions (not meaningful here).
      return CssToken(
        CssTokenKind.length,
        number: _number(term.value),
        unit: term.unitToString()?.toLowerCase() ?? '?',
      );
    case NumberTerm():
      return CssToken(CssTokenKind.number, number: _number(term.value));
    case LiteralTerm():
      final value = term.value;
      if (value is Identifier) {
        return CssToken(
          CssTokenKind.ident,
          text: value.name.toLowerCase(),
          raw: value.name,
        );
      }
      final text = value.toString();
      return CssToken(CssTokenKind.string, text: _unquote(text));
    default:
      return null;
  }
}

double _number(Object value) => value is num ? value.toDouble() : 0;

String _unquote(String text) {
  if (text.length >= 2) {
    final first = text[0];
    if ((first == '"' || first == "'") && text.endsWith(first)) {
      return text.substring(1, text.length - 1);
    }
  }
  return text;
}

int? _hexColor(String text) {
  var digits = text.startsWith('#') ? text.substring(1) : text;
  if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(digits)) return null;
  if (digits.length == 3 || digits.length == 4) {
    digits = digits.split('').map((c) => '$c$c').join();
  }
  if (digits.length == 6) return 0xFF000000 | int.parse(digits, radix: 16);
  if (digits.length == 8) {
    final value = int.parse(digits, radix: 16);
    return ((value & 0xFF) << 24) | (value >> 8);
  }
  return null;
}

CssToken? _function(FunctionTerm term) {
  final name = term.text.toLowerCase();
  if (name != 'rgb' && name != 'rgba') {
    final collector = _FunctionArguments();
    term.visit(collector);
    return CssToken(
      CssTokenKind.function,
      text: name,
      arguments: List.unmodifiable(collector.tokens ?? const []),
    );
  }
  final printer = CssPrinter();
  term.visit(printer);
  final printed = printer.toString();
  final open = printed.indexOf('(');
  final close = printed.lastIndexOf(')');
  if (open < 0 || close < open) return null;
  final parts = printed
      .substring(open + 1, close)
      .split(RegExp(r'[\s,/]+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.length < 3 || parts.length > 4) return null;
  int? channel(String part) {
    final percent = part.endsWith('%');
    final value = double.tryParse(
      percent ? part.substring(0, part.length - 1) : part,
    );
    if (value == null) return null;
    final scaled = percent ? value * 2.55 : value;
    return scaled.round().clamp(0, 255);
  }

  final red = channel(parts[0]);
  final green = channel(parts[1]);
  final blue = channel(parts[2]);
  if (red == null || green == null || blue == null) return null;
  var alpha = 255;
  if (parts.length == 4) {
    final percent = parts[3].endsWith('%');
    final raw = double.tryParse(
      percent ? parts[3].substring(0, parts[3].length - 1) : parts[3],
    );
    if (raw == null) return null;
    alpha = ((percent ? raw / 100 : raw).clamp(0, 1) * 255).round();
  }
  return CssToken(
    CssTokenKind.color,
    color: (alpha << 24) | (red << 16) | (green << 8) | blue,
  );
}

final class _FunctionArguments extends Visitor {
  List<CssToken>? tokens;
  @override
  void visitExpressions(Expressions node) {
    tokens = convertExpression(node);
  }
}
