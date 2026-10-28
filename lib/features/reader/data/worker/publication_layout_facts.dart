import 'package:shiori/features/reader/data/layout/section_rendition.dart';

/// Import facts, independent of the renderer's capability verdict.
enum PublicationLayoutMode { reflowable, fixed }

enum SectionInspection { notInspected, inspected }

enum SectionDirectionIssue { rtlProgression, rtlDirection, verticalWritingMode }

final class PublicationLayoutFacts {
  PublicationLayoutFacts({
    required this.pageProgressionDirection,
    required this.primaryLanguage,
    required Map<String, String?> packageRendition,
    required List<SectionLayoutFacts> sections,
  }) : packageRendition = Map.unmodifiable(packageRendition),
       sections = List.unmodifiable(sections);

  final String? pageProgressionDirection;
  final String? primaryLanguage;
  final Map<String, String?> packageRendition;
  final List<SectionLayoutFacts> sections;
}

final class SectionLayoutFacts {
  SectionLayoutFacts({
    required this.sectionIndex,
    required this.spineIndex,
    required this.mode,
    required List<String> itemrefProperties,
    required Map<String, String?> rendition,
    this.source,
    this.style,
    this.renditionResolution,
  }) : itemrefProperties = List.unmodifiable(itemrefProperties),
       rendition = Map.unmodifiable(rendition);

  /// Index into the filtered publication sections, and original OPF slot.
  final int sectionIndex;
  final int spineIndex;
  final PublicationLayoutMode mode;
  final List<String> itemrefProperties;

  /// Package values after layout/orientation/spread/page-spread overrides.
  /// Original package declarations and raw itemref tokens remain available.
  final Map<String, String?> rendition;
  final SectionSourceFacts? source;
  final SectionStyleFacts? style;
  final SectionRendition? renditionResolution;

  /// Null means metadata has not been validated or has a typed issue. The
  /// legacy mode remains an import hint, never a renderer acceptance verdict.
  PublicationLayoutMode? get resolvedMode {
    final value = renditionResolution;
    if (value == null || !value.isValid) return null;
    return value.isFixed == true
        ? PublicationLayoutMode.fixed
        : PublicationLayoutMode.reflowable;
  }

  Set<SectionDirectionIssue> directionIssues({
    String? pageProgressionDirection,
  }) => Set.unmodifiable({
    if (pageProgressionDirection == 'rtl') SectionDirectionIssue.rtlProgression,
    if (style?.rootDirection == 'rtl' ||
        style?.bodyDirection == 'rtl' ||
        style?.declaredRootDirection == 'rtl' ||
        style?.declaredBodyDirection == 'rtl')
      SectionDirectionIssue.rtlDirection,
    if (style?.writingModes.any((mode) => mode.startsWith('vertical-')) ??
        false)
      SectionDirectionIssue.verticalWritingMode,
  });

  SectionInspection get inspection => style == null
      ? SectionInspection.notInspected
      : SectionInspection.inspected;
}

final class SectionStyleFacts {
  SectionStyleFacts({
    required this.rootWritingMode,
    required this.bodyWritingMode,
    required Set<String> writingModes,
    required this.rootDirection,
    required this.bodyDirection,
    required this.declaredRootDirection,
    required this.declaredBodyDirection,
    required this.rtlRunCount,
  }) : writingModes = Set.unmodifiable(writingModes);

  final String? rootWritingMode;
  final String? bodyWritingMode;
  final Set<String> writingModes;
  final String? rootDirection;
  final String? bodyDirection;
  final String? declaredRootDirection;
  final String? declaredBodyDirection;

  /// Visible non-root/body elements with computed RTL direction, like S2's
  /// rtlBlockCount. This is a style fact, not Unicode bidi segmentation.
  final int rtlRunCount;
}

final class SectionSourceFacts {
  SectionSourceFacts({
    required List<String> viewports,
    required List<String> sourceViewports,
    required List<SvgSourceDimensions> svgDimensions,
    this.rootSvgNodeIndex,
  }) : viewports = List.unmodifiable(viewports),
       sourceViewports = List.unmodifiable(sourceViewports),
       svgDimensions = List.unmodifiable(svgDimensions);

  final List<String> viewports;
  final List<String> sourceViewports;
  final List<SvgSourceDimensions> svgDimensions;
  final int? rootSvgNodeIndex;
}

final class SvgSourceDimensions {
  const SvgSourceDimensions({
    required this.nodeIndex,
    required this.width,
    required this.height,
    required this.viewBox,
    this.preserveAspectRatio,
  });
  final int nodeIndex;
  final String? width;
  final String? height;
  final String? viewBox;
  final String? preserveAspectRatio;
}
