import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';
import 'package:shiori/features/reader/engine/motion/page_turn_engine.dart';
import 'package:shiori/features/reader/engine/motion/turn_session.dart';
import 'package:shiori/features/reader/engine/pagination/anchor.dart';
import 'package:shiori/features/reader/engine/pagination/page_painter.dart';
import 'package:shiori/features/reader/engine/pagination/prepared_section.dart';
import 'package:shiori/features/reader/engine/surface/page_surface_pool.dart';
import 'package:shiori/features/reader/engine/surface/prepared_page_position.dart';
import 'package:shiori/features/reader/engine/surface/surface_frame.dart';

/// Prepared sections are borrowed from the caller's bounded preparation owner.
/// This session owns all page pictures and leases, including the handoff cover.
final class PreparedReaderSession implements TurnSession {
  PreparedReaderSession._(
    this.pool,
    this.theme,
    this.sectionCount,
    this.loadSection,
    this._current,
    this._foreground,
    this.proofHook,
    this.drain,
  ) : frames = ValueNotifier(SurfaceFrame(current: _current.surface));
  final PageSurfacePool pool;
  final PagePaintTheme theme;
  final int sectionCount;
  final Future<PreparedSection?> Function(int) loadSection;
  final AnchorProofHook? proofHook;
  final Future<void> Function()? drain;
  final ValueNotifier<SurfaceFrame> frames;
  PageSurfaceLease _current;
  TurnPosition _foreground;
  PageSurfaceLease? _staged;
  bool _stagedAccepted = false;
  final Map<PreparedTurn, PageSurfaceLease> _previews = {};
  final Map<TurnDirection, PreparedTurn> _warm = {};
  final Map<TurnDirection, Future<void>> _warming = {};
  @override
  TurnSessionState state = TurnSessionState.ready;
  TurnPosition get position => _foreground;

  static Future<PreparedReaderSession?> open({
    required PageSurfacePool pool,
    required PreparedSection section,
    required int pageIndex,
    required int sectionCount,
    required Future<PreparedSection?> Function(int) loadSection,
    required PagePaintTheme theme,
    AnchorProofHook? proofHook,
    Future<void> Function()? drain,
  }) async {
    final position = preparedPagePosition(
      section,
      pageIndex,
      atStart: section.sectionIndex == 0 && pageIndex == 0,
      atEnd:
          section.sectionIndex == sectionCount - 1 &&
          pageIndex == section.pageCount - 1,
      proofHook: proofHook,
    );
    if (position == null) return null;
    final lease = await pool.prepare(section, pageIndex, theme);
    return lease == null
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
          );
  }

  Future<({PreparedSection section, int page})?> _adjacent(
    TurnPosition origin,
    TurnDirection direction,
  ) async {
    final delta = direction == TurnDirection.next ? 1 : -1;
    var section = _current.surface.section;
    if (section.sectionIndex != origin.sectionIndex) {
      final loaded = await loadSection(origin.sectionIndex);
      if (loaded == null) return null;
      section = loaded;
    }
    final page = origin.pageIndex + delta;
    if (page >= 0 && page < section.pageCount) {
      return (section: section, page: page);
    }
    final index = origin.sectionIndex + delta;
    if (index < 0 || index >= sectionCount) return null;
    final loaded = await loadSection(index);
    return loaded == null
        ? null
        : (section: loaded, page: delta > 0 ? 0 : loaded.pageCount - 1);
  }

  @override
  Future<PreparedTurn?> prepare(
    TurnPosition origin,
    TurnDirection direction,
  ) async {
    ReaderWorkGuard.check(ReaderWork.surfacePreparation);
    final cached = ready(origin, direction);
    if (cached != null) return cached;
    final target = await _adjacent(origin, direction);
    if (target == null || state == TurnSessionState.closed) return null;
    final position = preparedPagePosition(
      target.section,
      target.page,
      atStart: target.section.sectionIndex == 0 && target.page == 0,
      atEnd:
          target.section.sectionIndex == sectionCount - 1 &&
          target.page == target.section.pageCount - 1,
      proofHook: proofHook,
    );
    if (position == null) return null;
    final lease = await pool.prepare(target.section, target.page, theme);
    if (lease == null) return null;
    if (state == TurnSessionState.closed) {
      lease.release();
      return null;
    }
    late final PreparedTurn preview;
    preview = PreparedTurn(
      origin: origin,
      target: position,
      direction: direction,
      releaseCallback: () {
        _previews.remove(preview)?.release();
      },
    );
    _previews[preview] = lease;
    return preview;
  }

  Future<void> warm(TurnDirection direction) {
    if (state == TurnSessionState.closed || _warm.containsKey(direction)) {
      return Future<void>.value();
    }
    return _warming.putIfAbsent(direction, () => _warmDirection(direction));
  }

  Future<void> _warmDirection(TurnDirection direction) async {
    final origin = _foreground;
    try {
      final preview = await prepare(origin, direction);
      if (preview == null) return;
      if (state == TurnSessionState.closed || !_foreground.sameOrigin(origin)) {
        preview.release();
        return;
      }
      _warm[direction] = preview;
    } finally {
      // This job is completing; removing it must not await its own future.
      unawaited(_warming.remove(direction));
    }
  }

  @override
  PreparedTurn? ready(TurnPosition origin, TurnDirection direction) {
    final preview = _warm.remove(direction);
    if (preview != null && !preview.origin.sameOrigin(origin)) {
      preview.release();
      return null;
    }
    return preview;
  }

  @override
  Future<void> stopAndDrain() async {
    await drain?.call();
  }

  @override
  void optionalWorkAllowed(bool allowed) {}
  @override
  void bind(TurnPosition origin, List<PreparedTurn> neighbors) {
    if (state == TurnSessionState.closed) return;
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
    final staged = _staged;
    _staged = null;
    if (staged != null && _stagedAccepted) {
      final old = _current;
      _current = staged;
      frames.value = SurfaceFrame(current: _current.surface);
      old.release();
    } else {
      staged?.release();
      frames.value = SurfaceFrame(current: _current.surface);
    }
    _stagedAccepted = false;
    for (final preview in _warm.values) {
      preview.release();
    }
    _warm.clear();
  }

  @override
  Future<TurnNavigation> navigate(
    TurnPosition origin,
    TurnDirection direction,
    PreparedTurn? preview,
  ) async {
    if (state == TurnSessionState.closed) {
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
      return const TurnNavigation(TurnNavigationKind.unavailable);
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
    if (state == TurnSessionState.closed) return false;
    final section = (_staged ?? _current).surface.section;
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
    if (!_foreground.sameOrigin(position)) throw StateError('Unproven handoff');
    _stagedAccepted = true;
  }

  @override
  Future<bool> restore(TurnPosition origin) async {
    if (state == TurnSessionState.closed) return false;
    _staged?.release();
    _staged = null;
    _stagedAccepted = false;
    if (!provePreparedPosition(
      _current.surface.section,
      origin,
      proofHook: proofHook,
    )) {
      return false;
    }
    _foreground = origin;
    return true;
  }

  void close() {
    if (state == TurnSessionState.closed) return;
    state = TurnSessionState.closed;
    _staged?.release();
    _staged = null;
    for (final preview in _previews.keys.toList()) {
      preview.release();
    }
    _warm.clear();
    _current.release();
    frames.dispose();
    pool.close();
  }
}
