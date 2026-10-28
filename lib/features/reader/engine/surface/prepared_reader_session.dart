import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/features/reader/data/layout/reading_unit.dart';
import 'package:shiori/features/reader/data/layout/reading_unit_navigator.dart';
import 'package:shiori/features/reader/data/layout/source_page_id.dart';
import 'package:shiori/features/reader/data/source/source_position.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';
import 'package:shiori/features/reader/data/worker/publication_cancellation.dart';
import 'package:shiori/features/reader/engine/motion/page_turn_engine.dart';
import 'package:shiori/features/reader/engine/motion/turn_session.dart';
import 'package:shiori/features/reader/engine/motion/reader_preparation_failure.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_section_preparer.dart';
import 'package:shiori/features/reader/engine/layout/process_font_budget.dart';
import 'package:shiori/features/reader/engine/pagination/anchor.dart';
import 'package:shiori/features/reader/engine/pagination/page_painter.dart';
import 'package:shiori/features/reader/engine/pagination/prepared_section.dart';
import 'package:shiori/features/reader/engine/pagination/preparation.dart';
import 'package:shiori/features/reader/engine/pagination/reading_unit_navigator.dart';
import 'package:shiori/features/reader/engine/surface/page_surface_pool.dart';
import 'package:shiori/features/reader/engine/surface/prepared_page_position.dart';
import 'package:shiori/features/reader/engine/surface/prepared_unit_navigation.dart';
import 'package:shiori/features/reader/engine/surface/reader_publication_lifetime.dart';
import 'package:shiori/features/reader/engine/surface/surface_frame.dart';
import 'package:shiori/features/reader/engine/surface/fixed_unit_navigation.dart';
import 'package:shiori/features/reader/engine/support/section_capability.dart';

typedef _PreparationKey = ({
  int epoch,
  String layout,
  int generation,
  String page,
  int section,
  int index,
  int count,
  String cfi,
  TurnDirection direction,
  ReadingUnit? target,
});

final class _PreparationJob {
  late final Future<({TurnPosition position, PageSurfaceLease lease})?> result;
  int waiters = 0;
}

/// Prepared sections are borrowed from the caller's bounded preparation owner.
/// This session owns all page pictures and leases, including the handoff cover.
final class PreparedReaderSession
    implements TurnSession, TurnPreparationInvalidation {
  PreparedReaderSession._(
    this.pool,
    this.theme,
    this.sectionCount,
    this.loadSection,
    this._current,
    this._foreground,
    this.proofHook,
    this.drain,
    this.unitNavigation,
    this.activation,
    this.isActivationCurrent,
    this.fixedSources,
  ) : frames = ValueNotifier(SurfaceFrame(current: _current.surface));
  final PageSurfacePool pool;
  final PagePaintTheme theme;
  final int sectionCount;
  final Future<PreparedSection?> Function(int) loadSection;
  final AnchorProofHook? proofHook;
  final Future<void> Function()? drain;
  final PreparedUnitNavigation? unitNavigation;
  final ServerSession? activation;
  final bool Function(ServerSession)? isActivationCurrent;
  final FixedUnitSources? fixedSources;
  final Map<_PreparationKey, ReaderPreparationFailure> _failures = {};
  ReaderPreparationFailure? lastFailure;
  final Set<PublicationCancellation> _fixedWork = {};
  bool get _active =>
      state != TurnSessionState.closed &&
      (_publication?.isActive ?? true) &&
      (activation == null || isActivationCurrent!(activation!));
  final ValueNotifier<SurfaceFrame> frames;
  PageSurfaceLease _current;
  TurnPosition _foreground;
  PageSurfaceLease? _staged;
  bool _stagedAccepted = false;
  final Map<PreparedTurn, PageSurfaceLease> _previews = {};
  final Map<PreparedTurn, int> _previewEpochs = {};
  final Map<PreparedTurn, ReadingUnit?> _previewTargets = {};
  final Map<TurnDirection, PreparedTurn> _warm = {};
  final Map<_PreparationKey, Future<void>> _warming = {};
  final Map<_PreparationKey, _PreparationJob> _preparing = {};
  int _epoch = 0;
  int _optionalEpoch = 0;
  ReaderPublicationLifetime? _publication;
  Future<void> Function()? _cancelAndDrainMotion;
  Future<void> Function()? _disposeSourceAdapters;
  Future<void>? _closing;
  Future<void> get closed => _closing ?? Future.value();
  bool _optionalAllowed = true;
  @override
  TurnSessionState state = TurnSessionState.ready;
  TurnPosition get position => _foreground;
  ReadingUnit? get unit => (_staged ?? _current).surface.unit;

  static Future<PreparedReaderSession?> open({
    required PageSurfacePool pool,
    required PreparedSection section,
    required int pageIndex,
    required int sectionCount,
    required Future<PreparedSection?> Function(int) loadSection,
    required PagePaintTheme theme,
    AnchorProofHook? proofHook,
    Future<void> Function()? drain,
    ComposedReadingUnitNavigator? navigator,
    ServerSession? activation,
    bool Function(ServerSession)? isActivationCurrent,
    ReaderPublicationLifetime? publication,
    Future<void> Function()? cancelAndDrainMotion,
    Future<void> Function()? disposeSourceAdapters,
    FixedUnitSources? fixedSources,
  }) async {
    if (publication != null &&
        (cancelAndDrainMotion == null ||
            disposeSourceAdapters == null ||
            activation != publication.activation ||
            section.identity != publication.layout ||
            (navigator != null &&
                navigator.units.any(
                  (unit) => unit.id.content != publication.identity,
                )))) {
      throw ArgumentError(
        'Publication session requires matching owners and shutdown hooks',
      );
    }
    if ((activation == null) != (isActivationCurrent == null) ||
        (navigator != null && activation == null)) {
      throw ArgumentError(
        'Unit sessions require a captured activation and guard',
      );
    }
    bool active() =>
        (activation == null || isActivationCurrent!(activation)) &&
        (publication?.isActive ?? true);
    if (!active()) return null;
    final navigation = navigator == null
        ? null
        : PreparedUnitNavigation(navigator, loadSection);
    final unit = navigation?.unitFor(section, pageIndex);
    if (navigation != null && unit == null) return null;
    if (unit != null &&
        unit.id.content.bookKey.serverKey != activation!.serverKey) {
      return null;
    }
    final sectionPin = pool.pinSection(section);
    try {
      final position = navigation != null
          ? await navigation.positionFor(
              (unit: unit!, section: section, page: pageIndex),
              proofHook: proofHook,
              isCurrent: active,
            )
          : preparedPagePosition(
              section,
              pageIndex,
              atStart: section.sectionIndex == 0 && pageIndex == 0,
              atEnd:
                  section.sectionIndex == sectionCount - 1 &&
                  pageIndex == section.pageCount - 1,
              proofHook: proofHook,
            );
      if (position == null || !active()) return null;
      final lease = await pool.prepare(
        section,
        pageIndex,
        theme,
        unit: unit,
        typedFailures: true,
      );
      if (!active()) {
        lease?.release();
        return null;
      }
      final session = lease == null
          ? null
          : PreparedReaderSession._(
              pool,
              theme,
              sectionCount,
              loadSection,
              lease,
              position,
              proofHook,
              drain,
              navigation,
              activation,
              isActivationCurrent,
              fixedSources,
            );
      session?._publication = publication;
      session?._cancelAndDrainMotion = cancelAndDrainMotion;
      session?._disposeSourceAdapters = disposeSourceAdapters;
      return session;
    } finally {
      sectionPin.release();
    }
  }

  /// Initial fixed units use the same retained surface/session as later turns.
  /// Recomposition opens a fresh session/pool with shared admission owners and
  /// A1's replacement navigator, restoring the same source in that snapshot.
  static Future<PreparedReaderSession?> openUnit({
    required PageSurfacePool pool,
    required ReadingUnit unit,
    required ComposedReadingUnitNavigator navigator,
    required FixedUnitSources fixedSources,
    required Future<PreparedSection?> Function(int) loadSection,
    required PagePaintTheme theme,
    required ServerSession activation,
    required bool Function(ServerSession) isActivationCurrent,
    ReaderPublicationLifetime? publication,
    Future<void> Function()? cancelAndDrainMotion,
    Future<void> Function()? disposeSourceAdapters,
    PublicationCancellation? cancellation,
  }) async {
    final navigation = PreparedUnitNavigation(navigator, loadSection);
    if (unit.kind == ReadingUnitKind.reflowPage) {
      final page = await navigation.resolve(unit);
      if (page == null) return null;
      return open(
        pool: pool,
        section: page.section,
        pageIndex: page.page,
        sectionCount: navigator.sections.length,
        loadSection: loadSection,
        theme: theme,
        navigator: navigator,
        activation: activation,
        isActivationCurrent: isActivationCurrent,
        publication: publication,
        cancelAndDrainMotion: cancelAndDrainMotion,
        disposeSourceAdapters: disposeSourceAdapters,
        fixedSources: fixedSources,
      );
    }
    final layout = fixedSources.layoutFor(unit.activeSource.sectionIndex);
    if (unit.id.content.bookKey.serverKey != activation.serverKey ||
        layout.contentId != unit.id.content.sha256 ||
        navigator.viewportWidth != layout.viewportWidth ||
        navigator.viewportHeight != layout.viewportHeight ||
        !navigator.units.any(
          (u) => u.id == unit.id && u.slots.toSet().containsAll(unit.slots),
        ) ||
        (publication != null &&
            (publication.identity != unit.id.content ||
                publication.activation != activation ||
                publication.layout != layout ||
                cancelAndDrainMotion == null ||
                disposeSourceAdapters == null))) {
      throw ArgumentError(
        'Fixed session requires matching composition and owners',
      );
    }
    bool active() =>
        isActivationCurrent(activation) &&
        (publication?.isActive ?? true) &&
        !(cancellation?.isCanceled ?? false);
    if (!active()) return null;
    final token = cancellation ?? PublicationCancellation();
    final lease = await fixedSources.prepare(pool, unit, token);
    if (lease == null) return null;
    var transferred = false;
    try {
      if (!active()) return null;
      final previous = await navigator.adjacent(unit, UnitDirection.previous);
      final next = await navigator.adjacent(unit, UnitDirection.next);
      if (!active() ||
          previous is UnavailableReadingUnit ||
          next is UnavailableReadingUnit) {
        return null;
      }
      final position = fixedSources.positionFor(
        lease.surface,
        atStart:
            previous is ReadingUnitBoundary &&
            previous.boundary == UnitBoundary.start,
        atEnd: next is ReadingUnitBoundary && next.boundary == UnitBoundary.end,
      );
      if (position == null) return null;
      final session = PreparedReaderSession._(
        pool,
        theme,
        navigator.sections.length,
        loadSection,
        lease,
        position,
        null,
        null,
        navigation,
        activation,
        isActivationCurrent,
        fixedSources,
      );
      session._publication = publication;
      session._cancelAndDrainMotion = cancelAndDrainMotion;
      session._disposeSourceAdapters = disposeSourceAdapters;
      transferred = true;
      return session;
    } finally {
      if (!transferred) lease.release();
    }
  }

  Future<({PreparedSection section, int page, ReadingUnit? unit})?> _adjacent(
    TurnPosition origin,
    TurnDirection direction,
  ) async {
    final epoch = _epoch;
    bool current() =>
        _active && epoch == _epoch && _foreground.sameOrigin(origin);
    final navigation = unitNavigation;
    if (navigation != null) {
      final source = unit;
      if (source == null) return null;
      final result = await navigation.navigator.adjacent(
        source,
        _unitDirection(direction),
      );
      if (!current() || result is! LocatedReadingUnit) return null;
      return navigation.resolve(
        result.unit,
        available: _current.surface.reflowSection,
        isCurrent: current,
      );
    }
    // Compatibility for the old probe entry point, which has no full content
    // identity/composition. New publication callers must supply A1's navigator.
    final delta = direction == TurnDirection.next ? 1 : -1;
    var section = _current.surface.section;
    if (section.sectionIndex != origin.sectionIndex) {
      final loaded = await loadSection(origin.sectionIndex);
      if (!current() || loaded == null) return null;
      section = loaded;
    }
    final page = origin.pageIndex + delta;
    if (page >= 0 && page < section.pageCount) {
      return (section: section, page: page, unit: null);
    }
    final index = origin.sectionIndex + delta;
    if (index < 0 || index >= sectionCount) return null;
    final loaded = await loadSection(index);
    return !current() || loaded == null
        ? null
        : (
            section: loaded,
            page: delta > 0 ? 0 : loaded.pageCount - 1,
            unit: null,
          );
  }

  UnitDirection _unitDirection(TurnDirection direction) =>
      direction == TurnDirection.next
      ? UnitDirection.next
      : UnitDirection.previous;

  /// Candidates use A1 lookup, then exactly the same surface/proof/accept path
  /// as a turn. A TOC hit alone never updates the accepted foreground.
  Future<PreparedTurn?> prepareTocTarget(TurnPosition origin, String href) {
    ReaderWorkGuard.check(ReaderWork.surfacePreparation);
    final navigation = unitNavigation;
    if (navigation == null) return Future.value();
    return _prepareLocated(origin, navigation.navigator.forTocTarget(href));
  }

  Future<PreparedTurn?> prepareSourcePosition(
    TurnPosition origin,
    SourcePageId page,
    SourcePosition position,
  ) {
    ReaderWorkGuard.check(ReaderWork.surfacePreparation);
    final navigation = unitNavigation;
    if (navigation == null) return Future.value();
    return _prepareLocated(
      origin,
      navigation.navigator.forSourcePosition(page, position),
    );
  }

  Future<PreparedTurn?> _prepareLocated(
    TurnPosition origin,
    Future<UnitNavigationResult> lookup,
  ) async {
    final epoch = _epoch;
    final result = await lookup;
    if (!_active ||
        epoch != _epoch ||
        !_foreground.sameOrigin(origin) ||
        result is! LocatedReadingUnit) {
      return null;
    }
    final units = unitNavigation!.navigator.units;
    final from = units.indexWhere((u) => u.id == unit?.id);
    final to = units.indexWhere((u) => u.id == result.unit.id);
    if (from < 0 || to < 0) return null;
    return _prepareShared(
      origin,
      to < from ? TurnDirection.previous : TurnDirection.next,
      targetUnit: result.unit,
    );
  }

  @override
  Future<PreparedTurn?> prepare(
    TurnPosition origin,
    TurnDirection direction, {
    PublicationCancellation? cancellation,
  }) {
    ReaderWorkGuard.check(ReaderWork.surfacePreparation);
    if (!_active ||
        (cancellation?.isCanceled ?? false) ||
        !_foreground.sameOrigin(origin)) {
      return Future.value();
    }
    final work = _prepareShared(origin, direction);
    if (cancellation == null) return work;
    final done = Completer<PreparedTurn?>();
    final unsubscribe = cancellation.listen(() {
      if (!done.isCompleted) done.complete();
    });
    work.then(
      (preview) {
        unsubscribe();
        if (done.isCompleted) {
          preview?.release();
        } else {
          done.complete(preview);
        }
      },
      onError: (Object error, StackTrace stack) {
        unsubscribe();
        if (!done.isCompleted) done.completeError(error, stack);
      },
    );
    return done.future;
  }

  _PreparationKey _key(
    TurnPosition origin,
    TurnDirection direction, [
    ReadingUnit? target,
  ]) => (
    epoch: _epoch,
    layout: origin.layoutKey,
    generation: origin.layoutGeneration,
    page: origin.pageIdentity,
    section: origin.sectionIndex,
    index: origin.pageIndex,
    count: origin.pageCount,
    cfi: origin.cfi,
    direction: direction,
    target: target,
  );

  Future<PreparedTurn?> _prepareShared(
    TurnPosition origin,
    TurnDirection direction, {
    ReadingUnit? targetUnit,
  }) async {
    final cached = targetUnit == null ? ready(origin, direction) : null;
    if (cached != null) return cached;
    // A completed warm or direct consumer may still own this exact result.
    // Reuse its surface with a new reference, including after the job drained.
    for (final entry in _previews.entries) {
      final preview = entry.key;
      if (_previewEpochs[preview] == _epoch &&
          preview.origin.sameOrigin(origin) &&
          preview.direction == direction &&
          _previewTargets[preview] == targetUnit) {
        return _retainPreview(
          origin,
          direction,
          preview.target,
          entry.value,
          _epoch,
          targetUnit,
        );
      }
    }
    final key = _key(origin, direction, targetUnit);
    final job = _preparing.putIfAbsent(key, () {
      _failures.remove(key);
      final job = _PreparationJob();
      job.result = _buildSurface(
        origin,
        direction,
        key.epoch,
        targetUnit: targetUnit,
      );
      return job;
    });
    job.waiters++;
    ({TurnPosition position, PageSurfaceLease lease})? result;
    try {
      result = await job.result;
      if (result == null ||
          key.epoch != _epoch ||
          !_active ||
          !_foreground.sameOrigin(origin)) {
        return null;
      }
      return _retainPreview(
        origin,
        direction,
        result.position,
        result.lease,
        key.epoch,
        targetUnit,
      );
    } on Object catch (error) {
      if (error is PreparationCancelled || error is ProcessFontLoadCanceled) {
        return null;
      }
      final failure = ReaderPreparationFailure.from(error);
      if (failure == null) rethrow;
      if (_active && key.epoch == _epoch && _foreground.sameOrigin(origin)) {
        _failures[key] = failure;
        lastFailure = failure;
      }
      return null;
    } finally {
      if (--job.waiters == 0) {
        _preparing.remove(key);
        result?.lease.release();
      }
    }
  }

  PreparedTurn _retainPreview(
    TurnPosition origin,
    TurnDirection direction,
    TurnPosition position,
    PageSurfaceLease source,
    int epoch,
    ReadingUnit? targetUnit,
  ) {
    final lease = source.retain();
    late final PreparedTurn preview;
    preview = PreparedTurn(
      origin: origin,
      target: position,
      direction: direction,
      releaseCallback: () {
        _previewEpochs.remove(preview);
        _previewTargets.remove(preview);
        _previews.remove(preview)?.release();
      },
    );
    _previews[preview] = lease;
    _previewEpochs[preview] = epoch;
    _previewTargets[preview] = targetUnit;
    return preview;
  }

  Future<({TurnPosition position, PageSurfaceLease lease})?> _buildSurface(
    TurnPosition origin,
    TurnDirection direction,
    int epoch, {
    ReadingUnit? targetUnit,
  }) async {
    final navigation = unitNavigation;
    if (navigation != null && targetUnit == null) {
      final source = unit;
      if (source == null) return null;
      final result = await navigation.navigator.adjacent(
        source,
        _unitDirection(direction),
      );
      if (!_active ||
          epoch != _epoch ||
          !_foreground.sameOrigin(origin) ||
          result is! LocatedReadingUnit) {
        return null;
      }
      targetUnit = result.unit;
    }
    if (targetUnit != null && targetUnit.kind != ReadingUnitKind.reflowPage) {
      return _buildFixedSurface(origin, targetUnit, epoch);
    }
    final target = targetUnit == null
        ? await _adjacent(origin, direction)
        : await unitNavigation!.resolve(
            targetUnit,
            available: _current.surface.reflowSection,
            isCurrent: () =>
                _active && epoch == _epoch && _foreground.sameOrigin(origin),
          );
    if (target == null ||
        !_active ||
        epoch != _epoch ||
        !_foreground.sameOrigin(origin)) {
      return null;
    }
    final identity = target.section.identity;
    final currentIdentity = _current.surface.layout;
    if (identity.contentId != currentIdentity.contentId ||
        identity.generation != origin.layoutGeneration ||
        identity.viewportWidth != currentIdentity.viewportWidth ||
        identity.viewportHeight != currentIdentity.viewportHeight ||
        identity.devicePixelRatio != currentIdentity.devicePixelRatio ||
        identity.settings != currentIdentity.settings ||
        identity.styleVersion != currentIdentity.styleVersion) {
      return null;
    }
    final sectionPin = pool.pinSection(target.section);
    try {
      final position = target.unit != null
          ? await unitNavigation!.positionFor(
              (unit: target.unit!, section: target.section, page: target.page),
              proofHook: proofHook,
              isCurrent: () =>
                  _active && epoch == _epoch && _foreground.sameOrigin(origin),
            )
          : preparedPagePosition(
              target.section,
              target.page,
              atStart: target.section.sectionIndex == 0 && target.page == 0,
              atEnd:
                  target.section.sectionIndex == sectionCount - 1 &&
                  target.page == target.section.pageCount - 1,
              proofHook: proofHook,
            );
      if (position == null) return null;
      if (!_active || epoch != _epoch || !_foreground.sameOrigin(origin)) {
        return null;
      }
      final lease = await pool.prepare(
        target.section,
        target.page,
        theme,
        unit: target.unit,
        typedFailures: true,
      );
      if (lease == null) return null;
      if (!_active || epoch != _epoch || !_foreground.sameOrigin(origin)) {
        lease.release();
        return null;
      }
      return (position: position, lease: lease);
    } finally {
      sectionPin.release();
    }
  }

  Future<({TurnPosition position, PageSurfaceLease lease})?> _buildFixedSurface(
    TurnPosition origin,
    ReadingUnit target,
    int epoch,
  ) async {
    bool current() =>
        _active && epoch == _epoch && _foreground.sameOrigin(origin);
    final sources = fixedSources;
    if (sources == null) {
      throw FixedPreparationFailure(
        UnsupportedSectionCapability(
          sectionIndex: target.activeSource.sectionIndex,
          reason: 'Fixed source ownership was not supplied to the session',
          constructs: [
            OffendingConstruct(
              kind: CapabilityConstructKind.layout,
              identifier: 'fixed-source-required',
            ),
          ],
        ),
      );
    }
    final identity = sources.layoutFor(target.activeSource.sectionIndex);
    final previousIdentity = _current.surface.layout;
    if (identity.contentId != previousIdentity.contentId ||
        identity.generation != origin.layoutGeneration ||
        identity.viewportWidth != previousIdentity.viewportWidth ||
        identity.viewportHeight != previousIdentity.viewportHeight ||
        identity.devicePixelRatio != previousIdentity.devicePixelRatio ||
        identity.settings != previousIdentity.settings ||
        identity.styleVersion != previousIdentity.styleVersion) {
      return null;
    }
    final token = PublicationCancellation();
    _fixedWork.add(token);
    PageSurfaceLease? lease;
    var transferred = false;
    try {
      lease = await sources.prepare(pool, target, token);
      if (lease == null || !current()) return null;
      final previous = await unitNavigation!.navigator.adjacent(
        target,
        UnitDirection.previous,
      );
      final next = await unitNavigation!.navigator.adjacent(
        target,
        UnitDirection.next,
      );
      if (!current() ||
          previous is UnavailableReadingUnit ||
          next is UnavailableReadingUnit) {
        return null;
      }
      final position = sources.positionFor(
        lease.surface,
        atStart:
            previous is ReadingUnitBoundary &&
            previous.boundary == UnitBoundary.start,
        atEnd: next is ReadingUnitBoundary && next.boundary == UnitBoundary.end,
      );
      if (position == null) return null;
      transferred = true;
      return (position: position, lease: lease);
    } finally {
      _fixedWork.remove(token);
      if (!transferred) lease?.release();
    }
  }

  Future<void> warm(TurnDirection direction) {
    ReaderWorkGuard.check(ReaderWork.surfacePreparation);
    final stale = _warm[direction];
    if (stale != null && _previewEpochs[stale] != _epoch) {
      _warm.remove(direction)?.release();
    }
    if (!_active || !_optionalAllowed || _warm.containsKey(direction)) {
      return Future<void>.value();
    }
    final origin = _foreground;
    final key = _key(origin, direction);
    return _warming.putIfAbsent(
      key,
      () => _warmDirection(origin, direction, key, _optionalEpoch),
    );
  }

  Future<void> _warmDirection(
    TurnPosition origin,
    TurnDirection direction,
    _PreparationKey key,
    int optionalEpoch,
  ) async {
    try {
      final preview = await prepare(origin, direction);
      if (preview == null) return;
      if (!_active ||
          !_foreground.sameOrigin(origin) ||
          key.epoch != _epoch ||
          !_optionalAllowed ||
          optionalEpoch != _optionalEpoch) {
        preview.release();
        return;
      }
      _warm[direction] = preview;
    } finally {
      // This job is completing; removing it must not await its own future.
      unawaited(_warming.remove(key));
    }
  }

  @override
  PreparedTurn? ready(TurnPosition origin, TurnDirection direction) {
    if (!_active || !_foreground.sameOrigin(origin)) {
      return null;
    }
    final preview = _warm.remove(direction);
    if (preview != null &&
        (!preview.origin.sameOrigin(origin) ||
            _previewEpochs[preview] != _epoch)) {
      preview.release();
      return null;
    }
    return preview;
  }

  @override
  Future<void> stopAndDrain() async {
    await drain?.call();
    // Physical work remains owned even when a logical waiter cancels. Do not
    // cross the motion barrier until every captured preparation has drained.
    while (_preparing.isNotEmpty) {
      await Future.wait(
        _preparing.values.map(
          (job) => job.result.then<void>((_) {}, onError: (Object _) {}),
        ),
      );
    }
  }

  @override
  void optionalWorkAllowed(bool allowed) {
    if (_optionalAllowed == allowed) return;
    _optionalAllowed = allowed;
    _optionalEpoch++;
  }

  /// Called when the owning reader/layout generation retires, including an
  /// A -> B -> A invalidation whose visible origin happens to compare equal.
  /// Numeric invalidation is safe in callbacks; unbind releases warm owners
  /// later in the controller's ordinary control task.
  @override
  void invalidatePreparation() {
    _epoch++;
    _failures.clear();
    for (final token in _fixedWork.toList()) {
      token.cancel();
    }
  }

  @override
  void bind(TurnPosition origin, List<PreparedTurn> neighbors) {
    if (!_active) return;
    PreparedPageSurface? previous;
    PreparedPageSurface? next;
    for (final preview in neighbors) {
      final surface = _previews[preview]?.surface;
      if (preview.direction == TurnDirection.previous) {
        previous = surface;
      } else {
        next = surface;
      }
    }
    frames.value = SurfaceFrame(
      current: _current.surface,
      previous: previous,
      next: next,
    );
  }

  @override
  void unbind() {
    if (state == TurnSessionState.closed) return;
    invalidatePreparation();
    for (final preview in _warm.values) {
      preview.release();
    }
    _warm.clear();
    final staged = _staged;
    _staged = null;
    if (staged != null && _stagedAccepted && _active) {
      final old = _current;
      _current = staged;
      frames.value = SurfaceFrame(current: _current.surface);
      old.release();
    } else {
      staged?.release();
      frames.value = SurfaceFrame(current: _current.surface);
    }
    _stagedAccepted = false;
  }

  @override
  Future<TurnNavigation> navigate(
    TurnPosition origin,
    TurnDirection direction,
    PreparedTurn? preview,
  ) async {
    if (!_active) {
      return const TurnNavigation(TurnNavigationKind.cancelled);
    }
    if (!_foreground.sameOrigin(origin)) {
      return const TurnNavigation(
        TurnNavigationKind.mismatch,
        reason: 'origin',
      );
    }
    final candidate = preview ?? await prepare(origin, direction);
    if (candidate == null) {
      if (!_active || !_foreground.sameOrigin(origin)) {
        return const TurnNavigation(TurnNavigationKind.cancelled);
      }
      final failure = _failures[_key(origin, direction)];
      if (failure != null) {
        return TurnNavigation(TurnNavigationKind.failed, failure: failure);
      }
      final navigation = unitNavigation;
      final source = unit;
      if (navigation != null && source != null) {
        final epoch = _epoch;
        final result = await navigation.navigator.adjacent(
          source,
          _unitDirection(direction),
        );
        if (!_active || epoch != _epoch || !_foreground.sameOrigin(origin)) {
          return const TurnNavigation(TurnNavigationKind.cancelled);
        }
        if (result is ReadingUnitBoundary) {
          return TurnNavigation(
            TurnNavigationKind.boundary,
            reason: result.boundary.name,
          );
        }
      }
      return const TurnNavigation(TurnNavigationKind.unavailable);
    }
    if (!_active ||
        !_foreground.sameOrigin(origin) ||
        candidate.released ||
        _previewEpochs[candidate] != _epoch ||
        !candidate.origin.sameOrigin(origin) ||
        candidate.direction != direction) {
      if (preview == null) candidate.release();
      return const TurnNavigation(TurnNavigationKind.cancelled);
    }
    final lease = _previews[candidate];
    if (lease == null) {
      return const TurnNavigation(TurnNavigationKind.unavailable);
    }
    _staged?.release();
    _stagedAccepted = false;
    _staged = lease.retain();
    _foreground = candidate.target;
    if (preview == null) candidate.release();
    return TurnNavigation.verified(_foreground);
  }

  @override
  Future<bool> prove(TurnPosition position, {PreparedTurn? preview}) async {
    if (!_active) return false;
    final surface = (_staged ?? _current).surface;
    if (surface.reflowSection == null) {
      return fixedSources?.prove(
            surface,
            position,
            anchor: preview?.target.cfi,
          ) ??
          false;
    }
    final section = surface.section;
    return provePreparedPosition(section, position, proofHook: proofHook) &&
        (preview == null ||
            provePreparedPosition(
              section,
              position,
              anchor: preview.target.cfi,
              proofHook: proofHook,
            ));
  }

  @override
  void accept(TurnPosition position) {
    if (!_active || !_foreground.sameOrigin(position)) {
      throw StateError('Unproven handoff');
    }
    _stagedAccepted = true;
    lastFailure = null;
  }

  @override
  Future<bool> restore(TurnPosition origin) async {
    if (!_active) return false;
    _staged?.release();
    _staged = null;
    _stagedAccepted = false;
    final surface = _current.surface;
    final proven = surface.reflowSection == null
        ? fixedSources?.prove(surface, origin) ?? false
        : provePreparedPosition(surface.section, origin, proofHook: proofHook);
    if (!proven) {
      return false;
    }
    _foreground = origin;
    return true;
  }

  void close() {
    if (state == TurnSessionState.closed) return;
    state = TurnSessionState.closed;
    invalidatePreparation();
    pool.close();
    final publication = _publication;
    if (publication != null) {
      _closing = publication.close(
        disableAndInvalidate: () {},
        cancelAndDrain: () async {
          await _cancelAndDrainMotion!();
          await stopAndDrain();
        },
        disposeScenesAndSources: () async {
          _disposeSurfaces();
          await pool.drained;
          await _disposeSourceAdapters!();
        },
      );
    } else {
      _disposeSurfaces();
      _closing = stopAndDrain();
    }
  }

  void _disposeSurfaces() {
    _staged?.release();
    _staged = null;
    for (final preview in _previews.keys.toList()) {
      preview.release();
    }
    _warm.clear();
    _current.release();
    frames.dispose();
  }
}
