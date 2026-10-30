import 'dart:math' as math;

export 'fixed_preparation_scale.dart';

import 'package:shiori/features/reader/data/geometry/paint_geometry.dart';

import 'package:shiori/features/reader/data/layout/authored_dimension_resolver.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/layout/section_rendition.dart';
import 'package:shiori/features/reader/data/layout/section_source_facts.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_source_lease.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_preparation_scale.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_scene.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_scene_svg_sizing.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_svg_viewport.dart';
import 'package:shiori/features/reader/engine/fixed/svg/svg_graphics.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/layout/layout_model.dart'
    show atomicElementNames;
import 'package:shiori/features/reader/engine/style/computed_style.dart';
import 'package:shiori/features/reader/engine/style/css_style_resolver.dart';
import 'package:shiori/features/reader/engine/style/css_stylesheet.dart';
import 'package:shiori/features/reader/engine/style/style_diagnostic.dart';
import 'package:shiori/features/reader/engine/support/section_capability.dart';

/// Planning borrows inputs and performs no native allocation or I/O.
final class FixedPreparationPlan {
  FixedPreparationPlan._(
    this.source,
    this.dimensions,
    this.capability,
    Map<SceneResource, int> resources,
    this.sourceDepth,
    this.referenceDepth,
    this.layerDepth,
    this.svgPlans,
    this.svgFeatureHost,
    this.evidencePixels,
    this.scale,
    this.retainedEvidenceBytes,
  ) : resources = Map.unmodifiable(resources);
  final FixedSourceLease source;
  final DimensionResolution dimensions;
  final SectionCapability capability;
  final Map<SceneResource, int> resources;
  final int sourceDepth, referenceDepth, layerDepth;
  final SvgFeatureHost svgFeatureHost;
  final int evidencePixels;
  final FixedPreparationScale scale;

  /// Safe predecode upper bound of the retained alpha footprints inside
  /// resources[vectorBytes] (XHTML maps, SVG coverage maps, filter outputs).
  /// Exact reconciliation after publication may release only the excess of this
  /// bound over the bytes actually stored; it is never lowered before then.
  final int retainedEvidenceBytes;

  /// Filter inputs remain authored, just like their unchanged DAG caches.
  late final Set<String> authoredImagePaths = Set.unmodifiable({
    for (final svg in svgPlans) ...svg.authoredImagePaths,
    for (final svg in svgPlans)
      for (final node in svg.authoredImageNodes)
        if (source.styles.styleOf(node)?.authored.backgroundImage
            case final String path)
          fixedCssImageKey(source.document, path),
  });
  ({int width, int height}) imageTarget(String path) {
    final image = source.images[path]!;
    return authoredImagePaths.contains(path)
        ? (width: image.width, height: image.height)
        : scale.imageTarget(image.width, image.height);
  }

  /// Inline SVG subtrees inspected before any font/native allocation.
  final List<SvgGraphicsPlan> svgPlans;

  /// Per-source recording ceiling: eight real sources share the existing
  /// 16 MiB picture owner. Reject actual native payload above this ceiling;
  /// never guess bytes per native command. Opaque allocator/RSS is separate.
  int get pictureBytes =>
      (16 * 1024 * 1024) ~/ SceneResourceBudget.maxSourcePages;
  int get decodedImageBytes => source.images.entries.fold(0, (sum, entry) {
    final target = imageTarget(entry.key), image = entry.value;
    final display = target.width * target.height * 4;
    // Opacity must be proved before using a smaller decode for evidence.
    return sum +
        display +
        (target.width == image.width && target.height == image.height
            ? 0
            : image.width * image.height * 4);
  });

  static FixedPreparationPlan inspect(
    FixedSourceLease source, {
    SvgFeatureHost svgFeatureHost = const SvgFeatureHost.unavailable(),
    FixedPreparationScale scale = const FixedPreparationScale.authored(),
  }) {
    ReaderWorkGuard.check(ReaderWork.surfacePreparation);
    source.requireLive();
    final document = source.document;
    // Planning has no native allocation. Preparation binds the same service
    // to the registered paragraph faces and the prepaid local sub-ledger.
    if (svgFeatureHost.foreignObject
        is SvgUnavailableForeignObjectLayoutService) {
      svgFeatureHost = SvgFeatureHost(
        foreignObject: FixedForeignObjectLayoutService(
          styles: source.styles,
          page: source.page,
        ),
        text: svgFeatureHost.text,
      );
    }
    final facts = extractSectionSourceFacts(document);
    var dimensions = resolveAuthoredDimensions(
      source: facts,
      packageRendition: source.rendition.effective,
    );
    final viewports = dimensions is ResolvedDimensions
        ? fixedInlineSvgViewports(source, dimensions.size)
        : <int, FixedSvgViewport>{};
    DimensionResolution? svgDimensionFailure;
    if (dimensions is ResolvedDimensions) {
      for (final viewport in viewports.values) {
        if (viewport.dimensions is! ResolvedDimensions) {
          svgDimensionFailure = viewport.dimensions;
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
    } else if (dimensions is! ResolvedDimensions ||
        svgDimensionFailure != null) {
      final failure = svgDimensionFailure ?? dimensions;
      final constructs = [
        OffendingConstruct(
          kind: CapabilityConstructKind.dimensions,
          identifier: 'authored-viewport',
        ),
      ];
      capability = failure is MalformedDimensions
          ? MalformedSectionCapability(
              sectionIndex: section,
              reason: failure.reason,
              constructs: constructs,
            )
          : UnsupportedSectionCapability(
              sectionIndex: section,
              reason: (failure as UnsupportedDimensions).reason,
              constructs: constructs,
            );
    } else {
      capability = CompleteSectionCapability(
        sectionIndex: section,
        reason: 'Fixed inputs planned; scene completeness awaits preparation',
      );
    }
    final svgRoots = _svgRoots(document);
    var svgPlans = <SvgGraphicsPlan>[];
    if (capability.isComplete &&
        dimensions is ResolvedDimensions &&
        svgRoots.isNotEmpty) {
      final svgDiagnostic = _svgDiagnostic(section, source.styles.diagnostics);
      if (svgDiagnostic != null) {
        capability = svgDiagnostic;
      } else {
        final presentation = _svgPresentation(
          document,
          source.styles,
          svgRoots,
        );
        for (final root in svgRoots) {
          final svgSize =
              (viewports[root]!.dimensions as ResolvedDimensions).size;
          final plan = SvgGraphicsPlan.inspect(
            preparationScale: scale,
            document: document,
            rootIndex: root,
            page: source.page,
            size: svgSize,
            evidenceSize: dimensions.size,
            resolvedPresentation: {
              ...presentation,
              root: {
                ...?presentation[root],
                'width': '${svgSize.width}',
                'height': '${svgSize.height}',
              },
            },
            host: svgFeatureHost,
          );
          svgPlans.add(plan);
          if (capability.isComplete && !plan.capability.isComplete) {
            capability = plan.capability;
          }
        }
      }
    }
    var depth = 0, layers = 0, textNodes = 0, decorations = 0, units = 0;
    var referenceDepth = 0;
    var shiftedInline = false;
    var operations = 0;
    final depths = <int, int>{}, layerDepths = <int, int>{};
    for (final node in document.nodes) {
      final d = (depths[node.parentIndex] ?? 0) + 1;
      depths[node.index] = d;
      if (d > depth) depth = d;
      units += node.text?.length ?? 0;
      final style = source.styles.styleOf(node.index);
      final paintsXhtml = _paintsXhtml(source, node.index);
      if (svgRoots.contains(node.index) ||
          paintsXhtml &&
              !node.isCharacterData &&
              (node.localName == 'img' ||
                  node.localName == 'br' ||
                  style?.display == StyleDisplay.inlineBlock)) {
        units++; // Atomic placeholders and generated line breaks are shaped.
      }
      if (paintsXhtml &&
          !node.isCharacterData &&
          (style?.textIndent.resolve(1) ?? 0) != 0) {
        units++; // At most one indent placeholder per paragraph owner.
      }
      if (node.isCharacterData &&
          paintsXhtml &&
          ((node.text ?? '').trim().isNotEmpty ||
              style?.underline == true ||
              style?.lineThrough == true)) {
        textNodes++;
      }
      if (style != null && style.verticalAlign != StyleVerticalAlign.baseline) {
        shiftedInline = true;
      }
      if (!node.isCharacterData &&
          (style?.display == StyleDisplay.inline ||
              style?.display == StyleDisplay.inlineBlock) &&
          style?.authored.position == AuthoredPosition.relative) {
        shiftedInline = true;
      }
      final a = style?.authored;
      final ld =
          (layerDepths[node.parentIndex] ?? 0) +
          (!node.isCharacterData && a != null && a.opacity < 1 ? 1 : 0);
      layerDepths[node.index] = ld;
      if (ld > layers) layers = ld;
      if (node.isCharacterData || style == null || !paintsXhtml) continue;
      if (style.backgroundColor != null ||
          a!.backgroundImage != null ||
          const [
            'top',
            'right',
            'bottom',
            'left',
          ].any((e) => a.borderStyle(e) != 'none')) {
        // An inline decoration publishes separate evidence for its fragments.
        // Every fragment consumes at least one paragraph unit (including br /
        // placeholders); prepay its worst-case grid before shaping occurs.
        decorations += style.display == StyleDisplay.inline
            ? _inlineDecorationUnits(document, node.index)
            : 1;
      }
      if (node.localName == 'img') decorations++;
      operations += a!.backgroundImage == null ? 32 : 16416;
    }
    for (final plan in svgPlans) {
      depth = math.max(depth, plan.sourceDepth);
      referenceDepth = math.max(referenceDepth, plan.referenceDepth);
      layers = math.max(layers, plan.layerDepth);
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
        // The fixed painter delegates SVG coverage to its prepaid SVG scene;
        // it does not retain a second XHTML alpha map for the wrapper box.
        document.nodes
            .where((n) => n.localName == 'br' && _paintsXhtml(source, n.index))
            .length;
    final svg = _svgResourceUsage(svgPlans);
    final xhtmlEvidenceBytes =
        (pixels + GeometryAlphaFootprint.storageOverhead) * alphaMaps;
    var evidencePixels = dimensions is ResolvedDimensions && alphaMaps > 0
        ? AuthoredEvidenceRaster.scratchPixels(
            dimensions.size.width.ceil(),
            dimensions.size.height.ceil(),
          )
        : 0;
    evidencePixels = math.max(evidencePixels, svg.evidencePixels);
    for (final image in source.images.values) {
      // Opacity inspection borrows an already image-cache-charged decode and
      // needs only its tile pair. It completes before scene rasterization.
      evidencePixels = math.max(
        evidencePixels,
        AuthoredEvidenceRaster.tilePixels(image.width, image.height),
      );
    }
    final displayPixels = dimensions is ResolvedDimensions
        ? scale.pixels(dimensions.size.width) *
              scale.pixels(dimensions.size.height)
        : 0;
    final layerPixels =
        displayPixels * layers +
        svg.layerPixels -
        svg.evidencePixels +
        evidencePixels;
    final svgDynamic = _svgHasDynamicPaint(document, svgRoots);
    final svgDashBytes = _svgDashBytes(document, svgRoots);
    if (svg.failure != null && capability.isComplete) {
      capability = ResourceSectionCapability(
        sectionIndex: section,
        reason: 'Inline SVG exceeds resource admission',
        constructs: [
          OffendingConstruct(
            kind: CapabilityConstructKind.resource,
            identifier: 'svg-${svg.failure!.resource?.name ?? 'resource'}',
          ),
        ],
      );
    }
    final resources = <SceneResource, int>{
      SceneResource.sourceBytes: source.retainedSourceBytes,
      // Original SVG nodes are already in the document charge. Add expansion
      // above that subtree's source count, including repeated references.
      SceneResource.sourceNodes:
          document.nodes.length +
          svgPlans.fold(
            0,
            (sum, p) =>
                sum +
                math.max(
                  0,
                  (p.resources[SceneResource.sourceNodes] ?? 0) -
                      _svgSourceNodeCount(document, p.rootIndex),
                ),
          ),
      SceneResource.textCodeUnits:
          units + (shiftedInline ? units * units + 1 : 0) + svg.textCodeUnits,
      // Shifted inline paint retains the original shaping Paragraph plus at
      // most one paint group per source unit, and one temporary font probe.
      SceneResource.paragraphs:
          document.nodes.length +
          (shiftedInline ? units + 1 : 0) +
          svg.paragraphs,
      SceneResource.vectorBytes:
          units * 512 +
          document.nodes.length * 512 +
          xhtmlEvidenceBytes +
          svg.vectorBytes +
          svgDashBytes,
      SceneResource.vectorOperations: math.max(
        operations + units * 8 + svg.vectorOperations,
        svgDynamic
            ? SceneResourceBudget.provisionalLimits[SceneResource
                  .vectorOperations]!
            : 0,
      ),
      SceneResource.references: math.max(
        source.images.length + svg.references,
        svgDynamic
            ? SceneResourceBudget.provisionalLimits[SceneResource.references]!
            : 0,
      ),
      SceneResource.gradientStops: svg.gradientStops,
      SceneResource.layerPixels: layerPixels,
      SceneResource.layerBytes:
          displayPixels * layers * 4 +
          svg.layerBytes -
          svg.evidencePixels * 4 +
          evidencePixels * 4,
    };
    return FixedPreparationPlan._(
      source,
      dimensions,
      capability,
      resources,
      depth,
      referenceDepth,
      layers + 1,
      List.unmodifiable(svgPlans),
      svgFeatureHost,
      evidencePixels,
      scale,
      xhtmlEvidenceBytes + svg.retainedEvidenceBytes,
    );
  }

  static int _inlineDecorationUnits(SourceDocument document, int root) {
    final node = document.node(root);
    if (node.isCharacterData) return node.text?.length ?? 0;
    if (atomicElementNames.contains(node.localName) || node.localName == 'br') {
      return 1;
    }
    return node.children.fold(
      0,
      (sum, child) => sum + _inlineDecorationUnits(document, child),
    );
  }
}

const _svgNamespace = 'http://www.w3.org/2000/svg';

bool _paintsXhtml(FixedSourceLease source, int index) {
  int? current = index;
  while (current != null) {
    final node = source.document.node(current);
    if (node.namespaceUri == _svgNamespace ||
        source.styles.styleOf(current)?.display == StyleDisplay.none ||
        const {'head', 'script', 'style', 'title'}.contains(node.localName)) {
      return false;
    }
    current = node.parentIndex;
  }
  return true;
}

final class _SvgResourceUsage {
  const _SvgResourceUsage({
    this.textCodeUnits = 0,
    this.paragraphs = 0,
    this.vectorBytes = 0,
    this.vectorOperations = 0,
    this.references = 0,
    this.gradientStops = 0,
    this.layerPixels = 0,
    this.layerBytes = 0,
    this.evidencePixels = 0,
    this.retainedEvidenceBytes = 0,
    this.failure,
  });
  final int vectorBytes, vectorOperations, references, gradientStops;
  final int textCodeUnits, paragraphs;
  final int layerPixels, layerBytes;
  final int evidencePixels;
  final int retainedEvidenceBytes;
  final SceneAdmissionException? failure;
}

_SvgResourceUsage _svgResourceUsage(List<SvgGraphicsPlan> plans) {
  var textCodeUnits = 0, paragraphs = 0;
  var vectorBytes = 0,
      vectorOperations = 0,
      references = 0,
      gradientStops = 0,
      layerPixels = 0,
      layerBytes = 0;
  var evidencePixels = 0, retainedEvidenceBytes = 0;
  for (final plan in plans) {
    try {
      final reservation = plan.reservation();
      retainedEvidenceBytes += plan.retainedEvidenceBytes;
      textCodeUnits += reservation[SceneResource.textCodeUnits] ?? 0;
      paragraphs += reservation[SceneResource.paragraphs] ?? 0;
      vectorBytes += reservation[SceneResource.vectorBytes] ?? 0;
      layerPixels +=
          (reservation[SceneResource.layerPixels] ?? 0) - plan.evidencePixels;
      layerBytes +=
          (reservation[SceneResource.layerBytes] ?? 0) -
          plan.evidencePixels * 4;
      evidencePixels = math.max(evidencePixels, plan.evidencePixels);
      vectorOperations += plan.resources[SceneResource.vectorOperations] ?? 0;
      references += plan.resources[SceneResource.references] ?? 0;
      gradientStops += plan.resources[SceneResource.gradientStops] ?? 0;
    } on SceneAdmissionException catch (error) {
      return _SvgResourceUsage(
        vectorBytes: vectorBytes,
        vectorOperations: vectorOperations,
        references: references,
        gradientStops: gradientStops,
        layerPixels: layerPixels,
        layerBytes: layerBytes,
        failure: error,
      );
    }
  }
  return _SvgResourceUsage(
    textCodeUnits: textCodeUnits,
    paragraphs: paragraphs,
    vectorBytes: vectorBytes,
    vectorOperations: vectorOperations,
    references: references,
    gradientStops: gradientStops,
    layerPixels: layerPixels + evidencePixels,
    layerBytes: layerBytes + evidencePixels * 4,
    evidencePixels: evidencePixels,
    retainedEvidenceBytes: retainedEvidenceBytes,
  );
}

List<int> _svgRoots(SourceDocument document) => [
  for (final node in document.nodes)
    if (node.localName == 'svg' &&
        node.namespaceUri == _svgNamespace &&
        !_hasSvgAncestor(document, node.index))
      node.index,
];

int _svgSourceNodeCount(SourceDocument document, int index) {
  var count = 0;
  final pending = [index];
  while (pending.isNotEmpty) {
    count++;
    pending.addAll(document.node(pending.removeLast()).children);
  }
  return count;
}

bool _hasSvgAncestor(SourceDocument document, int index) {
  int? parent = document.node(index).parentIndex;
  while (parent != null) {
    final node = document.node(parent);
    if (node.localName == 'svg' && node.namespaceUri == _svgNamespace) {
      return true;
    }
    parent = node.parentIndex;
  }
  return false;
}

bool _svgHasDynamicPaint(SourceDocument document, List<int> roots) {
  for (final node in document.nodes) {
    if (node.namespaceUri != _svgNamespace) continue;
    if (node.localName == 'pattern') return true;
    if (node.localName == 'path' &&
        (node.attribute('stroke-dasharray') ?? 'none') != 'none') {
      return true;
    }
  }
  return false;
}

int _svgDashBytes(SourceDocument document, List<int> roots) {
  var bytes = 0;
  for (final node in document.nodes) {
    if (node.namespaceUri != _svgNamespace) continue;
    final dash = node.attribute('stroke-dasharray');
    if (dash == null || dash == 'none') continue;
    bytes += (node.attribute('d') ?? '').length * 96;
  }
  return bytes;
}

const _svgCssProperties = {
  'fill',
  'fill-rule',
  'fill-opacity',
  'stroke',
  'stroke-width',
  'stroke-linecap',
  'stroke-linejoin',
  'stroke-miterlimit',
  'stroke-dasharray',
  'stroke-dashoffset',
  'stroke-opacity',
  'color',
  'opacity',
  'visibility',
  'display',
  'overflow',
  'filter',
  'mask',
  'clip-path',
  'marker-start',
  'marker-mid',
  'marker-end',
  'stop-color',
  'stop-opacity',
};

SectionCapability? _svgDiagnostic(
  int section,
  List<StyleDiagnostic> diagnostics,
) {
  for (final diagnostic in diagnostics) {
    if (diagnostic.kind != StyleDiagnosticKind.unsupportedProperty &&
        diagnostic.kind != StyleDiagnosticKind.invalidValue) {
      continue;
    }
    final property = diagnostic.detail.toLowerCase();
    if (!_svgCssProperties.contains(property)) continue;
    return UnsupportedSectionCapability(
      sectionIndex: section,
      reason: 'Inline SVG uses CSS outside the typed presentation profile',
      constructs: [
        OffendingConstruct(
          kind: CapabilityConstructKind.svg,
          identifier: 'svg-$property',
        ),
      ],
    );
  }
  return null;
}

Map<int, Map<String, String>> _svgPresentation(
  SourceDocument document,
  CssStyledDocument styles,
  List<int> roots,
) {
  final rootSet = roots.toSet();
  final result = <int, Map<String, String>>{};
  for (final node in document.nodes) {
    if (node.namespaceUri != _svgNamespace) continue;
    final style = styles.styleOf(node.index);
    if (style == null) continue;
    final index = node.index, values = <String, String>{};
    final authored = style.authored;
    final root = rootSet.contains(index);
    if (!root) {
      if (authored.opacity != 1) {
        values['opacity'] = '${authored.opacity}';
      }
      if (authored.visibility == AuthoredVisibility.hidden) {
        values['visibility'] = 'hidden';
      }
      if (style.display == StyleDisplay.none) values['display'] = 'none';
      if (authored.transforms.isNotEmpty) {
        values['transform'] = authored.transforms
            .map(_svgTransformString)
            .join(' ');
      }
    }
    // A presentation attribute is an author-level declaration at specificity
    // zero: project `color` only when CSS actually declares it on this element
    // (or, at the root, to carry the host's inherited CSS color into SVG).
    // Otherwise the module keeps the source attribute's inheritance intact.
    final declaresColor = _declaresSvgColor(document, styles, index, style);
    if (declaresColor || (root && node.attribute('color') == null)) {
      values['color'] = _cssColor(style.color);
    }
    result[index] = Map.unmodifiable(values);
  }
  return Map.unmodifiable(result);
}

bool _declaresSvgColor(
  SourceDocument document,
  CssStyledDocument styles,
  int index,
  ComputedStyle style,
) {
  final inline = document.node(index).attribute('style');
  if (inline != null &&
      parseInlineStyle(
        inline,
        null,
      ).any((declaration) => declaration.property == 'color')) {
    return true;
  }
  final parentIndex = document.node(index).parentIndex;
  final inherited = parentIndex == null
      ? 0xFF000000
      : styles.styleOf(parentIndex)?.color ?? 0xFF000000;
  // Inheritance cannot change the computed color; a difference means the
  // element itself matched a CSS declaration.
  return style.color != inherited;
}

String _cssColor(int argb) {
  final a = (argb >> 24) & 0xff,
      r = (argb >> 16) & 0xff,
      g = (argb >> 8) & 0xff,
      b = argb & 0xff;
  String hex(int value) => value.toRadixString(16).padLeft(2, '0');
  return a == 255
      ? '#${hex(r)}${hex(g)}${hex(b)}'
      : 'rgba($r,$g,$b,${(a / 255).toStringAsFixed(3)})';
}

String _svgTransformString(AuthoredTransform transform) {
  final args = transform.arguments
      .map((argument) {
        if (argument is StyleLength) return argument.toString();
        if (argument is num) {
          final value = argument.toDouble();
          if (transform.name == 'rotate' || transform.name.startsWith('skew')) {
            return '${(value * 180 / math.pi).toStringAsFixed(8)}deg';
          }
          return value.toString();
        }
        return '$argument';
      })
      .join(',');
  return '${transform.name}($args)';
}
