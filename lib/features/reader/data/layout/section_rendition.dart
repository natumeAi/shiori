enum RenditionIssueKind { malformed, unsupported }

final class RenditionIssue {
  RenditionIssue({
    required this.kind,
    required this.property,
    required this.reason,
  }) {
    if (property.isEmpty || reason.trim().isEmpty) {
      throw ArgumentError('Rendition issues require a property and reason');
    }
  }
  final RenditionIssueKind kind;
  final String property, reason;
  @override
  bool operator ==(Object other) =>
      other is RenditionIssue &&
      kind == other.kind &&
      property == other.property &&
      reason == other.reason;
  @override
  int get hashCode => Object.hash(kind, property, reason);
}

/// Raw declarations remain available even when an override replaces them.
final class SectionRendition {
  SectionRendition._(
    this.rawPackage,
    this.rawItemref,
    this.effective,
    this.issues,
  );
  final Map<String, String?> rawPackage;
  final List<String> rawItemref;
  final Map<String, String?> effective;
  final List<RenditionIssue> issues;
  bool get isValid => issues.isEmpty;
  bool? get isFixed => switch (effective['layout']) {
    'pre-paginated' => true,
    'reflowable' => false,
    _ => null,
  };
  @override
  bool operator ==(Object other) =>
      other is SectionRendition &&
      _mapsEqual(rawPackage, other.rawPackage) &&
      _mapsEqual(effective, other.effective) &&
      _listsEqual(rawItemref, other.rawItemref) &&
      _listsEqual(issues, other.issues);
  @override
  int get hashCode => Object.hash(
    _mapHash(rawPackage),
    _mapHash(effective),
    Object.hashAll(rawItemref),
    Object.hashAll(issues),
  );
}

const _allowed = {
  'layout': {'reflowable', 'pre-paginated'},
  'orientation': {'auto', 'portrait', 'landscape'},
  'spread': {'auto', 'none', 'landscape', 'both', 'portrait'},
  'pageSpread': {'left', 'right', 'center'},
};

SectionRendition resolveSectionRendition({
  required Map<String, String?> package,
  List<String> itemref = const [],
  String? legacyLayout,
}) {
  final effective = <String, String?>{
    ...package,
    'layout': package['layout'] ?? legacyLayout ?? 'reflowable',
    'orientation': package['orientation'] ?? 'auto',
    'spread': package['spread'] ?? 'auto',
  };
  final issues = <RenditionIssue>[];
  void validate(String property, String value) {
    if (!_allowed[property]!.contains(value)) {
      issues.add(
        RenditionIssue(
          kind: value.trim().isEmpty
              ? RenditionIssueKind.malformed
              : RenditionIssueKind.unsupported,
          property: property,
          reason: 'Invalid $property declaration: $value',
        ),
      );
    }
  }

  for (final property in _allowed.keys) {
    final raw =
        package[property] ?? (property == 'layout' ? legacyLayout : null);
    if (raw != null) validate(property, raw);
    final name = property == 'pageSpread' ? 'page-spread' : property;
    final prefixes = [
      'rendition:$name-',
      if (property == 'pageSpread') '$name-',
    ];
    final overrides = <String>[];
    for (final token in itemref) {
      if (token == 'rendition:$name' ||
          (property == 'pageSpread' && token == name)) {
        overrides.add('');
      }
      for (final prefix in prefixes) {
        if (token.startsWith(prefix)) {
          overrides.add(token.substring(prefix.length));
        }
      }
    }
    if (overrides.toSet().length > 1) {
      issues.add(
        RenditionIssue(
          kind: RenditionIssueKind.malformed,
          property: property,
          reason: 'Conflicting itemref $property overrides',
        ),
      );
    }
    for (final value in overrides) {
      validate(property, value);
    }
    if (overrides.isNotEmpty) effective[property] = overrides.last;
  }
  return SectionRendition._(
    Map.unmodifiable(package),
    List.unmodifiable(itemref),
    Map.unmodifiable(effective),
    List.unmodifiable(issues),
  );
}

bool _mapsEqual(Map<String, String?> a, Map<String, String?> b) =>
    a.length == b.length &&
    a.keys.every((key) => b.containsKey(key) && a[key] == b[key]);
bool _listsEqual<T>(List<T> a, List<T> b) =>
    a.length == b.length &&
    Iterable<int>.generate(a.length).every((i) => a[i] == b[i]);
int _mapHash(Map<String, String?> map) {
  final keys = map.keys.toList()..sort();
  return Object.hashAll(keys.map((key) => Object.hash(key, map[key])));
}
