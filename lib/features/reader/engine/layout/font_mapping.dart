/// Mapping from CSS / reader font families to families available on iOS.
///
/// The reference stacks (`useReaderSettings.ts:45`) name macOS/Windows fonts.
/// On iOS only some exist, and Flutter has no API to ask which family really
/// rendered, so the mapping below is explicit and the chosen chain is
/// recorded with each layout. Families marked unverified have not been
/// confirmed on a device yet; the CJK glyph fallback of the system font
/// covers the case where a mapped family is missing.
library;

/// Result of resolving a CSS family list.
final class ResolvedFontFamilies {
  const ResolvedFontFamilies({
    required this.primary,
    required this.fallback,
    required this.chain,
    required this.notes,
  });

  /// First family to request; null means the platform default font.
  final String? primary;
  final List<String> fallback;

  /// Every family tried in order, the platform default as `(system)`.
  final List<String> chain;

  /// `css-name -> mapped-name` decisions, for the report.
  final List<String> notes;

  @override
  bool operator ==(Object other) =>
      other is ResolvedFontFamilies &&
      other.primary == primary &&
      _listEquals(other.fallback, fallback);

  @override
  int get hashCode => Object.hash(primary, Object.hashAll(fallback));
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// The marker for the platform default font in a mapping.
const systemFamily = '(system)';

/// CSS family (lowercase) to iOS family, or [systemFamily].
const iosFamilyMapping = <String, String>{
  '-apple-system': systemFamily,
  'blinkmacsystemfont': systemFamily,
  'system-ui': systemFamily,
  'sf pro text': systemFamily,
  'sf pro': systemFamily,
  'segoe ui': systemFamily,
  'sans-serif': systemFamily,
  'helvetica neue': systemFamily,
  'arial': systemFamily,
  'pingfang sc': 'PingFang SC',
  'pingfang tc': 'PingFang TC',
  'pingfang hk': 'PingFang HK',
  // Reference stacks reach PingFang SC next, so use it directly.
  'microsoft yahei': 'PingFang SC',
  'microsoft jhenghei': 'PingFang TC',
  'heiti sc': 'PingFang SC',
  'noto sans cjk sc': 'PingFang SC',
  'songti sc': 'Songti SC',
  'simsun': 'Songti SC',
  'noto serif cjk sc': 'Songti SC',
  'kaiti sc': 'Kaiti SC',
  'kaiti': 'Kaiti SC',
  'serif': 'Times New Roman',
  'times new roman': 'Times New Roman',
  'georgia': 'Georgia',
  'monospace': 'Courier New',
  'courier new': 'Courier New',
};

String _unquote(String family) {
  var value = family.trim();
  if (value.length >= 2 &&
      (value.startsWith('"') && value.endsWith('"') ||
          value.startsWith("'") && value.endsWith("'"))) {
    value = value.substring(1, value.length - 1);
  }
  return value.trim();
}

/// Resolves [cssFamilies] in order. [embedded] maps a lowercase CSS family
/// to the alias it was registered under with the engine (`@font-face`).
/// Unknown families pass through unchanged, because the engine ignores a
/// family it cannot find and moves to the next one.
ResolvedFontFamilies resolveFontFamilies(
  List<String> cssFamilies, {
  Map<String, String> embedded = const {},
}) {
  final chain = <String>[];
  final notes = <String>[];
  for (final raw in cssFamilies) {
    final family = _unquote(raw);
    if (family.isEmpty) continue;
    final key = family.toLowerCase();
    final alias = embedded[key];
    final mapped = alias ?? iosFamilyMapping[key] ?? family;
    if (mapped != family) notes.add('$family -> $mapped');
    if (!chain.contains(mapped)) chain.add(mapped);
  }
  if (chain.isEmpty) chain.add(systemFamily);
  final real = [
    for (final family in chain)
      if (family != systemFamily) family,
  ];
  // The system font is requested by omitting a family; when it is first in
  // the chain it is the primary, otherwise it is simply the engine default
  // the fallback list ends in.
  final primary = chain.first == systemFamily ? null : chain.first;
  final fallback = [
    for (final family in real)
      if (family != primary) family,
  ];
  return ResolvedFontFamilies(
    primary: primary,
    fallback: fallback,
    chain: chain,
    notes: notes,
  );
}
