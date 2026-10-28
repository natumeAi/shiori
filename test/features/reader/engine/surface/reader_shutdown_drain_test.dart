import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/engine/motion/page_turn_engine.dart';
import 'package:shiori/features/reader/engine/motion/reader_turn_controller.dart';
import 'package:shiori/features/reader/engine/motion/turn_intent_queue.dart';
import 'package:shiori/features/reader/engine/surface/page_surface_pool.dart';
import 'package:shiori/features/reader/engine/surface/prepared_reader_session.dart';

import '../layout/layout_test_support.dart';
import '../motion/motion_test_support.dart';
import 'surface_test_support.dart';

void main() {
  initEngineBinding();
  test(
    'closeAndDrain waits for canceled preparation with a fake motion clock',
    () async {
      final h = await SurfaceHarness.open();
      addTearDown(h.close);
      final barrier = Completer<void>();
      final clock = TestTurnClock();
      final session = (await PreparedReaderSession.open(
        pool: PageSurfacePool(),
        section: h.section,
        pageIndex: 0,
        sectionCount: 1,
        loadSection: (_) async => h.section,
        theme: surfaceTheme,
        drain: () => barrier.future,
      ))!;
      final controller = ReaderTurnController(
        session: session,
        initial: session.position,
        clock: clock,
        width: 400,
      );
      final turn = controller.turnPage(TurnDirection.next);
      await clock.flush();
      var drained = false;
      final close = controller.closeAndDrain().then((_) => drained = true);
      await clock.flush();
      expect((await turn).kind, TurnResultKind.cancelled);
      expect(controller.phase, TurnPhase.closed);
      expect(drained, isFalse);
      expect(session.pool.liveSurfaces, greaterThan(0));
      barrier.complete();
      await clock.flush();
      await close;
      await controller.closeAndDrain();
      expect(drained, isTrue);
      expect(h.accepted, isEmpty);
      session.close();
      expect(session.pool.owners, 0);
    },
  );
}
