/// Reader appearance settings with the reference domain.
///
/// Ported from lan-reader `client/src/hooks/useReaderSettings.ts` at
/// a4bda23 (constants at :21–:117, page geometry at :185–:194 and
/// `foliateEngine.ts:205`). Pure Dart so it can cross isolates.
library;

final class ReaderSettings {
  const ReaderSettings({
    this.fontSize = defaultFontSize,
    this.fontFamilyId = defaultFontFamilyId,
    this.horizontalMargin = defaultHorizontalMargin,
    this.verticalMargin = defaultVerticalMargin,
    this.lineHeight = defaultLineHeight,
    this.letterSpacing = defaultLetterSpacing,
    this.themeId = defaultThemeId,
  });

  static const defaultFontSize = 18.0;
  static const fontSizeMin = 14.0;
  static const fontSizeMax = 40.0;
  static const fontSizeStep = 2.0;

  static const baseHorizontalMargin = 48.0;
  static const defaultHorizontalMargin = 0.0;
  static const horizontalMarginMin = 0.0;
  static const horizontalMarginMax = 48.0;
  static const horizontalMarginStep = 6.0;

  static const baseVerticalMargin = 60.0;
  static const defaultVerticalMargin = 0.0;
  static const verticalMarginMin = 0.0;
  static const verticalMarginMax = 48.0;
  static const verticalMarginStep = 6.0;

  static const defaultLineHeight = 1.6;
  static const lineHeightMin = 1.3;
  static const lineHeightMax = 2.0;
  static const lineHeightStep = 0.1;

  /// In `em` of the effective font size.
  static const defaultLetterSpacing = 0.0;
  static const letterSpacingMin = 0.0;
  static const letterSpacingMax = 0.12;
  static const letterSpacingStep = 0.02;

  static const defaultFontFamilyId = 'system';
  static const defaultThemeId = 'light';

  /// CSS px.
  final double fontSize;
  final String fontFamilyId;

  /// Added to [baseHorizontalMargin]; CSS px.
  final double horizontalMargin;

  /// Added to [baseVerticalMargin]; CSS px.
  final double verticalMargin;

  /// Unitless multiplier.
  final double lineHeight;

  /// In `em`.
  final double letterSpacing;
  final String themeId;

  /// Foliate's one-column `gap` (`foliateEngine.ts:212`): the smaller of
  /// 40% of the viewport width and the effective horizontal margin. Verify
  /// how the paginator splits it into side insets before relying on it.
  double pageGap(double viewportWidth) {
    final effective = baseHorizontalMargin + horizontalMargin;
    final percent = effective / (viewportWidth < 1 ? 1 : viewportWidth) * 100;
    return (percent < 40 ? percent : 40) / 100 * viewportWidth;
  }

  /// Foliate's `margin` attribute (`foliateEngine.ts:213`), CSS px.
  double get pageMargin => baseVerticalMargin + verticalMargin;

  /// `getEffectiveHorizontalMargin`: base margin plus the clamped setting.
  double get effectiveHorizontalMargin =>
      baseHorizontalMargin + clampHorizontalMargin(horizontalMargin);

  /// `getEffectiveVerticalMargin`.
  double get effectiveVerticalMargin =>
      baseVerticalMargin + clampVerticalMargin(verticalMargin);

  /// The font option for [fontFamilyId] (the first when unknown), like
  /// `getReaderFontOption`.
  ReaderFontOption get fontOption => readerFontOptions.firstWhere(
    (option) => option.id == fontFamilyId,
    orElse: () => readerFontOptions.first,
  );

  /// The theme for [themeId] (the first when unknown), like `getReaderTheme`.
  ReaderTheme get theme => readerThemes.firstWhere(
    (option) => option.id == themeId,
    orElse: () => readerThemes.first,
  );

  /// `sanitizeReaderSettings` for an arbitrary decoded JSON value. A value
  /// that is not a JSON object yields the defaults.
  factory ReaderSettings.sanitize(Object? value) {
    final map = value is Map ? value : const <Object?, Object?>{};
    double number(String key) =>
        map.containsKey(key) ? _jsNumber(map[key]) : double.nan;
    return ReaderSettings(
      fontSize: clampFontSize(number('fontSize')),
      fontFamilyId: sanitizeFontFamilyId(map['fontFamilyId']),
      horizontalMargin: clampHorizontalMargin(number('horizontalMargin')),
      verticalMargin: clampVerticalMargin(number('verticalMargin')),
      lineHeight: clampLineHeight(number('lineHeight')),
      letterSpacing: clampLetterSpacing(number('letterSpacing')),
      themeId: sanitizeThemeId(map['themeId']),
    );
  }

  /// This value with every field sanitized.
  ReaderSettings sanitized() => ReaderSettings(
    fontSize: clampFontSize(fontSize),
    fontFamilyId: sanitizeFontFamilyId(fontFamilyId),
    horizontalMargin: clampHorizontalMargin(horizontalMargin),
    verticalMargin: clampVerticalMargin(verticalMargin),
    lineHeight: clampLineHeight(lineHeight),
    letterSpacing: clampLetterSpacing(letterSpacing),
    themeId: sanitizeThemeId(themeId),
  );

  /// JSON object with the reference keys (sanitized values).
  Map<String, Object?> toJson() {
    final clean = sanitized();
    return {
      'fontSize': clean.fontSize,
      'fontFamilyId': clean.fontFamilyId,
      'horizontalMargin': clean.horizontalMargin,
      'verticalMargin': clean.verticalMargin,
      'lineHeight': clean.lineHeight,
      'letterSpacing': clean.letterSpacing,
      'themeId': clean.themeId,
    };
  }

  /// `clampNumber`: NaN/infinite input (after JavaScript `Number()`
  /// coercion) yields [fallback]; otherwise clamped to [min, max].
  static double clampNumber(
    Object? value,
    double min,
    double max,
    double fallback,
  ) {
    final number = _jsNumber(value);
    if (!number.isFinite) return fallback;
    return number < min ? min : (number > max ? max : number);
  }

  /// `clampFontSize`: clamped, then snapped to the 2 px step grid.
  static double clampFontSize(Object? value) {
    final clamped = clampNumber(
      value,
      fontSizeMin,
      fontSizeMax,
      defaultFontSize,
    );
    final step = ((clamped - fontSizeMin) / fontSizeStep).round();
    return fontSizeMin + step * fontSizeStep;
  }

  static double clampHorizontalMargin(Object? value) => clampNumber(
    value,
    horizontalMarginMin,
    horizontalMarginMax,
    defaultHorizontalMargin,
  );

  static double clampVerticalMargin(Object? value) => clampNumber(
    value,
    verticalMarginMin,
    verticalMarginMax,
    defaultVerticalMargin,
  );

  /// `Number(clampNumber(...).toFixed(1))`.
  static double clampLineHeight(Object? value) => double.parse(
    clampNumber(
      value,
      lineHeightMin,
      lineHeightMax,
      defaultLineHeight,
    ).toStringAsFixed(1),
  );

  /// `Number(clampNumber(...).toFixed(2))`.
  static double clampLetterSpacing(Object? value) => double.parse(
    clampNumber(
      value,
      letterSpacingMin,
      letterSpacingMax,
      defaultLetterSpacing,
    ).toStringAsFixed(2),
  );

  static String sanitizeFontFamilyId(Object? value) =>
      value is String && readerFontOptions.any((option) => option.id == value)
      ? value
      : defaultFontFamilyId;

  static String sanitizeThemeId(Object? value) =>
      value is String && readerThemes.any((option) => option.id == value)
      ? value
      : defaultThemeId;

  ReaderSettings copyWith({
    double? fontSize,
    String? fontFamilyId,
    double? horizontalMargin,
    double? verticalMargin,
    double? lineHeight,
    double? letterSpacing,
    String? themeId,
  }) => ReaderSettings(
    fontSize: fontSize ?? this.fontSize,
    fontFamilyId: fontFamilyId ?? this.fontFamilyId,
    horizontalMargin: horizontalMargin ?? this.horizontalMargin,
    verticalMargin: verticalMargin ?? this.verticalMargin,
    lineHeight: lineHeight ?? this.lineHeight,
    letterSpacing: letterSpacing ?? this.letterSpacing,
    themeId: themeId ?? this.themeId,
  );

  @override
  bool operator ==(Object other) =>
      other is ReaderSettings &&
      other.fontSize == fontSize &&
      other.fontFamilyId == fontFamilyId &&
      other.horizontalMargin == horizontalMargin &&
      other.verticalMargin == verticalMargin &&
      other.lineHeight == lineHeight &&
      other.letterSpacing == letterSpacing &&
      other.themeId == themeId;

  @override
  int get hashCode => Object.hash(
    fontSize,
    fontFamilyId,
    horizontalMargin,
    verticalMargin,
    lineHeight,
    letterSpacing,
    themeId,
  );
}

/// One reader font choice. [cssFamilies] is the reference CSS list in order;
/// which family actually renders on the device is a layout-time fact.
final class ReaderFontOption {
  const ReaderFontOption(this.id, this.label, this.cssFamilies);

  final String id;
  final String label;
  final List<String> cssFamilies;
}

/// Reference `FONT_FAMILY_OPTIONS` (`useReaderSettings.ts:45`).
const readerFontOptions = <ReaderFontOption>[
  ReaderFontOption('system', '默认', [
    '-apple-system',
    'BlinkMacSystemFont',
    'SF Pro Text',
    'Segoe UI',
    'sans-serif',
  ]),
  ReaderFontOption('pingfang', '苹方', [
    'PingFang SC',
    'PingFang TC',
    'PingFang HK',
    '-apple-system',
    'BlinkMacSystemFont',
    'sans-serif',
  ]),
  ReaderFontOption('yahei', '微软雅黑', [
    'Microsoft YaHei',
    'Microsoft JhengHei',
    'PingFang SC',
    'sans-serif',
  ]),
  ReaderFontOption('sans', '黑体', [
    'Heiti SC',
    'Microsoft YaHei',
    'Noto Sans CJK SC',
    'sans-serif',
  ]),
  ReaderFontOption('serif', '宋体', [
    'Songti SC',
    'SimSun',
    'Noto Serif CJK SC',
    'serif',
  ]),
  ReaderFontOption('kai', '楷体', ['Kaiti SC', 'KaiTi', 'serif']),
];

/// One reader theme; colors are 0xAARRGGBB.
final class ReaderTheme {
  const ReaderTheme({
    required this.id,
    required this.label,
    required this.text,
    required this.muted,
    required this.background,
    required this.selection,
  });

  final String id;
  final String label;
  final int text;
  final int muted;
  final int background;
  final int selection;
}

/// Reference `READER_THEME_OPTIONS` (`useReaderSettings.ts:76`).
const readerThemes = <ReaderTheme>[
  ReaderTheme(
    id: 'light',
    label: '白色',
    text: 0xFF1D1D1F,
    muted: 0xFF6E6E73,
    background: 0xFFFFFFFF,
    selection: 0x38007AFF,
  ),
  ReaderTheme(
    id: 'warm',
    label: '暖色',
    text: 0xFF2F271D,
    muted: 0xFF806F5A,
    background: 0xFFF4ECD9,
    selection: 0x3DB47A30,
  ),
  ReaderTheme(
    id: 'green',
    label: '护眼',
    text: 0xFF1F2C22,
    muted: 0xFF617060,
    background: 0xFFDFEADB,
    selection: 0x38347848,
  ),
  ReaderTheme(
    id: 'dark',
    label: '夜间',
    text: 0xFFEEEEEE,
    muted: 0xFFA6A6A6,
    background: 0xFF171717,
    selection: 0x4D5AA0FF,
  ),
];

/// JavaScript `Number(value)` for decoded JSON values; NaN when not a number.
double _jsNumber(Object? value) => switch (value) {
  null => 0,
  final num number => number.toDouble(),
  final bool flag => flag ? 1 : 0,
  final String text =>
    text.trim().isEmpty ? 0 : (double.tryParse(text.trim()) ?? double.nan),
  _ => double.nan,
};
