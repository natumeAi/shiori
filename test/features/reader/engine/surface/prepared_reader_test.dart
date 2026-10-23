import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/engine/motion/page_turn_engine.dart';
import 'package:shiori/features/reader/engine/motion/reader_turn_controller.dart';
import 'package:shiori/features/reader/engine/motion/turn_intent_queue.dart';
import 'package:shiori/features/reader/engine/surface/page_surface_pool.dart';
import 'package:shiori/features/reader/engine/surface/prepared_reader.dart';

import 'surface_test_support.dart';

Widget _reader(
  SurfaceHarness h, {
  VoidCallback? onPageBuild,
  bool reduced = false,
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Center(
      child: SizedBox(
        width: 400,
        height: 600,
        child: PreparedReader(
          controller: h.controller,
          session: h.session,
          onPageBuild: onPageBuild,
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'motion changes painted offsets without rebuilding page subtrees',
    (tester) async {
      final h = await SurfaceHarness.open();
      addTearDown(h.close);
      await h.session.warm(TurnDirection.previous);
      await h.session.warm(TurnDirection.next);
      var builds = 0;
      await tester.pumpWidget(_reader(h, onPageBuild: () => builds++));
      final origin = tester.getTopLeft(find.byType(PreparedReader));
      final gesture = await tester.startGesture(
        origin + const Offset(200, 100),
      );
      await h.clock.flush();
      await tester.pump();
      final page = find.byType(CustomPaint).first;
      final start = tester.getTopLeft(page);
      final initialBuilds = builds;
      expect(find.byType(CustomPaint), findsNWidgets(3));
      for (final x in [160.0, 140.0, 100.0]) {
        await gesture.moveTo(origin + Offset(x, 100));
        await h.clock.flush();
        h.clock.now += 16;
        await tester.pump(const Duration(milliseconds: 16));
        expect(builds, initialBuilds);
        expect(
          tester.getTopLeft(page).dx,
          closeTo(start.dx + h.controller.offset, 0.001),
        );
      }
      expect(h.controller.offset, -90);
      await gesture.cancel();
      await h.clock.flush();
      await tester.pumpWidget(const SizedBox.shrink());
      await h.clock.flush();
    },
  );

  testWidgets('background suspends the controller and foreground resumes it', (
    tester,
  ) async {
    final h = await SurfaceHarness.open();
    addTearDown(h.close);
    await tester.pumpWidget(_reader(h));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await h.clock.flush();
    expect(h.controller.phase, TurnPhase.suspended);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await h.clock.flush();
    expect(h.controller.phase, TurnPhase.idle);
    await tester.pumpWidget(const SizedBox.shrink());
    await h.clock.flush();
  });

  testWidgets(
    'leases dispose outgoing pictures and widget disposal releases the rest',
    (tester) async {
      final h = await SurfaceHarness.open();
      addTearDown(h.close);
      await tester.pumpWidget(_reader(h));
      for (var i = 0; i < 6; i++) {
        final outgoing = h.session.frames.value.current;
        final result = h.controller.turnPage(TurnDirection.next);
        await h.clock.flush();
        await tester.pump();
        expect(outgoing.disposed, isFalse);
        await h.tick(h.clock.now);
        await tester.pump();
        await h.tick(h.clock.now + 420);
        expect((await result).kind, TurnResultKind.committed);
        await tester.pump();
        expect(outgoing.disposed, isTrue);
        expect(outgoing.picture.debugDisposed, isTrue);
        expect(h.session.frames.value.current.picture.debugDisposed, isFalse);
        expect(h.pool.liveSurfaces, 1);
      }
      final current = h.session.frames.value.current;
      await tester.pumpWidget(const SizedBox.shrink());
      await h.clock.flush();
      expect(current.disposed, isTrue);
      expect(h.pool.owners, 0);
      expect(h.pool.pictureBytes, 0);
      expect(h.surfaces.every((s) => s.picture.debugDisposed), isTrue);
    },
  );

  testWidgets(
    'three visible surfaces plus the declared reserve is a hard bound',
    (tester) async {
      final h = await SurfaceHarness.open();
      addTearDown(h.close);
      await h.session.warm(TurnDirection.previous);
      await h.session.warm(TurnDirection.next);
      await tester.pumpWidget(_reader(h));
      expect(PageSurfacePool.presentedCapacity, 3);
      expect(PageSurfacePool.reserve, 1);
      expect(h.pool.liveSurfaces, 3);
      final reserve = await h.pool.prepare(h.section, 15, surfaceTheme);
      expect(reserve, isNotNull);
      expect(
        h.pool.owners,
        PageSurfacePool.presentedCapacity + PageSurfacePool.reserve,
      );
      expect(await h.pool.prepare(h.section, 16, surfaceTheme), isNull);
      reserve!.release();
      expect(reserve.surface.picture.debugDisposed, isTrue);
      expect(h.pool.liveSurfaces, 3);
      await tester.pumpWidget(const SizedBox.shrink());
      await h.clock.flush();
      expect(h.pool.owners, 0);
      expect(h.pool.peakOwners, PageSurfacePool.capacity);
    },
  );

  testWidgets(
    'dispose during an active drag releases leases before late cleanup',
    (tester) async {
      final h = await SurfaceHarness.open();
      addTearDown(h.close);
      await h.session.warm(TurnDirection.next);
      await tester.pumpWidget(_reader(h));
      final origin = tester.getTopLeft(find.byType(PreparedReader));
      final gesture = await tester.startGesture(
        origin + const Offset(200, 100),
      );
      await h.clock.flush();
      await gesture.moveTo(origin + const Offset(100, 100));
      await h.clock.flush();
      await tester.pump();
      expect(h.controller.offset, -90);
      expect(h.pool.liveSurfaces, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(h.pool.owners, 0);
      await h.clock.flush();
      await gesture.cancel();
      expect(h.controller.phase, TurnPhase.closed);
      expect(h.accepted, isEmpty);
      expect(
        h.surfaces.every((s) => s.disposed && s.picture.debugDisposed),
        isTrue,
      );
    },
  );

  testWidgets('reduced motion skips ticks but still proves and accepts once', (
    tester,
  ) async {
    var proofs = 0;
    final h = await SurfaceHarness.open(
      proofHook: (_, _) {
        proofs++;
        return null;
      },
    );
    addTearDown(h.close);
    await tester.pumpWidget(_reader(h, reduced: true));
    proofs = 0;
    final turn = h.controller.turnPage(TurnDirection.next);
    await h.clock.flush();
    expect((await turn).kind, TurnResultKind.committed);
    expect(h.controller.reducedMotion, isTrue);
    expect(h.controller.needsTick, isFalse);
    expect(h.controller.phase, TurnPhase.idle);
    expect(proofs, greaterThan(0));
    expect(h.accepted, hasLength(1));
    expect(h.controller.accepted.pageIndex, 11);
    expect(h.controller.staticFallbacks, 0);
    expect(h.controller.offset, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await h.clock.flush();
  });
}
