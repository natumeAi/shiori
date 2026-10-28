import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:shiori/features/reader/data/geometry/source_geometry.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/layout/reading_unit.dart';
import 'package:shiori/features/reader/data/layout/source_page_id.dart';
import 'package:shiori/features/reader/data/layout/source_page_slot.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';
import 'package:shiori/features/reader/data/worker/publication_cancellation.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_preparation_plan.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_scene_admission.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_section_preparer.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_source_lease.dart';
import 'package:shiori/features/reader/engine/layout/font_registry.dart';
import 'package:shiori/features/reader/engine/layout/image_cache.dart';
import 'package:shiori/features/reader/engine/layout/layout_model.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/motion/reader_preparation_failure.dart';
import 'package:shiori/features/reader/engine/pagination/layout_identity.dart';
import 'package:shiori/features/reader/engine/pagination/preparation.dart';
import 'package:shiori/features/reader/engine/pagination/page_painter.dart';
import 'package:shiori/features/reader/engine/pagination/page_plan.dart';
import 'package:shiori/features/reader/engine/pagination/prepared_section.dart';
import 'package:shiori/features/reader/engine/support/section_capability.dart';

part 'package:shiori/features/reader/engine/surface/fixed_unit_surface.dart';

/// Pending native work and retained surfaces share this single admission owner.
/// Release only after physical work/allocations have drained.
final class UnitSurfaceReservation {
  UnitSurfaceReservation._(this._pool, this.unit, this._resources);
  final PageSurfacePool _pool;
  final ReadingUnit? unit;
  final SceneResourceLease _resources;
  PreparedSection? _section;
  int _parts = 1, _fixedPictureCharge = 0;
  ImageReservation? _imageReservation;
  void _releasePart() {
    if (--_parts == 0) release();
  }

  bool get released => _resources.isReleased;
  void release() {
    ReaderWorkGuard.check(ReaderWork.surfacePreparation);
    if (released) return;
    _pool.allocations._pictureBytes -= _fixedPictureCharge;
    _fixedPictureCharge = 0;
    _imageReservation?.release();
    _resources.release();
    final section = _section;
    if (section != null) _pool.allocations._unpin(section);
    _pool._reservations.remove(this);
    if (_pool._reservations.isEmpty) _pool._drained?.complete();
  }
}

/// Share this owner across old/new pools during layout replacement. Pending
/// pictures and decode peaks consume the same 16/48 MiB owners as retained data.
final class SurfaceAllocationBudget {
  SurfaceAllocationBudget({
    this.maxPictureBytes = 16 * 1024 * 1024,
    int maxImageBytes = 48 * 1024 * 1024,
  }) : images = ReaderImageCache(maxBytes: maxImageBytes);
  final int maxPictureBytes;
  final ReaderImageCache images;
  int _pictureBytes = 0;
  final Map<PreparedSection, int> _pins = {};
  bool pinsSection(PreparedSection section) => (_pins[section] ?? 0) > 0;
  void _pin(PreparedSection section) =>
      _pins.update(section, (n) => n + 1, ifAbsent: () => 1);
  void _unpin(PreparedSection section) {
    final count = _pins[section]!;
    if (count == 1) {
      _pins.remove(section);
    } else {
      _pins[section] = count - 1;
    }
  }
}

/// Protects borrowed source/Paragraph/vector storage across preparation awaits.
final class SectionSurfacePin {
  SectionSurfacePin._(this._budget, this.section) {
    _budget._pin(section);
  }
  final SurfaceAllocationBudget _budget;
  final PreparedSection section;
  bool _released = false;
  void release() {
    if (_released) return;
    _released = true;
    _budget._unpin(section);
  }
}

/// A lease owns one reference; the last release disposes the retained picture.
final class PageSurfaceLease {
  PageSurfaceLease._(this._pool, this.surface);
  final PageSurfacePool _pool;
  final PreparedPageSurface surface;
  bool _released = false;
  bool get released => _released;
  PageSurfaceLease retain() {
    if (_released || surface.disposed) throw StateError('Expired page surface');
    surface._references++;
    return PageSurfaceLease._(_pool, surface);
  }

  void release() {
    ReaderWorkGuard.check(ReaderWork.surfacePreparation);
    if (_released) return;
    _released = true;
    if (--surface._references == 0) _pool._dispose(surface);
  }
}

final class PreparedPageSurface {
  PreparedPageSurface._(
    this.reflowSection,
    this.pageIndex,
    this.picture,
    this._images,
    this._reservation,
  ) : fixedScenes = const [],
      geometry = const [],
      _fixedLayout = null;
  PreparedPageSurface._fixed(
    this.picture,
    this._reservation,
    this._fixedLayout,
    List<PreparedFixedScene> scenes,
    List<SourceGeometry> geometry,
  ) : reflowSection = null,
      pageIndex = 0,
      _images = const {},
      fixedScenes = List.unmodifiable(scenes),
      geometry = List.unmodifiable(geometry);
  final PreparedSection? reflowSection;
  PreparedSection get section =>
      reflowSection ??
      (throw StateError(
        'Fixed surfaces retain source scenes, not reflow sections',
      ));
  final LayoutIdentity? _fixedLayout;
  LayoutIdentity get layout => _fixedLayout ?? section.identity;
  final List<PreparedFixedScene> fixedScenes;
  final List<SourceGeometry> geometry;
  final int pageIndex;
  final ui.Picture picture;
  final Map<int, ImageLease> _images;
  final UnitSurfaceReservation _reservation;
  ReadingUnit? get unit => _reservation.unit;
  int _references = 1;
  bool disposed = false;
  int get pictureBytes => picture.approximateBytesUsed;
  String get identity => reflowSection == null
      ? unit!.id.stableId
      : section.pages[pageIndex].map.identity;
}

/// Three presented pages plus one preparation/handoff reserve. No idle pictures
/// are cached: a released page returns its bytes immediately. Pending records
/// occupy the same owner budget, including through cancellation and close.
final class PageSurfacePool {
  PageSurfacePool({
    int maxPictureBytes = 16 * 1024 * 1024,
    int maxImageBytes = 48 * 1024 * 1024,
    SceneResourceBudget? resourceBudget,
    SurfaceAllocationBudget? allocations,
  }) : allocations =
           allocations ??
           SurfaceAllocationBudget(
             maxPictureBytes: maxPictureBytes,
             maxImageBytes: maxImageBytes,
           ),
       resourceBudget = resourceBudget ?? SceneResourceBudget();
  static const presentedCapacity = 3;
  static const reserve = 1;
  static const capacity = presentedCapacity + reserve;
  final SurfaceAllocationBudget allocations;
  int get maxPictureBytes => allocations.maxPictureBytes;
  int get maxImageBytes => images.maxBytes;
  ReaderImageCache get images => allocations.images;
  final SceneResourceBudget resourceBudget;
  final Set<PreparedPageSurface> _live = {};
  final Set<UnitSurfaceReservation> _reservations = {};
  final _imageCredits = Expando<ImageReservation>();
  int _epoch = 0;
  bool _closed = false;
  Completer<void>? _drained;
  Future<void> get drained =>
      owners == 0 ? Future.value() : (_drained ??= Completer<void>()).future;
  int peakOwners = 0;
  int get liveSurfaces => _live.length;
  int get owners => _reservations.length;
  int get pictureBytes => allocations._pictureBytes;
  bool pinsSection(PreparedSection section) => allocations.pinsSection(section);
  SectionSurfacePin pinSection(PreparedSection section) =>
      SectionSurfacePin._(allocations, section);

  /// Conservative command/reference storage plan for the existing reflow
  /// painter. Opaque native storage is reconciled after recording; an estimate
  /// overrun is refused, never repaired by unbudgeted growth or partial output.
  static int pictureReservationBytes(PreparedSection section, int pageIndex) {
    var bytes = 64 * 1024;
    for (final fragment in section.pages[pageIndex].fragments) {
      final laid = section.blocks[fragment.blockIndex];
      bytes += 4096;
      if (laid.block case TextBlock(:final text, :final backgrounds)) {
        bytes += text.length * 128 + backgrounds.length * 1024;
      }
      bytes += laid.vector?.picture.approximateBytesUsed ?? 0;
    }
    return bytes;
  }

  /// All constituents are admitted atomically on the pool's ownership decision.
  /// A blank contributes no source. This is also the pending-work seam for A2;
  /// reserving a unit does not publish a prepared scene or claim capability.
  UnitSurfaceReservation? reserveUnit(ReadingUnit unit) => _reserve(unit);

  UnitSurfaceReservation? _reserve(
    ReadingUnit? unit, {
    Map<SceneResource, int> resources = const {},
    int sourceDepth = 0,
    int referenceDepth = 0,
    int layerDepth = 0,
  }) {
    ReaderWorkGuard.check(ReaderWork.surfacePreparation);
    if (_closed || owners >= capacity) return null;
    final lease = resourceBudget.reserveUnit(
      sourcePages: unit?.realSourceCount ?? 1,
      resources: resources,
      sourceDepth: sourceDepth,
      referenceDepth: referenceDepth,
      layerDepth: layerDepth,
    );
    final reservation = UnitSurfaceReservation._(this, unit, lease);
    if (_reservations.isEmpty) _drained = null;
    _reservations.add(reservation);
    if (owners > peakOwners) peakOwners = owners;
    return reservation;
  }

  Future<PageSurfaceLease?> prepare(
    PreparedSection section,
    int pageIndex,
    PagePaintTheme theme, {
    ReadingUnit? unit,
    bool typedFailures = false,
  }) async {
    ReaderWorkGuard.check(ReaderWork.surfacePreparation);
    if (unit != null &&
        (unit.kind != ReadingUnitKind.reflowPage ||
            unit.activeSource.sectionIndex != section.sectionIndex ||
            unit.id.content.sha256 != section.identity.contentId)) {
      throw ArgumentError('Unit does not describe this reflow section');
    }
    final reservation = _reserve(unit);
    if (reservation == null) {
      if (typedFailures && !_closed) {
        throw const SceneAdmissionException(
          SceneAdmissionFailure.resourceExhausted,
          resource: SceneResource.readingUnits,
        );
      }
      return null;
    }
    reservation._section = section;
    allocations._pin(section);
    final epoch = _epoch;
    final leases = <int, ImageLease>{};
    ui.Picture? picture;
    var transferred = false;
    var pictureCharge = 0;
    try {
      final bound = pictureReservationBytes(section, pageIndex);
      if (bound > maxPictureBytes - pictureBytes) {
        if (typedFailures) throw const PictureAdmissionException();
        return null;
      }
      pictureCharge = bound;
      allocations._pictureBytes += bound;
      for (final fragment in section.pages[pageIndex].fragments) {
        if (fragment is! BoxFragment) continue;
        final block = section.blocks[fragment.blockIndex].block;
        if (block is! ImageBlock ||
            block.resourcePath == null ||
            leases.containsKey(block.index)) {
          continue;
        }
        final bytes = section.resources.bytes(block.resourcePath!);
        if (bytes == null) continue;
        final dpr = section.identity.devicePixelRatio;
        final lease = await images.lease(
          '${section.identity.contentId}:${block.resourcePath}',
          bytes,
          targetWidth: (fragment.width * dpr).ceil().clamp(1, 8192),
          targetHeight: (fragment.height * dpr).ceil().clamp(1, 8192),
        );
        if (lease != null) leases[block.index] = lease;
        if (_closed || epoch != _epoch) return null;
      }
      if (_closed || epoch != _epoch || images.totalBytes > maxImageBytes) {
        return null;
      }
      picture = PagePainter.record(
        section,
        pageIndex,
        theme,
        imageOf: (i) => leases[i],
      );
      final size = picture.approximateBytesUsed;
      if (size > pictureCharge) {
        if (typedFailures) throw const PictureAdmissionException();
        return null;
      }
      allocations._pictureBytes -= pictureCharge - size;
      pictureCharge = size;
      final surface = PreparedPageSurface._(
        section,
        pageIndex,
        picture,
        leases,
        reservation,
      );
      _live.add(surface);
      transferred = true;
      return PageSurfaceLease._(this, surface);
    } on ImageAdmissionException {
      if (typedFailures) rethrow;
      return null;
    } finally {
      if (!transferred) {
        picture?.dispose();
        for (final lease in leases.values) {
          lease.release();
        }
        images.clearUnleased();
        allocations._pictureBytes -= pictureCharge;
        reservation.release();
      }
    }
  }

  void _dispose(PreparedPageSurface surface) {
    ReaderWorkGuard.check(ReaderWork.surfacePreparation);
    if (!_live.remove(surface)) return;
    final size = surface.pictureBytes;
    surface.disposed = true;
    surface.picture.dispose();
    if (surface.reflowSection != null) allocations._pictureBytes -= size;
    for (final scene in surface.fixedScenes) {
      scene.dispose();
    }
    for (final lease in surface._images.values) {
      lease.release();
    }
    if (surface.reflowSection != null) surface._images.clear();
    images.clearUnleased();
    surface._reservation._releasePart();
  }

  /// Existing leases stay valid until released; pending work cannot publish.
  void close() {
    _closed = true;
    _epoch++;
    images.clearUnleased();
  }
}
