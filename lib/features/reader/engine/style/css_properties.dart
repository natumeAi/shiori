/// Property tables: shorthand expansion and typed longhand parsing for the
/// style matrix (S2 design 5.2). Pure Dart.
library;

import 'package:shiori/features/reader/engine/style/computed_style.dart';
import 'package:shiori/features/reader/engine/style/css_values.dart';
import 'package:shiori/features/reader/engine/style/style_diagnostic.dart';

import 'dart:math' as math;

part 'css_authored_properties.dart';

/// CSS-wide keywords.
enum CssKeyword { inherit, initial, unset }

enum CssLengthUnit { px, em, rem, percent, auto, none }

/// A parsed length; absolute units are already converted to CSS px, `ex`
/// is approximated as 0.5 em.
final class CssLength {
  const CssLength(this.value, this.unit);
  const CssLength.auto() : value = 0, unit = CssLengthUnit.auto;
  const CssLength.none() : value = 0, unit = CssLengthUnit.none;

  final double value;
  final CssLengthUnit unit;
}

/// `color` / `background-color` value.
final class CssColor {
  const CssColor(this.argb) : isCurrent = false;
  const CssColor.current() : argb = 0, isCurrent = true;

  /// 0xAARRGGBB; 0x00000000 is `transparent`.
  final int argb;
  final bool isCurrent;
}

final class CssLineHeight {
  const CssLineHeight.normal() : multiplier = null, length = null;
  const CssLineHeight.multiplier(double this.multiplier) : length = null;
  const CssLineHeight.length(CssLength this.length) : multiplier = null;

  final double? multiplier;
  final CssLength? length;
}

/// `font-weight`: absolute 100-900, or relative to the parent.
final class CssFontWeight {
  const CssFontWeight.absolute(int this.weight) : relative = 0;
  const CssFontWeight.bolder() : weight = null, relative = 1;
  const CssFontWeight.lighter() : weight = null, relative = -1;

  final int? weight;
  final int relative;
}

final class CssDecoration {
  const CssDecoration({this.underline = false, this.lineThrough = false});
  final bool underline;
  final bool lineThrough;
}

/// A declaration reduced to one longhand with a typed value (a
/// [CssKeyword] for CSS-wide keywords).
final class CssDeclaration {
  const CssDeclaration(this.property, this.value, this.important);

  final String property;
  final Object value;
  final bool important;
}

class _Invalid implements Exception {
  const _Invalid(this.kind, this.detail);
  final StyleDiagnosticKind kind;
  final String detail;
}

const _longhands = {
  'display',
  'margin-top',
  'margin-right',
  'margin-bottom',
  'margin-left',
  'padding-top',
  'padding-right',
  'padding-bottom',
  'padding-left',
  'text-indent',
  'text-align',
  'font-size',
  'font-weight',
  'font-style',
  'font-family',
  'line-height',
  'letter-spacing',
  'color',
  'background-color',
  'white-space',
  'vertical-align',
  'text-decoration-line',
  'overflow-wrap',
  'width',
  'height',
  'max-width',
  'max-height',
  'writing-mode',
  'direction',
  'break-before',
  'break-after',
  'list-style-type',
};

/// Properties that CSS inherits (`text-decoration` is not, but see the
/// resolver: it propagates to descendants visually).
const inheritedProperties = {
  'text-indent',
  'text-align',
  'font-size',
  'font-weight',
  'font-style',
  'font-family',
  'line-height',
  'letter-spacing',
  'color',
  'white-space',
  'overflow-wrap',
  'writing-mode',
  'direction',
  'list-style-type',
};

const _listStyleTypes = {
  'none': StyleListStyleType.none,
  'disc': StyleListStyleType.disc,
  'circle': StyleListStyleType.circle,
  'square': StyleListStyleType.square,
  'decimal': StyleListStyleType.decimal,
  'lower-alpha': StyleListStyleType.lowerAlpha,
  'lower-latin': StyleListStyleType.lowerAlpha,
  'upper-alpha': StyleListStyleType.upperAlpha,
  'upper-latin': StyleListStyleType.upperAlpha,
  'lower-roman': StyleListStyleType.lowerRoman,
  'upper-roman': StyleListStyleType.upperRoman,
};

const _vendorAliases = {
  '-epub-writing-mode': 'writing-mode',
  '-webkit-writing-mode': 'writing-mode',
  'word-wrap': 'overflow-wrap',
  '-webkit-box-decoration-break': 'box-decoration-break',
};

/// SVG feature-owned declarations. The SVG module reads these from the
/// authored declaration; they have no XHTML layout effect and must not become
/// `unsupportedProperty` diagnostics that reject a fixed scene.
const _featureOwnedSvgProperties = {
  'mask-type',
  'clip-rule',
  'clipPathUnits',
  'maskUnits',
  'maskContentUnits',
};

/// Expands [property] (a shorthand, alias or longhand) into typed longhand
/// declarations. Returns null and reports to [sink] when the property is
/// unknown or its value is invalid.
List<CssDeclaration>? expandDeclaration(
  String property,
  List<CssToken> tokens,
  bool important,
  StyleDiagnosticSink? sink,
) {
  final name = _vendorAliases[property] ?? property;
  try {
    final pairs = _expand(name, tokens);
    if (pairs == null) {
      sink?.add(StyleDiagnosticKind.unsupportedProperty, property);
      return null;
    }
    return [
      for (final (longhand, value) in pairs)
        CssDeclaration(
          longhand,
          _parseLonghand(longhand, value, sink),
          important,
        ),
    ];
  } on _Invalid catch (invalid) {
    sink?.add(invalid.kind, invalid.detail.isEmpty ? name : invalid.detail);
    return null;
  }
}

List<(String, List<CssToken>)>? _expand(String name, List<CssToken> tokens) {
  if (_featureOwnedSvgProperties.contains(name)) return const [];
  if (_longhands.contains(name) || authoredLonghands.contains(name)) {
    return [(name, tokens)];
  }
  final authored = _expandAuthored(name, tokens);
  if (authored != null) return authored;
  switch (name) {
    case 'margin':
    case 'padding':
      final keyword = _wideKeyword(tokens);
      final values = tokens.length > 4 || tokens.isEmpty
          ? throw _Invalid(StyleDiagnosticKind.invalidValue, name)
          : tokens;
      List<CssToken> at(int i) => keyword != null ? tokens : [values[i]];
      final top = 0;
      final right = values.length > 1 ? 1 : 0;
      final bottom = values.length > 2 ? 2 : 0;
      final left = values.length > 3 ? 3 : (values.length > 1 ? 1 : 0);
      return [
        ('$name-top', at(top)),
        ('$name-right', at(right)),
        ('$name-bottom', at(bottom)),
        ('$name-left', at(left)),
      ];
    case 'font':
      return _expandFont(tokens);
    case 'background':
      return _expandBackground(tokens);
    case 'text-decoration':
      return _expandTextDecoration(tokens);
    case 'list-style':
      for (final token in tokens) {
        if (token.kind == CssTokenKind.ident &&
            _listStyleTypes.containsKey(token.text)) {
          return [
            ('list-style-type', [token]),
          ];
        }
      }
      return const [];
    case 'page-break-before':
      return [('break-before', _pageBreak(tokens))];
    case 'page-break-after':
      return [('break-after', _pageBreak(tokens))];
    case 'word-break':
      if (tokens.length == 1 && tokens.first.isIdent('break-all')) {
        return [
          (
            'overflow-wrap',
            [const CssToken(CssTokenKind.ident, text: 'anywhere')],
          ),
        ];
      }
      return const [];
  }
  return null;
}

CssKeyword? _wideKeyword(List<CssToken> tokens) {
  if (tokens.length != 1 || tokens.first.kind != CssTokenKind.ident) {
    return null;
  }
  return switch (tokens.first.text) {
    'inherit' => CssKeyword.inherit,
    'initial' => CssKeyword.initial,
    'unset' => CssKeyword.unset,
    _ => null,
  };
}

List<CssToken> _pageBreak(List<CssToken> tokens) {
  if (tokens.length != 1 || tokens.first.kind != CssTokenKind.ident) {
    throw const _Invalid(StyleDiagnosticKind.invalidValue, 'page-break');
  }
  final text = tokens.first.text;
  if (text == 'always') {
    return [const CssToken(CssTokenKind.ident, text: 'page')];
  }
  return tokens;
}

const _sizeKeywords = {
  'xx-small': 9.0,
  'x-small': 10.0,
  'small': 13.0,
  'medium': 16.0,
  'large': 18.0,
  'x-large': 24.0,
  'xx-large': 32.0,
  'xxx-large': 48.0,
};

bool _isFontSizeToken(CssToken t) =>
    t.kind == CssTokenKind.length ||
    t.kind == CssTokenKind.percent ||
    (t.kind == CssTokenKind.ident &&
        (_sizeKeywords.containsKey(t.text) ||
            t.text == 'smaller' ||
            t.text == 'larger'));

List<(String, List<CssToken>)> _expandFont(List<CssToken> tokens) {
  final keyword = _wideKeyword(tokens);
  const longhandNames = [
    'font-style',
    'font-weight',
    'font-size',
    'line-height',
    'font-family',
  ];
  if (keyword != null) {
    return [for (final name in longhandNames) (name, tokens)];
  }
  var style = <CssToken>[const CssToken(CssTokenKind.ident, text: 'normal')];
  var weight = <CssToken>[const CssToken(CssTokenKind.ident, text: 'normal')];
  var index = 0;
  while (index < tokens.length && !_isFontSizeToken(tokens[index])) {
    final t = tokens[index];
    if (t.kind == CssTokenKind.ident) {
      switch (t.text) {
        case 'normal' || 'small-caps' || 'condensed' || 'expanded':
          break;
        case 'italic' || 'oblique':
          style = [t];
        case 'bold' || 'bolder' || 'lighter':
          weight = [t];
        default:
          throw const _Invalid(StyleDiagnosticKind.invalidValue, 'font');
      }
    } else if (t.kind == CssTokenKind.number) {
      weight = [t];
    } else {
      throw const _Invalid(StyleDiagnosticKind.invalidValue, 'font');
    }
    index++;
  }
  if (index >= tokens.length) {
    throw const _Invalid(StyleDiagnosticKind.invalidValue, 'font');
  }
  final size = tokens[index++];
  var lineHeight = <CssToken>[
    const CssToken(CssTokenKind.ident, text: 'normal'),
  ];
  if (index < tokens.length && tokens[index].kind == CssTokenKind.slash) {
    index++;
    if (index >= tokens.length) {
      throw const _Invalid(StyleDiagnosticKind.invalidValue, 'font');
    }
    lineHeight = [tokens[index++]];
  }
  final family = tokens.sublist(index);
  if (family.isEmpty) {
    throw const _Invalid(StyleDiagnosticKind.invalidValue, 'font');
  }
  return [
    ('font-style', style),
    ('font-weight', weight),
    ('font-size', [size]),
    ('line-height', lineHeight),
    ('font-family', family),
  ];
}

List<(String, List<CssToken>)> _expandBackground(List<CssToken> tokens) {
  return _authoredBackground(tokens);
}

List<(String, List<CssToken>)> _expandTextDecoration(List<CssToken> tokens) {
  final keyword = _wideKeyword(tokens);
  if (keyword != null) return [('text-decoration-line', tokens)];
  final lines = [
    for (final token in tokens)
      if (token.kind == CssTokenKind.ident &&
          const {
            'none',
            'underline',
            'overline',
            'line-through',
            'blink',
          }.contains(token.text))
        token,
  ];
  return [
    (
      'text-decoration-line',
      lines.isEmpty
          ? [const CssToken(CssTokenKind.ident, text: 'none')]
          : lines,
    ),
  ];
}

Object _parseLonghand(
  String name,
  List<CssToken> tokens,
  StyleDiagnosticSink? sink,
) {
  final keyword = _wideKeyword(tokens);
  if (keyword != null) return keyword;
  if (authoredLonghands.contains(name)) return _parseAuthored(name, tokens);
  switch (name) {
    case 'display':
      return _display(_ident(tokens, name), sink);
    case 'margin-top' || 'margin-right' || 'margin-bottom' || 'margin-left':
      return _length(_one(tokens, name), name, allowAuto: true);
    case 'padding-top' || 'padding-right' || 'padding-bottom' || 'padding-left':
      return _length(_one(tokens, name), name, allowNegative: false);
    case 'text-indent':
      return _length(_one(tokens, name), name);
    case 'text-align':
      return switch (_ident(tokens, name)) {
        'left' || 'match-parent' => StyleTextAlign.left,
        'right' || 'end' => StyleTextAlign.right,
        'center' || '-webkit-center' => StyleTextAlign.center,
        'justify' || 'justify-all' => StyleTextAlign.justify,
        'start' => StyleTextAlign.start,
        _ => throw _Invalid(StyleDiagnosticKind.invalidValue, name),
      };
    case 'font-size':
      return _fontSize(_one(tokens, name));
    case 'font-weight':
      return _fontWeight(_one(tokens, name));
    case 'font-style':
      return switch (_ident(tokens, name)) {
        'normal' => StyleFontStyle.normal,
        'italic' || 'oblique' => StyleFontStyle.italic,
        _ => throw _Invalid(StyleDiagnosticKind.invalidValue, name),
      };
    case 'font-family':
      return _fontFamily(tokens);
    case 'line-height':
      return _lineHeight(_one(tokens, name));
    case 'letter-spacing':
      final token = _one(tokens, name);
      if (token.isIdent('normal')) return const CssLength(0, CssLengthUnit.px);
      return _length(token, name, allowPercent: false);
    case 'color':
      return _color(_one(tokens, name), name);
    case 'background-color':
      return _color(_one(tokens, name), name);
    case 'white-space':
      return switch (_ident(tokens, name)) {
        'normal' => StyleWhiteSpace.normal,
        'pre' => StyleWhiteSpace.pre,
        'pre-wrap' || 'break-spaces' => StyleWhiteSpace.preWrap,
        'pre-line' => StyleWhiteSpace.preLine,
        'nowrap' => StyleWhiteSpace.nowrap,
        _ => throw _Invalid(StyleDiagnosticKind.invalidValue, name),
      };
    case 'vertical-align':
      final token = _one(tokens, name);
      if (token.kind == CssTokenKind.ident) {
        switch (token.text) {
          case 'baseline':
            return StyleVerticalAlign.baseline;
          case 'sub':
            return StyleVerticalAlign.sub;
          case 'super':
            return StyleVerticalAlign.superscript;
          case 'top' || 'middle' || 'bottom' || 'text-top' || 'text-bottom':
            sink?.add(StyleDiagnosticKind.approximatedValue, 'vertical-align');
            return StyleVerticalAlign.baseline;
        }
      } else if (token.kind == CssTokenKind.length ||
          token.kind == CssTokenKind.percent) {
        sink?.add(StyleDiagnosticKind.approximatedValue, 'vertical-align');
        return StyleVerticalAlign.baseline;
      }
      throw _Invalid(StyleDiagnosticKind.invalidValue, name);
    case 'text-decoration-line':
      var underline = false;
      var lineThrough = false;
      for (final token in tokens) {
        if (token.kind != CssTokenKind.ident) {
          throw _Invalid(StyleDiagnosticKind.invalidValue, name);
        }
        switch (token.text) {
          case 'underline':
            underline = true;
          case 'line-through':
            lineThrough = true;
          case 'none' || 'overline' || 'blink':
            break;
          default:
            throw _Invalid(StyleDiagnosticKind.invalidValue, name);
        }
      }
      return CssDecoration(underline: underline, lineThrough: lineThrough);
    case 'overflow-wrap':
      return switch (_ident(tokens, name)) {
        'anywhere' => true,
        'normal' || 'break-word' => false,
        _ => throw _Invalid(StyleDiagnosticKind.invalidValue, name),
      };
    case 'width' || 'height':
      return _length(
        _one(tokens, name),
        name,
        allowAuto: true,
        allowNegative: false,
      );
    case 'max-width' || 'max-height':
      final token = _one(tokens, name);
      if (token.isIdent('none')) return const CssLength.none();
      return _length(token, name, allowNegative: false);
    case 'writing-mode':
      return switch (_ident(tokens, name)) {
        'horizontal-tb' ||
        'lr-tb' ||
        'lr' ||
        'rl-tb' ||
        'rl' => StyleWritingMode.horizontalTb,
        'vertical-rl' || 'tb-rl' || 'tb' => StyleWritingMode.verticalRl,
        'vertical-lr' || 'tb-lr' => StyleWritingMode.verticalLr,
        'sideways-rl' || 'sideways-lr' => StyleWritingMode.verticalRl,
        _ => throw _Invalid(StyleDiagnosticKind.invalidValue, name),
      };
    case 'direction':
      return switch (_ident(tokens, name)) {
        'ltr' => StyleDirection.ltr,
        'rtl' => StyleDirection.rtl,
        _ => throw _Invalid(StyleDiagnosticKind.invalidValue, name),
      };
    case 'list-style-type':
      return _listStyleTypes[_ident(tokens, name)] ??
          (throw _Invalid(StyleDiagnosticKind.invalidValue, name));
    case 'break-before' || 'break-after':
      return switch (_ident(tokens, name)) {
        'page' || 'always' || 'left' || 'right' || 'recto' || 'verso' => true,
        'auto' ||
        'avoid' ||
        'avoid-page' ||
        'column' ||
        'avoid-column' ||
        'region' ||
        'avoid-region' => false,
        _ => throw _Invalid(StyleDiagnosticKind.invalidValue, name),
      };
  }
  throw _Invalid(StyleDiagnosticKind.unsupportedProperty, name);
}

CssToken _one(List<CssToken> tokens, String name) {
  if (tokens.length != 1) {
    throw _Invalid(StyleDiagnosticKind.invalidValue, name);
  }
  return tokens.first;
}

String _ident(List<CssToken> tokens, String name) {
  final token = _one(tokens, name);
  if (token.kind != CssTokenKind.ident) {
    throw _Invalid(StyleDiagnosticKind.invalidValue, name);
  }
  return token.text;
}

StyleDisplay _display(String value, StyleDiagnosticSink? sink) {
  switch (value) {
    case 'none':
      return StyleDisplay.none;
    case 'block':
      return StyleDisplay.block;
    case 'inline':
      return StyleDisplay.inline;
    case 'list-item':
      return StyleDisplay.listItem;
    case 'inline-block':
      return StyleDisplay.inlineBlock;
    case 'inline-flex' || 'inline-table' || 'contents':
    case 'ruby' || 'ruby-base' || 'ruby-text' || 'ruby-text-container':
      sink?.add(StyleDiagnosticKind.approximatedValue, 'display:$value');
      return StyleDisplay.inline;
    case 'flex' ||
        'grid' ||
        'table' ||
        'table-row' ||
        'table-cell' ||
        'table-row-group' ||
        'table-header-group' ||
        'table-footer-group' ||
        'table-caption' ||
        'table-column' ||
        'table-column-group' ||
        'flow-root' ||
        'run-in':
      sink?.add(StyleDiagnosticKind.approximatedValue, 'display:$value');
      return StyleDisplay.block;
  }
  throw const _Invalid(StyleDiagnosticKind.invalidValue, 'display');
}

const _absoluteUnitPx = {
  'px': 1.0,
  'pt': 96 / 72,
  'pc': 16.0,
  'in': 96.0,
  'cm': 96 / 2.54,
  'mm': 96 / 25.4,
};

CssLength _length(
  CssToken token,
  String name, {
  bool allowAuto = false,
  bool allowPercent = true,
  bool allowNegative = true,
}) {
  if (!token.number.isFinite) {
    throw _Invalid(StyleDiagnosticKind.invalidValue, name);
  }
  switch (token.kind) {
    case CssTokenKind.ident when token.text == 'auto' && allowAuto:
      return const CssLength.auto();
    case CssTokenKind.number when token.number == 0:
      return const CssLength(0, CssLengthUnit.px);
    case CssTokenKind.percent when allowPercent:
      if (!allowNegative && token.number < 0) {
        throw _Invalid(StyleDiagnosticKind.invalidValue, name);
      }
      return CssLength(token.number, CssLengthUnit.percent);
    case CssTokenKind.length:
      if (!allowNegative && token.number < 0) {
        throw _Invalid(StyleDiagnosticKind.invalidValue, name);
      }
      final absolute = _absoluteUnitPx[token.unit];
      if (absolute != null) {
        return CssLength(token.number * absolute, CssLengthUnit.px);
      }
      switch (token.unit) {
        case 'em':
          return CssLength(token.number, CssLengthUnit.em);
        case 'rem':
          return CssLength(token.number, CssLengthUnit.rem);
        case 'ex':
          return CssLength(token.number * 0.5, CssLengthUnit.em);
        default:
          throw _Invalid(StyleDiagnosticKind.unsupportedUnit, token.unit);
      }
    case CssTokenKind.function:
      throw _Invalid(StyleDiagnosticKind.unsupportedUnit, token.text);
    default:
      throw _Invalid(StyleDiagnosticKind.invalidValue, name);
  }
}

CssLength _fontSize(CssToken token) {
  if (token.kind == CssTokenKind.ident) {
    final absolute = _sizeKeywords[token.text];
    if (absolute != null) return CssLength(absolute, CssLengthUnit.px);
    if (token.text == 'smaller') {
      return const CssLength(1 / 1.2, CssLengthUnit.em);
    }
    if (token.text == 'larger') return const CssLength(1.2, CssLengthUnit.em);
    throw const _Invalid(StyleDiagnosticKind.invalidValue, 'font-size');
  }
  return _length(token, 'font-size', allowNegative: false);
}

CssFontWeight _fontWeight(CssToken token) {
  if (token.kind == CssTokenKind.ident) {
    return switch (token.text) {
      'normal' => const CssFontWeight.absolute(400),
      'bold' => const CssFontWeight.absolute(700),
      'bolder' => const CssFontWeight.bolder(),
      'lighter' => const CssFontWeight.lighter(),
      _ => throw const _Invalid(
        StyleDiagnosticKind.invalidValue,
        'font-weight',
      ),
    };
  }
  if (token.kind == CssTokenKind.number &&
      token.number >= 1 &&
      token.number <= 1000) {
    final rounded = (token.number / 100).round() * 100;
    return CssFontWeight.absolute(rounded.clamp(100, 900));
  }
  throw const _Invalid(StyleDiagnosticKind.invalidValue, 'font-weight');
}

List<String> _fontFamily(List<CssToken> tokens) {
  final families = <String>[];
  final current = <String>[];
  void flush() {
    if (current.isEmpty) {
      throw const _Invalid(StyleDiagnosticKind.invalidValue, 'font-family');
    }
    families.add(current.join(' '));
    current.clear();
  }

  for (final token in tokens) {
    switch (token.kind) {
      case CssTokenKind.comma:
        flush();
      case CssTokenKind.string:
        if (current.isNotEmpty) {
          throw const _Invalid(StyleDiagnosticKind.invalidValue, 'font-family');
        }
        current.add(token.text);
      case CssTokenKind.ident:
        current.add(token.raw.isEmpty ? token.text : token.raw);
      default:
        throw const _Invalid(StyleDiagnosticKind.invalidValue, 'font-family');
    }
  }
  flush();
  return families;
}

CssLineHeight _lineHeight(CssToken token) {
  if (token.isIdent('normal')) return const CssLineHeight.normal();
  if (token.kind == CssTokenKind.number) {
    if (token.number < 0) {
      throw const _Invalid(StyleDiagnosticKind.invalidValue, 'line-height');
    }
    return CssLineHeight.multiplier(token.number);
  }
  return CssLineHeight.length(
    _length(token, 'line-height', allowNegative: false),
  );
}

CssColor _color(CssToken token, String name) {
  if (token.kind == CssTokenKind.color) return CssColor(token.color);
  if (token.kind == CssTokenKind.ident) {
    switch (token.text) {
      case 'transparent':
        return const CssColor(0x00000000);
      case 'currentcolor':
        return const CssColor.current();
    }
  }
  throw _Invalid(
    token.kind == CssTokenKind.function
        ? StyleDiagnosticKind.unsupportedUnit
        : StyleDiagnosticKind.invalidValue,
    token.kind == CssTokenKind.function ? token.text : name,
  );
}
