part of 'css_properties.dart';

const authoredLonghands = {
  'position',
  'top',
  'right',
  'bottom',
  'left',
  'min-width',
  'min-height',
  'box-sizing',
  'opacity',
  'visibility',
  'z-index',
  'transform',
  'transform-origin',
  'overflow',
  'word-spacing',
  'background-image',
  'background-repeat',
  'background-position',
  'background-size',
  'border-top-width',
  'border-right-width',
  'border-bottom-width',
  'border-left-width',
  'border-top-color',
  'border-right-color',
  'border-bottom-color',
  'border-left-color',
  'border-top-style',
  'border-right-style',
  'border-bottom-style',
  'border-left-style',
  'border-top-left-radius',
  'border-top-right-radius',
  'border-bottom-right-radius',
  'border-bottom-left-radius',
};

List<(String, List<CssToken>)>? _expandAuthored(
  String name,
  List<CssToken> tokens,
) {
  if (name == 'border' ||
      const {
        'border-top',
        'border-right',
        'border-bottom',
        'border-left',
      }.contains(name)) {
    final edges = name == 'border'
        ? ['top', 'right', 'bottom', 'left']
        : [name.substring(7)];
    final wide = _wideKeyword(tokens);
    if (wide != null) {
      return [
        for (final edge in edges)
          for (final suffix in ['width', 'style', 'color'])
            ('border-$edge-$suffix', tokens),
      ];
    }
    CssToken? width, style, color;
    for (final token in tokens) {
      if (token.kind == CssTokenKind.length ||
          token.kind == CssTokenKind.number) {
        width = token;
      } else if (const {'solid', 'none'}.contains(token.text)) {
        style = token;
      } else {
        _color(token, name);
        color = token;
      }
    }
    return [
      for (final edge in edges) ...[
        (
          'border-$edge-width',
          [width ?? const CssToken(CssTokenKind.length, number: 3, unit: 'px')],
        ),
        (
          'border-$edge-style',
          [style ?? const CssToken(CssTokenKind.ident, text: 'none')],
        ),
        (
          'border-$edge-color',
          [color ?? const CssToken(CssTokenKind.ident, text: 'currentcolor')],
        ),
      ],
    ];
  }
  if (name == 'border-radius') {
    if (tokens.isEmpty ||
        tokens.length > 4 ||
        tokens.any((t) => t.kind == CssTokenKind.slash)) {
      throw const _Invalid(StyleDiagnosticKind.invalidValue, 'border-radius');
    }
    return [
      for (var i = 0; i < 4; i++)
        (
          'border-${['top-left', 'top-right', 'bottom-right', 'bottom-left'][i]}-radius',
          [
            tokens[i == 0
                ? 0
                : i == 1
                ? tokens.length > 1
                      ? 1
                      : 0
                : i == 2
                ? tokens.length > 2
                      ? 2
                      : 0
                : tokens.length > 3
                ? 3
                : tokens.length > 1
                ? 1
                : 0],
          ],
        ),
    ];
  }
  return null;
}

List<(String, List<CssToken>)> _authoredBackground(List<CssToken> tokens) {
  const names = [
    'background-color',
    'background-image',
    'background-repeat',
    'background-position',
    'background-size',
  ];
  if (_wideKeyword(tokens) != null) {
    return [for (final name in names) (name, tokens)];
  }
  final color = <CssToken>[],
      image = <CssToken>[],
      repeat = <CssToken>[],
      position = <CssToken>[],
      size = <CssToken>[];
  var afterSlash = false;
  for (final token in tokens) {
    if (token.kind == CssTokenKind.slash) {
      afterSlash = true;
      continue;
    }
    if (token.kind == CssTokenKind.uri || token.kind == CssTokenKind.function) {
      image.add(token);
      continue;
    }
    if (const {
      'repeat',
      'no-repeat',
      'repeat-x',
      'repeat-y',
    }.contains(token.text)) {
      repeat.add(token);
      continue;
    }
    if (token.kind == CssTokenKind.length ||
        token.kind == CssTokenKind.percent ||
        token.kind == CssTokenKind.number ||
        const {
          'left',
          'right',
          'top',
          'bottom',
          'center',
          'auto',
          'cover',
          'contain',
        }.contains(token.text)) {
      (afterSlash ? size : position).add(token);
      continue;
    }
    if (token.isIdent('none')) {
      image.add(token);
      continue;
    }
    _color(token, 'background');
    color.add(token);
  }
  return [
    (
      'background-color',
      color.isEmpty
          ? [const CssToken(CssTokenKind.ident, text: 'transparent')]
          : color,
    ),
    (
      'background-image',
      image.isEmpty
          ? [const CssToken(CssTokenKind.ident, text: 'none')]
          : image,
    ),
    (
      'background-repeat',
      repeat.isEmpty
          ? [const CssToken(CssTokenKind.ident, text: 'repeat')]
          : repeat,
    ),
    (
      'background-position',
      position.isEmpty
          ? [
              const CssToken(CssTokenKind.percent, number: 0),
              const CssToken(CssTokenKind.percent, number: 0),
            ]
          : position,
    ),
    (
      'background-size',
      size.isEmpty ? [const CssToken(CssTokenKind.ident, text: 'auto')] : size,
    ),
  ];
}

Object _parseAuthored(String name, List<CssToken> tokens) {
  Object fail() => throw _Invalid(StyleDiagnosticKind.invalidValue, name);
  if (const {'top', 'right', 'bottom', 'left'}.contains(name)) {
    return _length(_one(tokens, name), name, allowAuto: true);
  }
  if (name.startsWith('min-') ||
      name.endsWith('-width') ||
      name.endsWith('-radius')) {
    return _length(
      _one(tokens, name),
      name,
      allowNegative: false,
      allowPercent: !name.startsWith('border-') || name.endsWith('-radius'),
    );
  }
  if (name.endsWith('-color')) return _color(_one(tokens, name), name);
  if (name.endsWith('-style')) {
    final v = _ident(tokens, name);
    return const {'none', 'solid'}.contains(v) ? v : fail();
  }
  switch (name) {
    case 'position':
      return switch (_ident(tokens, name)) {
        'static' => AuthoredPosition.static,
        'relative' => AuthoredPosition.relative,
        'absolute' => AuthoredPosition.absolute,
        'fixed' => AuthoredPosition.fixed,
        _ => fail(),
      };
    case 'box-sizing':
      return switch (_ident(tokens, name)) {
        'content-box' => AuthoredBoxSizing.contentBox,
        'border-box' => AuthoredBoxSizing.borderBox,
        _ => fail(),
      };
    case 'visibility':
      return switch (_ident(tokens, name)) {
        'visible' => AuthoredVisibility.visible,
        'hidden' => AuthoredVisibility.hidden,
        _ => fail(),
      };
    case 'overflow':
      return switch (_ident(tokens, name)) {
        'visible' => AuthoredOverflow.visible,
        'hidden' => AuthoredOverflow.hidden,
        'clip' => AuthoredOverflow.clip,
        _ => fail(),
      };
    case 'opacity':
      final t = _one(tokens, name);
      return t.kind == CssTokenKind.number && t.number.isFinite
          ? t.number.clamp(0.0, 1.0)
          : fail();
    case 'z-index':
      final t = _one(tokens, name);
      return t.isIdent('auto')
          ? 'auto'
          : t.kind == CssTokenKind.number &&
                t.number.isFinite &&
                t.number == t.number.roundToDouble()
          ? t.number.toInt()
          : fail();
    case 'word-spacing':
      final t = _one(tokens, name);
      return t.isIdent('normal')
          ? const CssLength(0, CssLengthUnit.px)
          : _length(t, name, allowPercent: false);
    case 'background-image':
      final t = _one(tokens, name);
      return t.isIdent('none')
          ? 'none'
          : t.kind == CssTokenKind.uri
          ? t.text
          : fail();
    case 'background-repeat':
      return switch (_ident(tokens, name)) {
        'repeat' => BackgroundRepeat.repeat,
        'repeat-x' => BackgroundRepeat.repeatX,
        'repeat-y' => BackgroundRepeat.repeatY,
        'no-repeat' => BackgroundRepeat.noRepeat,
        _ => fail(),
      };
    case 'background-position':
    case 'transform-origin':
      if (tokens.isEmpty || tokens.length > 2) return fail();
      CssLength at(int i) {
        if (i >= tokens.length) {
          return const CssLength(50, CssLengthUnit.percent);
        }
        final t = tokens[i];
        if (t.isIdent('center')) {
          return const CssLength(50, CssLengthUnit.percent);
        }
        if (t.isIdent('left') || t.isIdent('top')) {
          return const CssLength(0, CssLengthUnit.percent);
        }
        if (t.isIdent('right') || t.isIdent('bottom')) {
          return const CssLength(100, CssLengthUnit.percent);
        }
        return _length(t, name);
      }
      return List<CssLength>.unmodifiable([at(0), at(1)]);
    case 'background-size':
      if (tokens.length == 1 &&
          const {'cover', 'contain'}.contains(tokens.single.text)) {
        return tokens.single.text;
      }
      if (tokens.isEmpty || tokens.length > 2) return fail();
      return List<CssLength>.unmodifiable([
        _length(tokens[0], name, allowAuto: true, allowNegative: false),
        tokens.length == 1
            ? const CssLength.auto()
            : _length(tokens[1], name, allowAuto: true, allowNegative: false),
      ]);
    case 'transform':
      if (tokens.length == 1 && tokens.single.isIdent('none')) {
        return const <AuthoredTransform>[];
      }
      return List<AuthoredTransform>.unmodifiable(
        tokens.map((t) => _transform(t, name)),
      );
  }
  return fail();
}

AuthoredTransform _transform(CssToken token, String name) {
  final args = token.arguments
      .where((t) => t.kind != CssTokenKind.comma)
      .toList();
  Object fail() => throw _Invalid(StyleDiagnosticKind.invalidValue, name);
  if (token.kind != CssTokenKind.function) return fail() as AuthoredTransform;
  final n = token.text;
  if (!const {
    'matrix',
    'translate',
    'translatex',
    'translatey',
    'scale',
    'scalex',
    'scaley',
    'rotate',
    'skew',
    'skewx',
    'skewy',
  }.contains(n)) {
    return fail() as AuthoredTransform;
  }
  final count = n == 'matrix'
      ? 6
      : const {'translate', 'scale', 'skew'}.contains(n)
      ? -1
      : 1;
  if (count < 0 ? args.isEmpty || args.length > 2 : args.length != count) {
    return fail() as AuthoredTransform;
  }
  return AuthoredTransform(
    n,
    args.map<Object>((t) {
      if (n.startsWith('translate')) return _length(t, name);
      if (n.startsWith('skew') || n == 'rotate') {
        if (t.kind == CssTokenKind.number && t.number == 0) return 0.0;
        if (t.kind != CssTokenKind.length ||
            !const {'deg', 'rad', 'grad', 'turn'}.contains(t.unit)) {
          return fail();
        }
        return t.number *
            switch (t.unit) {
              'deg' => math.pi / 180,
              'grad' => math.pi / 200,
              'turn' => math.pi * 2,
              _ => 1.0,
            };
      }
      return t.kind == CssTokenKind.number && t.number.isFinite
          ? t.number
          : fail();
    }).toList(),
  );
}
