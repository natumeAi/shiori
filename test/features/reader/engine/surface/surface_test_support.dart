import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/core/config/server_endpoint.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/data/layout/reading_unit_section.dart';
import 'package:shiori/features/reader/data/layout/section_rendition.dart';
import 'package:shiori/features/reader/engine/motion/page_turn_engine.dart';
import 'package:shiori/features/reader/engine/motion/reader_turn_controller.dart';
import 'package:shiori/features/reader/engine/motion/turn_intent_queue.dart';
import 'package:shiori/features/reader/engine/motion/turn_session.dart';
import 'package:shiori/features/reader/engine/pagination/anchor.dart';
import 'package:shiori/features/reader/engine/pagination/page_painter.dart';
import 'package:shiori/features/reader/engine/pagination/preparation.dart';
import 'package:shiori/features/reader/engine/pagination/prepared_section.dart';
import 'package:shiori/features/reader/engine/pagination/reading_unit_navigator.dart';
import 'package:shiori/features/reader/engine/pagination/section_preparer.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';
import 'package:shiori/features/reader/engine/surface/page_surface_pool.dart';
import 'package:shiori/features/reader/engine/surface/prepared_reader_session.dart';

import '../layout/layout_test_support.dart';
import '../motion/motion_test_support.dart';
import '../../contract_test_values.dart';

const surfaceTheme = PagePaintTheme(background: 0xffffffff);

final class SurfaceHarness {
  SurfaceHarness._(
    this.request,
    this.section,
    this.pool,
    this.session,
    this.clock,
    TurnTimingSink? timing,
  ) {
    controller = ReaderTurnController(
      session: session,
      initial: session.position,
      clock: clock,
      width: 400,
      onAccepted: accepted.add,
      timing: timing,
    );
    capture();
    session.frames.addListener(capture);
  }
  final PreparedSection section;
  final PrepareRequest request;
  final PageSurfacePool pool;
  final PreparedReaderSession session;
  final TestTurnClock clock;
  late final ReaderTurnController controller;
  final List<TurnPosition> accepted = [];
  final Set<PreparedPageSurface> surfaces = {};
  bool _closed = false;

  static Future<SurfaceHarness> open({
    Future<void> Function()? drain,
    AnchorProofHook? proofHook,
    int page = 10,
    TurnTimingSink? timing,
  }) async {
    final book = EpubBook.open(
      buildEpub(
        sections: {
          's.xhtml': xhtml(
            List.generate(
              25,
              (i) =>
                  '<p style="break-before:page">Page $i alpha beta gamma delta epsilon.</p>',
            ).join(),
          ),
        },
      ),
    );
    final document = book.loadSection(0);
    final request = PrepareRequest(
      book: book,
      sectionIndex: 0,
      document: document,
      styled: fixtureResolver().resolve(
        book,
        0,
        document,
        const ReaderSettings(),
      ),
      settings: const ReaderSettings(),
      viewportWidth: 400,
      viewportHeight: 600,
      contentId: contractContent().sha256,
    );
    final section = await SectionPreparer().prepare(
      request,
      control: PreparationControl(slice: const Duration(days: 1)),
    );
    expect(section.pageCount, 25);
    final pool = PageSurfacePool();
    final session = await PreparedReaderSession.open(
      pool: pool,
      section: section,
      pageIndex: page,
      sectionCount: 1,
      loadSection: (_) async => section,
      theme: surfaceTheme,
      proofHook: proofHook,
      drain: drain,
      navigator: surfaceNavigator([section]),
      activation: surfaceActivation(1),
      isActivationCurrent: (_) => true,
    );
    expect(session, isNotNull);
    return SurfaceHarness._(
      request,
      section,
      pool,
      session!,
      TestTurnClock(),
      timing,
    );
  }

  void capture() {
    final frame = session.frames.value;
    surfaces.add(frame.current);
    if (frame.previous != null) surfaces.add(frame.previous!);
    if (frame.next != null) surfaces.add(frame.next!);
  }

  Future<void> tick(double time) async {
    clock.now = time;
    controller.tick();
    await clock.flush();
  }

  Future<TurnResult> turn(TurnDirection direction) async {
    final result = controller.turnPage(direction);
    await clock.flush();
    await tick(clock.now);
    await tick(clock.now + 420);
    return result;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    controller.close();
    await clock.flush();
    session.close();
    section.dispose();
  }
}

ServerSession surfaceActivation(int generation) => ServerSession(
  endpoint: ServerEndpoint.parse(
    contractContent().bookKey.serverKey.canonicalRoot,
  ).endpoint!,
  generation: generation,
);

ComposedReadingUnitNavigator surfaceNavigator(
  List<PreparedSection> sections, {
  Set<int> nonlinear = const {},
}) {
  final sources = {
    for (final section in sections)
      section.sectionIndex: contractPage(
        section: section.sectionIndex,
        id: 'section-${section.sectionIndex}.xhtml',
      ),
  };
  return ComposedReadingUnitNavigator(
    sections: [
      for (final section in sections)
        ReadingUnitSection(
          page: sources[section.sectionIndex]!,
          href: 'section-${section.sectionIndex}.xhtml',
          rendition: resolveSectionRendition(package: {}),
          linear: !nonlinear.contains(section.sectionIndex),
          layoutKey: section.identity.key,
          reflowPageCount: section.pageCount,
        ),
    ],
    viewportWidth: sections.first.identity.viewportWidth,
    viewportHeight: sections.first.identity.viewportHeight,
    documents: {
      for (final section in sections)
        sources[section.sectionIndex]!: section.document,
    },
    locateReflow: (page, position) => PageAnchors(
      sections.firstWhere((s) => s.sectionIndex == page.sectionIndex),
    ).locate(position)?.pageIndex,
  );
}

TurnPosition changePosition(
  TurnPosition p, {
  String? cfi,
  String? layout,
  int? generation,
  int? section,
  int? page,
  int? total,
  String? identity,
}) => TurnPosition(
  cfi: cfi ?? p.cfi,
  layoutKey: layout ?? p.layoutKey,
  layoutGeneration: generation ?? p.layoutGeneration,
  sectionIndex: section ?? p.sectionIndex,
  pageIndex: page ?? p.pageIndex,
  pageCount: total ?? p.pageCount,
  pageIdentity: identity ?? p.pageIdentity,
  atStart: p.atStart,
  atEnd: p.atEnd,
);
