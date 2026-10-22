import 'package:shiori/features/reader/engine/style/reader_settings.dart';

/// Bumped when layout or pagination output changes for the same inputs.
const layoutEngineVersion = 1;

/// Everything that makes one pagination of a section reusable. Theme-only
/// changes are deliberately absent: they repaint without repaginating.
final class LayoutIdentity {
  const LayoutIdentity({
    required this.contentId,
    required this.sectionIndex,
    required this.viewportWidth,
    required this.viewportHeight,
    required this.devicePixelRatio,
    required this.settings,
    required this.fontSignature,
    this.styleVersion = 'style-1',
    this.generation = 0,
  });

  /// Digest of the book or fixture content.
  final String contentId;
  final int sectionIndex;
  final double viewportWidth;
  final double viewportHeight;
  final double devicePixelRatio;
  final ReaderSettings settings;

  /// Fonts that were loaded for the section, in a stable order.
  final String fontSignature;
  final String styleVersion;

  /// Caller-owned counter, bumped on every invalidation.
  final int generation;

  String get key => [
    'L$layoutEngineVersion',
    styleVersion,
    contentId,
    sectionIndex,
    viewportWidth,
    viewportHeight,
    devicePixelRatio,
    settings.fontSize,
    settings.fontFamilyId,
    settings.horizontalMargin,
    settings.verticalMargin,
    settings.lineHeight,
    settings.letterSpacing,
    fontSignature,
    generation,
  ].join('|');

  @override
  bool operator ==(Object other) => other is LayoutIdentity && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'LayoutIdentity($key)';
}
