/// What the style resolver ignored or approximated. Diagnostics never carry
/// book prose: details are CSS property, at-rule, pseudo-class or unit names.
library;

enum StyleDiagnosticKind {
  /// The CSS parser rejected a rule or declaration.
  parseError,

  /// An at-rule other than `@font-face`, `@import`, `@charset` and
  /// supported `@media` blocks.
  unsupportedAtRule,

  /// A selector construct outside the supported subset; the selector is
  /// dropped and never matches.
  unsupportedSelector,

  /// A property outside the style matrix; the declaration is ignored.
  unsupportedProperty,

  /// A supported property with a value that is invalid or unsupported.
  invalidValue,

  /// A unit that cannot be resolved (for example `vw`, `ch`, `calc()`).
  unsupportedUnit,

  /// A value mapped to a nearby supported one (for example
  /// `display: inline-block` as `inline`).
  approximatedValue,

  /// A linked or imported stylesheet that is missing from the archive.
  stylesheetNotFound,

  /// A linked or imported stylesheet that is not read (external URL,
  /// non-screen media, import depth).
  stylesheetSkipped,
}

/// One aggregated diagnostic: how often [kind]/[detail] occurred.
final class StyleDiagnostic {
  const StyleDiagnostic(this.kind, this.detail, this.count);

  final StyleDiagnosticKind kind;
  final String detail;
  final int count;

  @override
  String toString() => '${kind.name}:$detail x$count';
}

/// Collects diagnostics, aggregating identical entries.
final class StyleDiagnosticSink {
  final Map<(StyleDiagnosticKind, String), int> _counts = {};

  void add(StyleDiagnosticKind kind, String detail, [int count = 1]) {
    final key = (kind, detail);
    _counts[key] = (_counts[key] ?? 0) + count;
  }

  /// Aggregated entries ordered by kind then detail.
  List<StyleDiagnostic> get diagnostics {
    final entries = [
      for (final entry in _counts.entries)
        StyleDiagnostic(entry.key.$1, entry.key.$2, entry.value),
    ];
    entries.sort((a, b) {
      final byKind = a.kind.index.compareTo(b.kind.index);
      return byKind != 0 ? byKind : a.detail.compareTo(b.detail);
    });
    return List.unmodifiable(entries);
  }
}
