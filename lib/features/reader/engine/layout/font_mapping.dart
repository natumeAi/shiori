/// Mapping from CSS / reader font families to families available on iOS.
///
/// The reference stacks (`useReaderSettings.ts:45`) name macOS/Windows fonts.
/// On iOS only some exist, and Flutter has no API to ask which family really
/// rendered, so the mapping below is explicit and the chosen chain is
/// recorded with each layout. Families marked unverified have not been
/// confirmed on a device yet; the CJK glyph fallback of the system font
/// covers the case where a mapped family is missing.
library;

import 'package:shiori/features/reader/engine/style/style_resolver.dart';
import 'package:shiori/features/reader/engine/style/computed_style.dart';

/// A descriptor and its own admitted native alias, never a family-wide alias.
typedef AdmittedFontFace = ({StyleFontFace face, String alias});

/// CSS style matching precedes weight matching within each ordered family.
ResolvedFontFamilies resolveFontFaces(
  List<String> families, {
  required int weight,
  required StyleFontStyle style,
  required List<AdmittedFontFace> faces,
}) {
  final selected = <String, String>{};
  for (final raw in families) {
    final key = _unquote(raw).toLowerCase();
    var candidates = faces
        .where((entry) => entry.face.family.toLowerCase() == key)
        .toList();
    if (candidates.isEmpty) continue;
    final matchingStyle = candidates
        .where((e) => e.face.style == style)
        .toList();
    if (matchingStyle.isNotEmpty) candidates = matchingStyle;
    int rank(int value) {
      if (weight < 400) return value <= weight ? weight - value : 2000 + value;
      if (weight > 500) return value >= weight ? value - weight : 2000 - value;
      if (value >= weight && value <= 500) return value - weight;
      return value < weight ? 2000 - value : 4000 + value;
    }

    var best = candidates.first;
    for (final candidate in candidates.skip(1)) {
      // A later equally matching @font-face wins in source order.
      if (rank(candidate.face.weight) <= rank(best.face.weight)) {
        best = candidate;
      }
    }
    selected[key] = best.alias;
  }
  return resolveFontFamilies(families, embedded: selected);
}

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
