import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';
import 'package:shiori/features/reader/engine/motion/page_turn_engine.dart';
import 'package:shiori/features/reader/engine/motion/reader_turn_controller.dart';
import 'package:shiori/features/reader/engine/motion/turn_intent_queue.dart';
import 'package:shiori/features/reader/engine/motion/turn_session.dart';
import 'package:shiori/features/reader/engine/surface/page_surface_pool.dart';
import 'package:shiori/features/reader/engine/surface/prepared_reader_session.dart';

import '../motion/motion_test_support.dart';
import 'fixed_session_test_support.dart';
import 'surface_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'fixed spreads use existing motion proof and exactly-once acceptance',
    () async {
      final f = FixedSessionFixture(spreads: 3);
      await f.prepareNavigation();
      final session = (await PreparedReaderSession.openUnit(
        pool: PageSurfacePool(),
        unit: f.navigator.units.first,
        navigator: f.navigator,
        fixedSources: f.sources(),
        loadSection: (_) async => null,
        theme: surfaceTheme,
        activation: surfaceActivation(1),
        isActivationCurrent: (_) => true,
      ))!;
      final clock = TestTurnClock(), accepted = <TurnPosition>[];
      final controller = ReaderTurnController(
        session: session,
        initial: session.position,
        clock: clock,
        width: 800,
        onAccepted: accepted.add,
      );
      for (final direction in [
        TurnDirection.next,
        TurnDirection.next,
        TurnDirection.previous,
        TurnDirection.previous,
      ]) {
        await session.warm(direction);
        final result = controller.turnPage(direction);
        for (var i = 0; i < 100 && !controller.needsTick; i++) {
          await Future<void>.delayed(Duration.zero);
          await clock.flush();
        }
        expect(controller.needsTick, true);
        ReaderWorkGuard.callback(controller.tick);
        await clock.flush();
        clock.now += 420;
        ReaderWorkGuard.callback(controller.tick);
        await clock.flush();
        expect((await result).kind, TurnResultKind.committed);
        expect(await session.prove(session.position), true);
      }
      expect(accepted.map((p) => p.sectionIndex), [2, 4, 3, 1]);
      expect(session.pool.peakOwners, lessThanOrEqualTo(4));
      final drain = controller.closeAndDrain();
      await clock.flush();
      await drain;
      session.close();
      await session.closed;
      expect(session.pool.owners, 0);
      expect(session.pool.pictureBytes, 0);
      f.dispose();
    },
  );
}
