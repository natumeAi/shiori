/// Source-aware SVG graphics assembly. The compiler is used only inside one
/// identified leaf; references and scene ordering never come from its picture.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' show BuildContext;
import 'package:flutter_svg/flutter_svg.dart' show BytesLoader, vg;
import 'package:xml/xml.dart';
// Already pinned through flutter_svg; no additional package is selected.
// ignore: depend_on_referenced_packages
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart' as vc;
// Path segment boundaries are needed before arcs expand into cubic pieces.
// ignore: depend_on_referenced_packages
import 'package:path_parsing/path_parsing.dart' as pp;
import 'package:shiori/features/reader/data/geometry/affine_transform.dart';
import 'package:shiori/features/reader/data/geometry/cluster_geometry.dart';
import 'package:shiori/features/reader/data/geometry/paint_geometry.dart';
import 'package:shiori/features/reader/data/geometry/source_fragment.dart';
import 'package:shiori/features/reader/data/geometry/source_geometry.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/layout/source_page_id.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/source/source_node.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_svg_viewport.dart';
import 'package:shiori/features/reader/data/worker/publication_layout_facts.dart';
import 'package:shiori/features/reader/data/worker/publication_cancellation.dart';
import 'package:shiori/features/reader/engine/pagination/preparation.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/support/section_capability.dart';

part 'svg_graphics_plan.dart';
part 'svg_graphics_values.dart';
part 'svg_graphics_shapes.dart';
part 'svg_graphics_prepare.dart';
part 'svg_graphics_geometry.dart';
part 'svg_graphics_tree.dart';
part 'svg_graphics_markers.dart';
part 'svg_graphics_patterns.dart';
part 'svg_path_bounds.dart';
part 'svg_graphics_validation.dart';
part 'svg_graphics_dash.dart';

/// Decoded images are borrowed from the caller's admitted image leases.
/// SVG image resources are already prepared scenes, never arbitrary markup.
final class SvgGraphicsImages {
  const SvgGraphicsImages({this.rasters = const {}, this.vectors = const {}});
  final Map<String, ui.Image> rasters;
  final Map<String, SvgGraphicsScene> vectors;
}

final class SvgGraphicsScene {
  SvgGraphicsScene._(
    this.size,
    this.picture,
    this.geometry,
    this.capability,
    this.elements,
    this._pictures,
    this._leases,
  );
  final AuthoredPageSize size;
  final ui.Picture? picture;
  final SourceGeometry geometry;
  final SectionCapability capability;
  final List<SvgGraphicsElement> elements;
  final List<ui.Picture> _pictures;
  final List<SceneResourceLease> _leases;
  bool _disposed = false;
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    picture?.dispose();
    for (final p in _pictures) {
      p.dispose();
    }
    for (final lease in _leases.reversed) {
      lease.release();
    }
  }
}

/// An instance retains both its source node and the chain of referencing nodes.
/// Bounds are fill geometry in local user space, excluding stroke and markers.
final class SvgGraphicsElement {
  SvgGraphicsElement(
    this.nodeIndex,
    this.instancePath,
    this.transform,
    this.paintOrdinal,
    this.bounds,
    this.paint,
    this.resourceNodes,
  );
  final int nodeIndex, paintOrdinal;
  final List<int> instancePath;
  final AffineTransform transform;
  final ui.Rect bounds;
  final Map<String, String> paint;

  /// Original nodes contributing gradient stops/pattern/marker paint. Resource
  /// definitions are not assigned fictitious independent document paint boxes.
  final List<int> resourceNodes;
}

final class _SvgFailure implements Exception {
  _SvgFailure(this.node, this.identifier, {this.malformed = false});
  final int node;
  final String identifier;
  final bool malformed;
}

/// Per-leaf byte lifetime. SvgStringLoader uses a process-global compilation
/// cache, which would outlive this scene's reservation and source owner.
final class _SvgBytes extends BytesLoader {
  const _SvgBytes(this.data);
  final ByteData data;
  @override
  Future<ByteData> loadBytes(BuildContext? context) async => data;
}

final class _SvgInstance {
  _SvgInstance(
    this.node,
    this.attributes,
    this.paint,
    this.transform,
    this.viewport,
    this.instances,
    this.clips,
    this.opacity,
    this.groups,
  );
  final SourceNode node;
  final Map<String, String> attributes, paint;
  final AffineTransform transform;
  final ui.Size viewport;
  final List<int> instances;
  final List<GeometryClip> clips;
  final double opacity;
  final List<GeometryOpacityGroup> groups;
  final List<_SvgInstance> children = [];
  ui.Rect? bounds;
  ui.Picture? picture;
  ui.Path? path;
  int ordinal = 0;
}
