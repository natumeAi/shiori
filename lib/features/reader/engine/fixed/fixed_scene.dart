library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:shiori/features/reader/data/geometry/affine_transform.dart';
import 'package:shiori/features/reader/data/geometry/cluster_geometry.dart';
import 'package:shiori/features/reader/data/geometry/source_fragment.dart';
import 'package:shiori/features/reader/data/geometry/source_geometry.dart';
import 'package:shiori/features/reader/data/geometry/paint_geometry.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/layout/section_source_facts.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_svg_viewport.dart';
import 'package:shiori/features/reader/data/layout/source_page_id.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';
import 'package:shiori/features/reader/data/worker/publication_cancellation.dart';
import 'package:shiori/features/reader/engine/pagination/preparation.dart';
import 'package:shiori/features/reader/engine/layout/inline_accumulator.dart';
import 'package:shiori/features/reader/engine/layout/layout_model.dart';
import 'package:shiori/features/reader/engine/layout/paragraph_factory.dart';
import 'package:shiori/features/reader/engine/layout/paragraph_map.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/style/computed_style.dart';
import 'package:shiori/features/reader/engine/style/css_style_resolver.dart';
import 'package:shiori/features/reader/engine/style/css_properties.dart';
import 'package:shiori/features/reader/engine/style/css_stylesheet.dart';
import 'package:shiori/features/reader/engine/support/section_capability.dart';

part 'fixed_scene_layout.dart';
part 'fixed_scene_inline.dart';
part 'fixed_scene_paint.dart';
part 'fixed_scene_geometry.dart';
part 'fixed_scene_coverage.dart';
part 'fixed_scene_svg.dart';

/// Retains the paragraphs actually painted. Images remain caller-owned leases.
final class FixedScene {
  FixedScene._(
    this.picture,
    this.boxes,
    this.texts,
    this.geometry,
    this.capability,
    this._leases,
  );
  final List<SceneResourceLease> _leases;
  final ui.Picture picture;
  final List<FixedBox> boxes;
  final List<FixedText> texts;
  final SourceGeometry geometry;
  final SectionCapability capability;
  bool _disposed = false;
  void dispose() {
    ReaderWorkGuard.check(ReaderWork.surfacePreparation);
    if (_disposed) return;
    _disposed = true;
    picture.dispose();
    for (final text in texts) {
      text.paragraph.dispose();
      text._inline?.dispose();
    }
    for (final lease in _leases) {
      lease.release();
    }
  }
}

final class FixedBox {
  FixedBox._(this.nodeIndex, this.style, this.parent);
  final int nodeIndex;
  final ComputedStyle style;
  final FixedBox? parent;
  final List<FixedBox> children = [];
  final List<FixedText> texts = [];
  final List<Object> contents = [];
  ui.Rect borderBox = ui.Rect.zero, contentBox = ui.Rect.zero;
  AffineTransform transform = const AffineTransform.identity();
  AffineTransform localTransform = const AffineTransform.identity();
  ui.Offset transformOrigin = ui.Offset.zero;
  double effectiveOpacity = 1;
  // Singular transforms suppress subtree paint/proof; layout still uses boxes.
  bool hasVisibleTransform = true;
  int paintOrdinal = 0;
  List<String> clipIds = const [];
  AffineTransform? svgContentTransform;
  int? svgFill;
  bool get context =>
      parent == null ||
      style.authored.opacity < 1 ||
      style.authored.transforms.isNotEmpty ||
      style.authored.position != AuthoredPosition.static &&
          style.authored.zIndex != null;
}

final class FixedText {
  FixedText._(this.owner, this.block, this.paragraph, this.origin);
  final FixedBox owner;
  final TextBlock block;
  final BuiltParagraph paragraph;
  final ui.Offset origin;
  _FixedInline? _inline;
  double get height => _inline?.height ?? paragraph.height;
  ui.Offset _offsetAt(int offset) =>
      _inline?.offsetAt(offset) ?? ui.Offset.zero;
  int paintOrdinal = 0;
}

/// Authored CSS coordinates throughout; viewport fitting belongs to the host.
final class FixedSceneBuilder {
  FixedSceneBuilder({
    required this.document,
    required this.styles,
    required this.page,
    required this.size,
    required this.fonts,
    this.backgroundImages = const {},
    this.cancellation,
    SceneResourceBudget? budget,
  }) : budget = budget ?? SceneResourceBudget();
  final SceneResourceBudget budget;
  final SourceDocument document;
  final CssStyledDocument styles;
  final SourcePageId page;
  final AuthoredPageSize size;
  final ParagraphFonts fonts;
  final Map<String, ui.Image> backgroundImages;
  final PublicationCancellation? cancellation;
  void _checkCancellation() {
    if (cancellation?.isCanceled ?? false) throw const PreparationCancelled();
  }

  final List<FixedBox> _boxes = [];
  final List<FixedText> _texts = [];
  final List<OffendingConstruct> _unsupported = [];
  final List<OffendingConstruct> _malformed = [];
  final List<GeometryIssue> _issues = [];
  final Set<int> _active = {};
  final List<GeometryClip> _clips = [];
  final List<GeometryPaint> _paint = [];
  final List<GeometryOpacityGroup> _groups = [];
  final List<String> _paintGroups = [];
  final List<(int, ui.Picture)> _coveragePictures = [];
  final List<SceneResourceLease> _leases = [];
  final List<OffendingConstruct> _resourceFailures = [];
  final List<OffendingConstruct> _dimensionFailures = [];
  int _ordinal = 0;
  bool _built = false;

  Future<FixedScene> build() async {
    ReaderWorkGuard.check(ReaderWork.surfacePreparation);
    if (_built) throw StateError('FixedSceneBuilder is single-use');
    _built = true;
    _checkCancellation();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, size.width, size.height),
    );
    try {
      try {
        _leases.add(
          budget.reserve({
            SceneResource.sourceNodes: document.nodes.length,
            SceneResource.textCodeUnits: document.nodes.fold(
              0,
              (sum, n) => sum + (n.text?.length ?? 0),
            ),
          }),
        );
        budget.reserveLayer(size.width.ceil(), size.height.ceil()).release();
      } on SceneAdmissionException catch (error) {
        _resourceFailures.add(
          OffendingConstruct(
            kind: CapabilityConstructKind.resource,
            identifier: error.resource?.name ?? error.failure.name,
          ),
        );
      }
      for (final d in styles.diagnostics) {
        _unsupported.add(
          OffendingConstruct(
            kind: CapabilityConstructKind.css,
            identifier: '${d.kind.name}:${d.detail}',
          ),
        );
      }
      final rootIndex = document.bodyIndex ?? document.documentElementIndex;
      final root = _resourceFailures.isEmpty
          ? _layout(
              rootIndex,
              null,
              ui.Rect.fromLTWH(0, 0, size.width, size.height),
              ui.Offset.zero,
              null,
              0,
            )
          : null;
      if (root != null) {
        try {
          _clips.add(
            GeometryClip(
              id: 'authored-page',
              region: GeometryRegion(
                left: 0,
                top: 0,
                width: size.width,
                height: size.height,
                transform: const AffineTransform.identity(),
              ),
            ),
          );
          _transforms(root, const AffineTransform.identity(), 1, const [
            'authored-page',
          ]);
          _paintContext(canvas, root);
        } on ArgumentError {
          _reject(
            root.nodeIndex,
            'nonfinite-transform-or-region',
            malformed: true,
          );
        }
      }
      await _resolveCoverage();
      _checkCancellation();
      final capability = _capability();
      if (!capability.isComplete) {
        _issues.add(GeometryIssue(GeometryGapKind.paint, capability.reason));
      }
      final geometry = _export();
      return FixedScene._(
        recorder.endRecording(),
        List.unmodifiable(_boxes),
        List.unmodifiable(_texts),
        geometry,
        capability,
        List.unmodifiable(_leases),
      );
    } on Object {
      recorder.endRecording().dispose();
      for (final text in _texts) {
        text.paragraph.dispose();
        text._inline?.dispose();
      }
      for (final pair in _coveragePictures) {
        pair.$2.dispose();
      }
      for (final lease in _leases) {
        lease.release();
      }
      rethrow;
    }
  }

  SectionCapability _capability() {
    if (_resourceFailures.isNotEmpty) {
      return ResourceSectionCapability(
        sectionIndex: page.sectionIndex,
        reason: 'Authored evidence resource admission failed',
        constructs: _resourceFailures,
      );
    }
    if (_malformed.isNotEmpty) {
      return MalformedSectionCapability(
        sectionIndex: page.sectionIndex,
        reason: 'Invalid authored geometry',
        constructs: _malformed,
      );
    }
    if (_dimensionFailures.isNotEmpty) {
      return UnsupportedSectionCapability(
        sectionIndex: page.sectionIndex,
        reason: 'Unsupported SVG dimensions',
        constructs: _dimensionFailures,
      );
    }
    if (_unsupported.isNotEmpty) {
      return UnsupportedSectionCapability(
        sectionIndex: page.sectionIndex,
        reason: 'Authored content outside admitted CSS profile',
        constructs: _unsupported,
      );
    }
    return CompleteSectionCapability(
      sectionIndex: page.sectionIndex,
      reason: 'Authored XHTML scene prepared',
    );
  }

  void _reject(int node, String reason, {bool malformed = false}) {
    (malformed ? _malformed : _unsupported).add(
      OffendingConstruct(
        kind: CapabilityConstructKind.layout,
        identifier: reason,
        nodeIndex: node,
      ),
    );
  }
}

AffineTransform _translation(double x, double y) =>
    AffineTransform(1, 0, 0, 1, x, y);
ui.Offset fixedMap(AffineTransform t, ui.Offset p) =>
    ui.Offset(t.a * p.dx + t.c * p.dy + t.e, t.b * p.dx + t.d * p.dy + t.f);
Float64List _matrix(AffineTransform t) => Float64List.fromList([
  t.a,
  t.b,
  0,
  0,
  t.c,
  t.d,
  0,
  0,
  0,
  0,
  1,
  0,
  t.e,
  t.f,
  0,
  1,
]);
