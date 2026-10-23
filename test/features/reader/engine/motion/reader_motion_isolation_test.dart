import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';
import 'package:shiori/features/reader/engine/motion/page_turn_engine.dart';
import 'package:shiori/features/reader/engine/motion/reader_turn_controller.dart';
import 'package:shiori/features/reader/engine/motion/turn_intent_queue.dart';
import 'package:shiori/features/reader/engine/pagination/preparation.dart';
import 'package:shiori/features/reader/engine/pagination/prepared_section.dart';
import 'package:shiori/features/reader/engine/pagination/section_preparer.dart';
import 'package:shiori/features/reader/engine/surface/page_surface_pool.dart';

import '../layout/layout_test_support.dart';
import '../surface/surface_test_support.dart';

const _next = TurnDirection.next;
const _previous = TurnDirection.previous;
GestureInput _point(double x, double time) => GestureInput(x, 100, time);

void main() {
  initEngineBinding();
  for (final warm in [false, true]) {
    test(
      'reversal during ${warm ? 'warm' : 'cold'} admission keeps the newest neighbor',
      () async {
        final gate = Completer<void>();
        final h = await SurfaceHarness.open(drain: () => gate.future);
        addTearDown(h.close);
        addTearDown(() {
          if (!gate.isCompleted) gate.complete();
        });
        if (warm) await h.session.warm(_next);
        h.controller.pointerDown(1, _point(200, 0));
        await h.clock.flush();
        h.controller.pointerMove(1, _point(160, 50));
        await h.clock.flush();
        h.controller.pointerMove(1, _point(300, 100));
        await h.clock.flush();
        gate.complete();
        await h.clock.flush();
        await h.tick(1000);
        await h.tick(1080);
        expect(h.controller.offset, 110);
        expect(h.pool.owners, 2);
        expect(h.session.frames.value.previous, isNotNull);
        expect(h.session.frames.value.next, isNull);
        h.controller.pointerCancel(1);
        await h.clock.flush();
        expect(h.pool.owners, 1);
      },
    );
  }
  test(
    'real drag and paired settlement do no picture or proof work in motion',
    () async {
      var proofs = 0;
      final h = await SurfaceHarness.open(
        proofHook: (_, _) {
          proofs++;
          return null;
        },
      );
      addTearDown(h.close);
      await h.session.warm(_next);
      var created = 0;
      var disposed = 0;
      final oldCreate = ui.Picture.onCreate;
      final oldDispose = ui.Picture.onDispose;
      ui.Picture.onCreate = (_) {
        expect(ReaderWorkGuard.inCallback, isFalse);
        created++;
      };
      ui.Picture.onDispose = (_) {
        expect(ReaderWorkGuard.inCallback, isFalse);
        disposed++;
      };
      addTearDown(() {
        ui.Picture.onCreate = oldCreate;
        ui.Picture.onDispose = oldDispose;
      });
      expect(h.controller.pointerDown(1, _point(200, 0)), isTrue);
      await h.clock.flush();
      h.controller.pointerMove(1, _point(160, 50));
      await h.clock.flush();
      final baseline = (
        proofs,
        h.pool.owners,
        h.pool.pictureBytes,
        h.session.frames.value,
      );
      for (final sample in [(140.0, 100.0), (110.0, 150.0), (60.0, 200.0)]) {
        h.controller.pointerMove(1, _point(sample.$1, sample.$2));
        await h.clock.flush();
        await h.tick(sample.$2);
        expect((
          proofs,
          h.pool.owners,
          h.pool.pictureBytes,
          h.session.frames.value,
        ), baseline);
        expect(h.controller.accepted.pageIndex, 10);
      }
      final turn = h.controller.pointerUp(1, _point(50, 250))!;
      await h.clock.flush();
      expect(h.controller.phase, TurnPhase.settling);
      await h.tick(300);
      expect(created, 0);
      expect(disposed, 0);
      expect(proofs, baseline.$1);
      await h.tick(1000);
      expect((await turn).kind, TurnResultKind.committed);
      expect(h.controller.accepted.pageIndex, 11);
      expect(h.accepted, hasLength(1));
    },
  );

  test('actual pending pagination drain prevents paired settlement', () async {
    final gate = Completer<void>();
    final control = PreparationControl(
      slice: Duration.zero,
      yielder: () => gate.future,
    );
    late Future<PreparedSection> work;
    var drains = 0;
    final h = await SurfaceHarness.open(
      drain: () async {
        drains++;
        control.cancel();
        try {
          (await work).dispose();
        } on PreparationCancelled {
          /* Expected drain. */
        }
      },
    );
    addTearDown(h.close);
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    await h.session.warm(_next);
    work = SectionPreparer().prepare(h.request, control: control);
    final turn = h.controller.turnPage(_next);
    await h.clock.flush();
    expect(control.yieldCount, 1);
    expect(drains, 1);
    expect(h.controller.phase, TurnPhase.preparing);
    expect(h.controller.needsTick, isFalse);
    expect(h.session.frames.value.next, isNull);
    gate.complete();
    await h.clock.flush();
    expect(h.controller.phase, TurnPhase.settling);
    await h.tick(0);
    await h.tick(420);
    expect((await turn).kind, TurnResultKind.committed);
  });

  test(
    'retained leases occupy the owner budget until their real release',
    () async {
      final h = await SurfaceHarness.open();
      addTearDown(h.close);
      final leases = [
        for (final page in [9, 11, 12])
          (await h.pool.prepare(h.section, page, surfaceTheme))!,
      ];
      final retained = leases.first.retain();
      expect(h.pool.owners, PageSurfacePool.capacity);
      expect(await h.pool.prepare(h.section, 13, surfaceTheme), isNull);
      leases.first.release();
      expect(retained.surface.disposed, isFalse);
      expect(await h.pool.prepare(h.section, 13, surfaceTheme), isNull);
      retained.release();
      expect(retained.surface.picture.debugDisposed, isTrue);
      final replacement = await h.pool.prepare(h.section, 13, surfaceTheme);
      expect(replacement, isNotNull);
      replacement!.release();
      for (final lease in leases) {
        lease.release();
      }
      expect(h.pool.owners, 1);
      expect(h.pool.peakOwners, PageSurfacePool.capacity);
    },
  );

  test(
    'cold reversal parks foreground before creating the opposite picture',
    () async {
      final h = await SurfaceHarness.open();
      addTearDown(h.close);
      h.controller.pointerDown(1, _point(200, 0));
      h.controller.pointerMove(1, _point(100, 100));
      await h.clock.flush();
      await h.tick(0);
      await h.tick(80);
      expect(h.controller.offset, -90);
      var created = 0;
      final old = ui.Picture.onCreate;
      ui.Picture.onCreate = (_) {
        created++;
        expect(h.controller.offset, 0);
        expect(ReaderWorkGuard.inCallback, isFalse);
        expect(h.session.frames.value.next, isNull);
      };
      addTearDown(() => ui.Picture.onCreate = old);
      h.controller.pointerMove(1, _point(300, 200));
      await h.clock.flush();
      expect(created, 1);
      await h.tick(100);
      await h.tick(180);
      expect(h.controller.offset, 110);
    },
  );
  test(
    'ready opposite neighbor reverses by lease without creating another owner',
    () async {
      final h = await SurfaceHarness.open();
      addTearDown(h.close);
      await h.session.warm(_next);
      await h.session.warm(_previous);
      h.controller.pointerDown(1, _point(200, 0));
      await h.clock.flush();
      h.controller.pointerMove(1, _point(100, 100));
      await h.clock.flush();
      await h.tick(100);
      expect(h.controller.offset, -90);
      final frame = h.session.frames.value;
      final owners = h.pool.owners;
      final bytes = h.pool.pictureBytes;
      h.controller.pointerMove(1, _point(300, 200));
      await h.clock.flush();
      await h.tick(200);
      expect(h.controller.offset, 110);
      expect(h.pool.owners, owners);
      expect(h.pool.pictureBytes, bytes);
      expect(h.session.frames.value, same(frame));
      expect(frame.previous, isNotNull);
      expect(frame.next, isNotNull);
    },
  );

  test(
    '100 alternating animated turns bound owners and release all pictures',
    () async {
      final h = await SurfaceHarness.open();
      addTearDown(h.close);
      for (var i = 0; i < 100; i++) {
        expect(
          (await h.turn(i.isEven ? _next : _previous)).kind,
          TurnResultKind.committed,
        );
        expect(h.pool.owners, 1);
        expect(h.pool.peakOwners, lessThanOrEqualTo(PageSurfacePool.capacity));
        expect(h.controller.phase, TurnPhase.idle);
      }
      expect(h.controller.accepted.pageIndex, 10);
      expect(h.accepted, hasLength(100));
      await h.close();
      expect(h.pool.owners, 0);
      expect(h.pool.pictureBytes, 0);
      expect(h.pool.images.totalBytes, 0);
      expect(
        h.surfaces.every((s) => s.disposed && s.picture.debugDisposed),
        isTrue,
      );
    },
  );

  test(
    'samples accumulate during drain then catch up to the newest held sample',
    () async {
      final gate = Completer<void>();
      final h = await SurfaceHarness.open(drain: () => gate.future);
      addTearDown(h.close);
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      h.controller.pointerDown(1, _point(200, 0));
      h.controller.pointerMove(1, _point(160, 50));
      await h.clock.flush();
      h.controller.pointerMove(1, _point(80, 100));
      await h.clock.flush();
      expect(h.controller.offset, 0);
      expect(h.session.frames.value.next, isNull);
      gate.complete();
      for (var i = 0; i < 1000; i++) {
        await Future<void>.value();
      }
      expect(
        h.session.frames.value.next,
        isNull,
        reason: 'drain microtasks may only schedule ordinary control tasks',
      );
      await h.clock.flush();
      await h.tick(1000);
      expect(h.controller.offset, 0);
      await h.tick(1040);
      expect(h.controller.offset, -96.25);
      await h.tick(1080);
      expect(h.controller.offset, -110);
      expect(h.controller.needsTick, isFalse);
      expect(h.pool.owners, 2);
      h.controller.pointerCancel(1);
      await h.clock.flush();
      expect(h.pool.owners, 1);
    },
  );
}
