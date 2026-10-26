import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/features/diagnostics/data/book_digest.dart';
import 'package:shiori/features/diagnostics/data/probe_book_repository.dart';
import 'package:shiori/features/diagnostics/data/probe_turn_session.dart';
import 'package:shiori/features/diagnostics/data/reader_preparation_repository.dart';
import 'package:shiori/features/diagnostics/data/reader_probe_recorder.dart';
import 'package:shiori/features/diagnostics/presentation/reader_probe/scenario_target.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/engine/layout/layout_model.dart';
import 'package:shiori/features/reader/engine/motion/page_turn_engine.dart';
import 'package:shiori/features/reader/engine/motion/reader_turn_controller.dart';
import 'package:shiori/features/reader/engine/motion/turn_clock.dart';
import 'package:shiori/features/reader/engine/motion/turn_session.dart';
import 'package:shiori/features/reader/engine/pagination/anchor.dart';
import 'package:shiori/features/reader/engine/pagination/page_painter.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';
import 'package:shiori/features/reader/engine/support/unsupported_layout.dart';
import 'package:shiori/features/reader/engine/surface/page_surface_pool.dart';
import 'package:shiori/features/reader/engine/surface/prepared_reader_session.dart';

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
  PreparedReaderSession? session;
  ProbeTurnSession? _proxy;
  ReaderTurnController? turn;
  ReaderSettings settings = const ReaderSettings();
  bool reducedMotion = false;
  double width = 400, height = 600, dpr = 1;
  int _generation = 0;
  bool _closed = false;
  final accepted = ValueNotifier<TurnPosition?>(null);
  @override
  int get sectionCount => _book?.sections.length ?? 0;
  @override
  int get pageCount => session?.frames.value.current.section.pageCount ?? 0;
  @override
  bool get atEnd => turn?.accepted.atEnd ?? true;

  static EpubBook _open(Uint8List bytes) {
    final book = EpubBook.open(bytes);
    detectBookLayout(book).requireSupported();
    return book;
  }

  Future<void> open(ProbeBook book) async {
    final bytes = await book.read();
    if (sha256Hex(bytes) != book.sha256) throw const ParseException();
    final opened = await _openBook(bytes);
    if (_closed) return;
    final oldBook = _book;
    final oldIdentity = identity;
    _book = opened;
    identity = book;
    try {
      await jump(0, cold: true);
    } on Object {
      _book = oldBook;
      identity = oldIdentity;
      rethrow;
    }
  }

  @override
  Future<void> jump(int section, {int page = 0, bool cold = false}) =>
      _replace(section, page, cold: cold);

  Future<void> reflow(ReaderSettings value) async {
    final position = turn?.accepted;
    if (position == null) {
      settings = value;
      notifyListeners();
      return;
    }
    turn?.settingsChanged();
    await _replace(
      position.sectionIndex,
      position.pageIndex,
      nextSettings: value,
      restoreCfi: position.cfi,
      cold: true,
    );
  }

  Future<void> _replace(
    int section,
    int page, {
    bool cold = false,
    ReaderSettings? nextSettings,
    String? restoreCfi,
  }) async {
    final book = _book;
    final id = identity;
    if (_closed || book == null || id == null) return;
    final token = ++_generation;
    final value = nextSettings ?? settings;
    final previousOwner = _owner;
    final reuse = !cold && nextSettings == null && previousOwner != null;
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
        pool: PageSurfacePool(),
        section: prepared,
        pageIndex: destination,
        sectionCount: sectionCount,
        loadSection: owner.load,
        theme: PagePaintTheme(background: value.theme.background),
        drain: owner.drain,
      );
      if (candidate == null) throw const ParseException();
      if (_closed || token != _generation) {
        candidate.close();
        if (!reuse) await owner.close();
        return;
      }
      final oldSession = session;
      final oldTurn = turn;
      final oldProxy = _proxy;
      oldProxy?.release();
      oldTurn?.cancel('programmatic-jump');
      _owner = owner;
      session = candidate;
      settings = value;
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
      owner.pinned = (s) {
        final frame = session?.frames.value;
        return frame?.current.section == s ||
            frame?.previous?.section == s ||
            frame?.next?.section == s;
      };
      notifyListeners();
      // Retain the old pictures until its widget has detached this frame.
      await SchedulerBinding.instance.endOfFrame;
      oldTurn?.close();
      oldSession?.close();
      if (previousOwner != null && previousOwner != owner) {
        await previousOwner.close();
      }
      snapshot();
    } on Object {
      if (candidate != session) candidate?.close();
      if (!reuse && owner != _owner) await owner.close();
      rethrow;
    }
  }

  @override
  Future<void> longParagraph() async {
    for (var i = 0; i < sectionCount; i++) {
      await jump(i, cold: true);
      final section = session?.frames.value.current.section;
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
    ++_generation;
    releasePreparation();
    turn?.close();
    session?.close();
    final owner = _owner;
    if (owner != null) unawaited(owner.close());
    accepted.dispose();
    super.dispose();
  }
}
