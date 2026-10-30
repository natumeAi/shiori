import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/features/diagnostics/data/book_digest.dart';
import 'package:shiori/features/diagnostics/data/probe_book_repository.dart';
import 'package:shiori/features/diagnostics/data/probe_turn_session.dart';
import 'package:shiori/features/diagnostics/data/reader_preparation_repository.dart';
import 'package:shiori/features/diagnostics/data/reader_probe_recorder.dart';
import 'package:shiori/features/diagnostics/presentation/reader_probe/scenario_target.dart';
import 'package:shiori/features/library/data/publications/prepare_book_queue.dart';
import 'package:shiori/features/library/data/publications/prepare_book_service.dart';
import 'package:shiori/features/library/data/publications/prepared_book.dart';
import 'package:shiori/features/library/data/publications/publication_lease.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/data/cfi/cfi.dart';
import 'package:shiori/features/reader/data/layout/reading_unit.dart';
import 'package:shiori/features/reader/data/layout/reading_unit_navigator.dart';
import 'package:shiori/features/reader/data/layout/source_page_slot.dart';
import 'package:shiori/features/reader/data/worker/publication_worker.dart';
import 'package:shiori/features/reader/engine/layout/font_registry.dart';
import 'package:shiori/features/reader/engine/layout/layout_model.dart';
import 'package:shiori/features/reader/engine/motion/page_turn_engine.dart';
import 'package:shiori/features/reader/engine/motion/reader_turn_controller.dart';
import 'package:shiori/features/reader/engine/motion/turn_clock.dart';
import 'package:shiori/features/reader/engine/motion/turn_session.dart';
import 'package:shiori/features/reader/engine/pagination/anchor.dart';
import 'package:shiori/features/reader/engine/pagination/layout_identity.dart';
import 'package:shiori/features/reader/engine/pagination/page_painter.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';
import 'package:shiori/features/reader/engine/support/unsupported_layout.dart';
import 'package:shiori/features/reader/engine/surface/page_surface_pool.dart';
import 'package:shiori/features/reader/engine/surface/prepared_reader_session.dart';
import 'package:shiori/features/reader/engine/surface/publication_fixed_composition.dart';
import 'package:shiori/features/reader/engine/surface/publication_fixed_sources.dart';

/// Route-owned preparation result. The opening path releases [book] after it
/// has acquired its own independent cache lease.
final class ReaderProbePreparation {
  const ReaderProbePreparation({
    required this.book,
    required this.session,
    required this.service,
  });
  final PreparedBook book;
  final ServerSession session;
  final PrepareBookService service;
}

/// Obtains the server publication through the S3 service before any reader
/// owner exists. Callers release [ReaderProbePreparation.book] after opening.
Future<ReaderProbePreparation> prepareProbeBook({
  required BookKey key,
  required ServerSession session,
  required PrepareBookService service,
}) async {
  if (key.serverKey != session.serverKey) {
    throw ArgumentError('Probe book belongs to another server session');
  }
  final prepared = await service.prepare(key);
  return ReaderProbePreparation(
    book: prepared,
    session: session,
    service: service,
  );
}

/// Probe-local session control. No provider is invalidated by ticks or turns.
final class ReaderProbeController extends ChangeNotifier
    implements ScenarioTarget {
  ReaderProbeController(
    this.recorder, {
    Future<EpubBook> Function(Uint8List)? openBook,
    TurnClock Function()? clockFactory,
  }) : _openBook = openBook ?? ((bytes) => compute(_open, bytes)),
       _clockFactory = clockFactory ?? StopwatchTurnClock.new;
  final ReaderProbeRecorder recorder;
  final Future<EpubBook> Function(Uint8List) _openBook;
  final TurnClock Function() _clockFactory;
  ProbeBook? identity;
  EpubBook? _book;
  ReaderPreparationRepository? _owner;
  PublicationFixedComposition? _fixedComposition;
  PublicationFixedSources? _fixedSources;
  Future<bool> Function(int, int, String?, ReaderSettings)? _replacePublication;
  Future<void>? _publicationRetirement;
  PreparedReaderSession? session;
  ProbeTurnSession? _proxy;
  ReaderTurnController? turn;
  ReaderSettings _settings = const ReaderSettings();
  ReaderSettings? _pendingSettings;
  Object? _reflowRequest;
  ReaderSettings get settings => _pendingSettings ?? _settings;
  bool get canReplacePublication => _replacePublication != null;
  set settings(ReaderSettings value) {
    if (settings == value) return;
    _settings = value;
    if (_pendingSettings != null) _pendingSettings = value;
    ++_generation;
  }

  bool reducedMotion = false;
  double _width = 400, _height = 600, _dpr = 1;
  double get width => _width;
  set width(double value) {
    if (_width == value) return;
    _width = value;
    ++_generation;
  }

  double get height => _height;
  set height(double value) {
    if (_height == value) return;
    _height = value;
    ++_generation;
  }

  double get dpr => _dpr;
  set dpr(double value) {
    if (_dpr == value) return;
    _dpr = value;
    ++_generation;
  }

  int _generation = 0;
  bool _closed = false;
  final accepted = ValueNotifier<TurnPosition?>(null);
  @override
  int get sectionCount =>
      _fixedComposition?.navigator.sections.length ??
      _book?.sections.length ??
      0;
  @override
  int get pageCount {
    final current = session?.frames.value.current;
    if (current == null) return 0;
    return current.reflowSection?.pageCount ?? 1;
  }

  @override
  bool get atEnd => turn?.accepted.atEnd ?? true;

  static EpubBook _open(Uint8List bytes) {
    final book = EpubBook.open(bytes);
    detectBookLayout(book).requireSupported();
    return book;
  }

  Future<void> open(ProbeBook book) async {
    _pendingSettings = null;
    _reflowRequest = null;
    final token = ++_generation;
    final bytes = await book.read();
    if (_closed || token != _generation) return;
    if (sha256Hex(bytes) != book.sha256) throw const ParseException();
    final opened = await _openBook(bytes);
    if (_closed || token != _generation) {
      opened.archive.close();
      return;
    }
    try {
      await _replace(0, 0, cold: true, nextBook: opened, nextIdentity: book);
    } on Object {
      if (_book != opened) opened.archive.close();
      rethrow;
    }
  }

  /// Opens a prepared publication that contains fixed sections through the
  /// same session. Mixed books retain reflow sections on the existing reflow
  /// path; a reflow-only publication is left to [open]. The route's
  /// [PreparedBook] may be released after this returns.
  Future<bool> openPublication({
    required PreparedBook book,
    required ServerSession activation,
    required bool Function(ServerSession) isCurrent,
    required Future<PublicationLease?> Function() acquireLease,
    required PrepareBookQueue queue,
    required Future<PublicationWorker> Function() worker,
    FontRegistry? fonts,
    int section = 0,
    int page = 0,
    String? restoreCfi,
    ReaderSettings? nextSettings,
    ProbeBook? captureIdentity,
  }) async {
    if (_closed || !hasFixedSections(book.layoutFacts)) return false;
    final token = ++_generation;
    final requestWidth = width, requestHeight = height, requestDpr = dpr;
    final requestSettings = nextSettings ?? settings;
    bool requestCurrent() =>
        !_closed && token == _generation && isCurrent(activation);
    var published = false;
    bool publicationCurrent() =>
        isCurrent(activation) && (published || requestCurrent());
    final identity = book.identity;
    final fact = book.layoutFacts;
    final registry = fonts ?? FontRegistry();
    LayoutIdentity fixedLayout(int index) => fixedSectionLayout(
      identity: identity,
      section: index,
      viewportWidth: requestWidth,
      viewportHeight: requestHeight,
      devicePixelRatio: requestDpr,
      settings: requestSettings,
    );
    final pool = PageSurfacePool();
    PublicationFixedSources? sources;
    PublicationFixedComposition? composition;
    PreparedReaderSession? candidate;
    ReaderTurnController? candidateTurn;
    try {
      if (!requestCurrent()) return false;
      // A lifetime holds the shared queue until its worker detaches. Retire
      // the old display and drain that reservation before requesting another.
      await _retireForPublication();
      if (!requestCurrent()) return false;
      sources = await PublicationFixedSources.open(
        preparedBook: book,
        activation: activation,
        layout: fixedLayout(section),
        isCurrent: publicationCurrent,
        acquireLease: acquireLease,
        queue: queue,
        worker: worker,
        pool: pool,
        fonts: registry,
        layoutFor: fixedLayout,
        sectionBaseFor: (page) =>
            sources!.book.sections[page.sectionIndex].spine.cfiBase,
      );
      if (!requestCurrent()) return false;
      composition = await PublicationFixedComposition.prepare(
        pool: pool,
        book: sources.book,
        identity: identity,
        facts: fact,
        settings: requestSettings,
        viewportWidth: requestWidth,
        viewportHeight: requestHeight,
        devicePixelRatio: requestDpr,
        fixedLayout: fixedLayout,
        fonts: registry,
      );
      if (!requestCurrent()) return false;
      final navigator = composition.navigator;
      final targetIndex = section < 0
          ? 0
          : section.clamp(0, navigator.sections.length - 1);
      final targets = navigator.units
          .where(
            (unit) => unit.slots.whereType<RealSourcePageSlot>().any(
              (slot) => slot.page.sectionIndex == targetIndex,
            ),
          )
          .toList();
      final targetPage = restoreCfi != null
          ? 0
          : page < 0
          ? targets.length - 1
          : page;
      if (targetPage < 0 || targetPage >= targets.length) {
        throw const ParseException();
      }
      var target = targets[targetPage];
      final sourcePage = target.slots
          .whereType<RealSourcePageSlot>()
          .firstWhere((slot) => slot.page.sectionIndex == targetIndex)
          .page;
      if (restoreCfi != null) {
        final located = await navigator.forSourcePosition(
          sourcePage,
          Cfi.resolve(composition.documents[sourcePage]!, restoreCfi).start,
        );
        if (!requestCurrent()) return false;
        if (located is! LocatedReadingUnit) throw const ParseException();
        target = located.unit;
      }
      final unit = ReadingUnit(
        id: target.id,
        kind: target.kind,
        slots: target.slots,
        activeSource: sourcePage,
      );
      candidate = await PreparedReaderSession.openUnit(
        pool: pool,
        unit: unit,
        navigator: navigator,
        fixedSources: sources.unitSources,
        loadSection: composition.loadReflow,
        theme: PagePaintTheme(background: requestSettings.theme.background),
        activation: activation,
        isActivationCurrent: (_) => publicationCurrent(),
        publication: sources.publication,
        cancelAndDrainMotion: () async {
          await candidateTurn?.closeAndDrain();
        },
        disposeSourceAdapters: () async {
          composition?.dispose();
          await composition?.drain();
          await sources?.disposeBook();
        },
      );
      if (candidate == null || !requestCurrent()) return false;
      final proxy = ProbeTurnSession(candidate);
      candidateTurn = ReaderTurnController(
        session: proxy,
        initial: candidate.position,
        clock: _clockFactory(),
        width: requestWidth,
        timing: recorder,
        onAccepted: (p) => accepted.value = p,
      );
      candidateTurn.configure(reducedMotion: reducedMotion);
      if (!requestCurrent()) return false;
      _fixedComposition = composition;
      _fixedSources = sources;
      _book = null;
      this.identity = ProbeBook(
        sha256: identity.sha256,
        fixtureId: captureIdentity?.sha256 == identity.sha256
            ? captureIdentity?.fixtureId
            : null,
        read: () => File(book.lease.local.path).readAsBytes(),
      );
      _settings = requestSettings;
      final summary = book.publication;
      _replacePublication = (section, page, cfi, value) async {
        final token = ++_generation;
        // The route has released its PreparedBook. Acquire a real temporary
        // route pin before retiring the reader's independent file/worker pin.
        final lease = await acquireLease();
        if (_closed || token != _generation || !isCurrent(activation)) {
          lease?.release();
          return false;
        }
        if (lease == null ||
            lease.generation.sha256 != identity.sha256 ||
            lease.generation.key != identity.bookKey ||
            lease.local.digest != identity.sha256) {
          lease?.release();
          throw const ParseException();
        }
        final route = PreparedBook(summary, lease, () {});
        try {
          return await openPublication(
            book: route,
            activation: activation,
            isCurrent: isCurrent,
            acquireLease: acquireLease,
            queue: queue,
            worker: worker,
            fonts: registry,
            section: section,
            page: page,
            restoreCfi: cfi,
            nextSettings: value,
            captureIdentity: captureIdentity,
          );
        } finally {
          route.release();
        }
      };
      session = candidate;
      _proxy = proxy;
      turn = candidateTurn;
      published = true;
      accepted.value = candidate.position;
      if (!_closed && token == _generation) notifyListeners();
      snapshot();
      return true;
    } on Object {
      if (!requestCurrent()) return false;
      rethrow;
    } finally {
      if (!published) {
        if (candidate != null) {
          // Session shutdown owns the composition and source-adapter barrier.
          candidate.close();
          await candidate.closed;
        } else {
          composition?.dispose();
          await composition?.drain();
        }
        await sources?.close();
        pool.close();
        await pool.drained;
      }
    }
  }

  /// Releases a fixed/mixed reader before S3 preparation uses the same queue.
  /// The accepted position remains until a replacement successfully publishes.
  Future<void> releasePublication() {
    ++_generation;
    _replacePublication = null;
    _pendingSettings = null;
    _reflowRequest = null;
    if (_fixedSources == null) {
      return _publicationRetirement ?? Future<void>.value();
    }
    return _retireForPublication();
  }

  Future<void> _retireForPublication() {
    final oldSession = session;
    if (oldSession == null) {
      return _publicationRetirement ?? Future<void>.value();
    }
    final oldTurn = turn;
    final oldSources = _fixedSources;
    final oldOwner = _owner;
    final oldBook = _book;
    _proxy?.release();
    oldTurn?.cancel('programmatic-open');
    session = null;
    turn = null;
    _proxy = null;
    _fixedComposition = null;
    _fixedSources = null;
    _owner = null;
    _book = null;
    // Keep the replacement factory and accepted source while the display is
    // retired: another metrics/settings request must supersede the candidate.
    final previousRetirement = _publicationRetirement;
    Future<void> retire() async {
      await previousRetirement;
      // Detach the old widget's frame leases before its pictures are disposed.
      if (SchedulerBinding.instance.hasScheduledFrame) {
        await SchedulerBinding.instance.endOfFrame;
      }
      oldTurn?.close();
      oldSession.close();
      await oldSession.closed;
      await oldTurn?.closeAndDrain();
      await oldSources?.close();
      await oldOwner?.close();
      oldBook?.archive.close();
    }

    final retiring = _publicationRetirement = retire();
    // Retain accepted until a fully prepared replacement can publish.
    notifyListeners();
    return retiring;
  }

  @override
  Future<void> jump(int section, {int page = 0, bool cold = false}) =>
      _replace(section, page, cold: cold);

  Future<void> reflow(ReaderSettings value) async {
    ++_generation;
    final position =
        turn?.accepted ?? (canReplacePublication ? accepted.value : null);
    if (position == null) {
      settings = value;
      notifyListeners();
      return;
    }
    final request = _reflowRequest = Object();
    _pendingSettings = value;
    turn?.settingsChanged();
    try {
      await _replace(
        position.sectionIndex,
        position.pageIndex,
        nextSettings: value,
        restoreCfi: position.cfi,
        cold: true,
      );
      if (!_closed && identical(request, _reflowRequest) && session == null) {
        throw const ParseException();
      }
    } finally {
      if (identical(request, _reflowRequest)) {
        _pendingSettings = null;
        _reflowRequest = null;
      }
    }
  }

  Future<void> _replace(
    int section,
    int page, {
    bool cold = false,
    ReaderSettings? nextSettings,
    String? restoreCfi,
    EpubBook? nextBook,
    ProbeBook? nextIdentity,
  }) async {
    if (_closed) return;
    final replacePublication = _replacePublication;
    if (nextBook == null && replacePublication != null) {
      await replacePublication(
        section,
        page,
        restoreCfi,
        nextSettings ?? settings,
      );
      return;
    }
    final book = nextBook ?? _book;
    final id = nextIdentity ?? identity;
    if (book == null || id == null) return;
    if (nextBook != null) _replacePublication = null;
    final token = ++_generation;
    if (_fixedSources != null) {
      await _retireForPublication();
      if (_closed || token != _generation) {
        nextBook?.archive.close();
        return;
      }
    }
    final value = nextSettings ?? settings;
    final previousOwner = _owner;
    final reuse =
        !cold &&
        nextBook == null &&
        nextSettings == null &&
        previousOwner != null;
    final pool = PageSurfacePool(
      resourceBudget: reuse ? session?.pool.resourceBudget : null,
      allocations: reuse ? session?.pool.allocations : null,
    );
    final owner = reuse
        ? previousOwner
        : ReaderPreparationRepository(
            book: book,
            digest: id.sha256,
            settings: value,
            width: width,
            height: height,
            dpr: dpr,
            generation: token,
            recorder: recorder,
            resourceBudget: pool.resourceBudget,
          );
    PreparedReaderSession? candidate;
    try {
      final prepared = await owner.load(section);
      if (prepared == null) throw const ParseException();
      var destination = page < 0 ? prepared.pageCount - 1 : page;
      if (restoreCfi != null) {
        final proof = PageAnchors(prepared).prove(restoreCfi);
        if (!proof.ok || proof.pageIndex == null) throw const ParseException();
        destination = proof.pageIndex!;
      }
      if (destination < 0 || destination >= prepared.pageCount) {
        throw const ParseException();
      }
      candidate = await PreparedReaderSession.open(
        pool: pool,
        section: prepared,
        pageIndex: destination,
        sectionCount: book.sections.length,
        loadSection: owner.load,
        theme: PagePaintTheme(background: value.theme.background),
        drain: owner.drain,
      );
      if (candidate == null) throw const ParseException();
      if (_closed || token != _generation) {
        candidate.close();
        await candidate.closed;
        if (!reuse) await owner.close();
        nextBook?.archive.close();
        return;
      }
      final oldSession = session;
      final oldTurn = turn;
      final oldProxy = _proxy;
      final oldBook = _book;
      oldProxy?.release();
      oldTurn?.cancel('programmatic-jump');
      _owner = owner;
      _book = book;
      identity = id;
      _replacePublication = null;
      session = candidate;
      _settings = value;
      final proxy = ProbeTurnSession(candidate);
      _proxy = proxy;
      turn = ReaderTurnController(
        session: proxy,
        initial: candidate.position,
        clock: _clockFactory(),
        width: width,
        timing: recorder,
        onAccepted: (p) => accepted.value = p,
      );
      turn?.configure(reducedMotion: reducedMotion);
      accepted.value = candidate.position;
      owner.pinned = pool.pinsSection;
      notifyListeners();
      // Retain the old pictures until its widget has detached this frame.
      if (SchedulerBinding.instance.hasScheduledFrame) {
        await SchedulerBinding.instance.endOfFrame;
      }
      oldTurn?.close();
      oldSession?.close();
      if (oldSession != null) {
        await oldSession.closed;
      }
      if (previousOwner != null && previousOwner != owner) {
        await previousOwner.close();
      }
      if (oldBook != book) oldBook?.archive.close();
      snapshot();
    } on Object {
      if (candidate != session) {
        candidate?.close();
        await candidate?.closed;
        pool.close();
        await pool.drained;
      }
      if (!reuse && owner != _owner) await owner.close();
      rethrow;
    }
  }

  @override
  Future<void> longParagraph() async {
    for (var i = 0; i < sectionCount; i++) {
      await jump(i, cold: true);
      final section = session?.frames.value.current.reflowSection;
      if (section != null &&
          section.model.blocks.whereType<TextBlock>().any(
            (block) => block.text.length >= 100000,
          )) {
        return;
      }
    }
    throw const ParseException();
  }

  @override
  Future<void> largeText() => reflow(
    settings.copyWith(
      fontSize: settings.fontSize == 26 ? 20 : 26,
      lineHeight: settings.lineHeight == 1.9 ? 1.6 : 1.9,
    ),
  );
  @override
  Future<void> warm() async {
    final current = session;
    if (current == null) return;
    for (final direction in TurnDirection.values) {
      await current.warm(direction);
    }
  }

  @override
  void holdPreparation() => _proxy?.hold();
  @override
  void releasePreparation() => _proxy?.release();
  @override
  void suspend() => turn?.suspend();
  @override
  Future<void> resume() async {
    await turn?.resume();
  }

  @override
  void snapshot() {
    final pool = session?.pool;
    if (pool == null) return;
    recorder.memory(
      liveSurfaces: pool.liveSurfaces,
      pictureBytes: pool.pictureBytes,
      imageBytes: pool.images.totalBytes,
      rssBytes: ProcessInfo.currentRss,
    );
  }

  Map<String, Object?> get resourceCaps {
    final pool = session?.pool;
    return {
      if (pool != null) ...{
        'liveSurfaceCap': PageSurfacePool.presentedCapacity,
        'liveSurfaceReserve': PageSurfacePool.reserve,
        'pictureCacheBytes': pool.maxPictureBytes,
        'imageCacheBytes': pool.images.maxBytes,
      },
    };
  }

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    _reflowRequest = null;
    _pendingSettings = null;
    ++_generation;
    releasePreparation();
    turn?.close();
    session?.close();
    final fixed = _fixedSources;
    _fixedComposition = null;
    _fixedSources = null;
    if (fixed != null) {
      final closing = session?.closed;
      unawaited(() async {
        await closing;
        await fixed.close();
      }());
    }
    final owner = _owner;
    final book = _book;
    final closing = session?.closed;
    _replacePublication = null;
    unawaited(() async {
      await closing;
      await owner?.close();
      book?.archive.close();
    }());
    accepted.dispose();
    super.dispose();
  }
}
