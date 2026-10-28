import 'package:shiori/features/reader/data/layout/authored_dimension_resolver.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/layout/section_rendition.dart';
import 'package:shiori/features/reader/data/layout/section_source_facts.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_source_lease.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_svg_viewport.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/style/computed_style.dart';
import 'package:shiori/features/reader/engine/support/section_capability.dart';

/// Planning borrows inputs and performs no native allocation or I/O.
final class FixedPreparationPlan {
  FixedPreparationPlan._(
    this.source,
    this.dimensions,
    this.capability,
    Map<SceneResource, int> resources,
    this.sourceDepth,
    this.layerDepth,
  ) : resources = Map.unmodifiable(resources);
  final FixedSourceLease source;
  final DimensionResolution dimensions;
  final SectionCapability capability;
  final Map<SceneResource, int> resources;
  final int sourceDepth, layerDepth;
  int get referenceDepth => 0;

  /// Per-source recording ceiling: eight real sources share the existing
  /// 16 MiB picture owner. Reject actual native payload above this ceiling;
  /// never guess bytes per native command. Opaque allocator/RSS is separate.
  int get pictureBytes =>
      (16 * 1024 * 1024) ~/ SceneResourceBudget.maxSourcePages;
  int get decodedImageBytes => source.images.values.fold(
    0,
    (sum, image) => sum + image.width * image.height * 4,
  );

  static FixedPreparationPlan inspect(FixedSourceLease source) {
    ReaderWorkGuard.check(ReaderWork.surfacePreparation);
    source.requireLive();
    final document = source.document;
    final facts = extractSectionSourceFacts(document);
    var dimensions = resolveAuthoredDimensions(
      source: facts,
      packageRendition: source.rendition.effective,
    );
    if (dimensions is ResolvedDimensions) {
      for (final svg in facts.svgDimensions) {
        final viewport = FixedSvgViewport.resolve(svg);
        if (viewport.dimensions is! ResolvedDimensions) {
          dimensions = viewport.dimensions;
          break;
        }
      }
    }
    final section = source.page.sectionIndex;
    final issues = source.rendition.issues;
    SectionCapability capability;
    if (issues.isNotEmpty) {
      final constructs = [
        for (final issue in issues)
          OffendingConstruct(
            kind: CapabilityConstructKind.layout,
            identifier: 'rendition:${issue.property}',
          ),
      ];
      capability = issues.any((i) => i.kind == RenditionIssueKind.malformed)
          ? MalformedSectionCapability(
              sectionIndex: section,
              reason: 'Malformed rendition metadata',
              constructs: constructs,
            )
          : UnsupportedSectionCapability(
              sectionIndex: section,
              reason: 'Unsupported rendition metadata',
              constructs: constructs,
            );
    } else if (source.rendition.isFixed != true || !source.styles.fixedLayout) {
      capability = UnsupportedSectionCapability(
        sectionIndex: section,
        reason:
            'Fixed preparation requires validated fixed styles and rendition',
        constructs: [
          OffendingConstruct(
            kind: CapabilityConstructKind.layout,
            identifier: 'fixed-profile-required',
          ),
        ],
      );
    } else if (dimensions is! ResolvedDimensions) {
      final constructs = [
        OffendingConstruct(
          kind: CapabilityConstructKind.dimensions,
          identifier: 'authored-viewport',
        ),
      ];
      capability = dimensions is MalformedDimensions
          ? MalformedSectionCapability(
              sectionIndex: section,
              reason: dimensions.reason,
              constructs: constructs,
            )
          : UnsupportedSectionCapability(
              sectionIndex: section,
              reason: (dimensions as UnsupportedDimensions).reason,
              constructs: constructs,
            );
    } else {
      capability = CompleteSectionCapability(
        sectionIndex: section,
        reason: 'Fixed inputs planned; scene completeness awaits preparation',
      );
    }
    var depth = 0, layers = 0, textNodes = 0, decorations = 0, units = 0;
    var shiftedInline = false;
    var operations = 0;
    final depths = <int, int>{}, layerDepths = <int, int>{};
    for (final node in document.nodes) {
      final d = (depths[node.parentIndex] ?? 0) + 1;
      depths[node.index] = d;
      if (d > depth) depth = d;
      units += node.text?.length ?? 0;
      if (node.isCharacterData) textNodes++;
      final style = source.styles.styleOf(node.index);
      if (style != null && style.verticalAlign != StyleVerticalAlign.baseline) {
        shiftedInline = true;
      }
      final a = style?.authored;
      final ld =
          (layerDepths[node.parentIndex] ?? 0) +
          (!node.isCharacterData && a != null && a.opacity < 1 ? 1 : 0);
      layerDepths[node.index] = ld;
      if (ld > layers) layers = ld;
      if (node.isCharacterData || style == null) continue;
      if (style.backgroundColor != null ||
          a!.backgroundImage != null ||
          const [
            'top',
            'right',
            'bottom',
            'left',
          ].any((e) => a.borderStyle(e) != 'none')) {
        decorations++;
      }
      operations += a!.backgroundImage == null ? 32 : 16416;
    }
    final pixelCap =
        SceneResourceBudget.provisionalLimits[SceneResource.layerPixels]!;
    var pixels = 0;
    if (dimensions is ResolvedDimensions) {
      final w = dimensions.size.width.ceil(), h = dimensions.size.height.ceil();
      if (h <= 0 || w <= 0 || w > pixelCap ~/ h) {
        capability = ResourceSectionCapability(
          sectionIndex: section,
          reason: 'Authored page exceeds layer pixel admission',
          constructs: [
            OffendingConstruct(
              kind: CapabilityConstructKind.resource,
              identifier: 'layerPixels',
            ),
          ],
        );
      } else {
        pixels = w * h;
      }
    }
    final alphaMaps =
        textNodes +
        decorations +
        document.nodes
            .where((n) => n.localName == 'br' || n.localName == 'svg')
            .length;
    final resources = <SceneResource, int>{
      SceneResource.sourceBytes: source.retainedSourceBytes,
      SceneResource.sourceNodes: document.nodes.length,
      SceneResource.textCodeUnits:
          units + (shiftedInline ? units * units + 1 : 0),
      // Shifted inline paint retains the original shaping Paragraph plus at
      // most one paint group per source unit, and one temporary font probe.
      SceneResource.paragraphs:
          document.nodes.length + (shiftedInline ? units + 1 : 0),
      SceneResource.vectorBytes:
          units * 512 + document.nodes.length * 512 + pixels * alphaMaps * 2,
      SceneResource.vectorOperations: operations + units * 8,
      SceneResource.references: source.images.length,
      SceneResource.gradientStops: 0,
      SceneResource.layerPixels: pixels * (layers + 2),
      SceneResource.layerBytes: pixels * (layers + 2) * 4,
    };
    return FixedPreparationPlan._(
      source,
      dimensions,
      capability,
      resources,
      depth,
      layers + 1,
    );
  }
}
