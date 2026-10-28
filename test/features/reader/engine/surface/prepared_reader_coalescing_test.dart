import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/worker/publication_cancellation.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';
import 'package:shiori/features/reader/engine/motion/page_turn_engine.dart';
import 'package:shiori/features/reader/engine/motion/turn_session.dart';

import '../layout/layout_test_support.dart';
import 'surface_test_support.dart';

void main() {
  initEngineBinding();
  test(
    'warm plus direct prepare share one record and independent references',
    () async {
      final h = await SurfaceHarness.open();
      addTearDown(h.close);
      final pictures = <ui.Picture>[];
      final old = ui.Picture.onCreate;
      ui.Picture.onCreate = pictures.add;
      addTearDown(() => ui.Picture.onCreate = old);
      final canceled = PublicationCancellation();
      final warm = h.session.warm(TurnDirection.next);
      final abandoned = h.session.prepare(
        h.session.position,
        TurnDirection.next,
        cancellation: canceled,
      );
      final live = h.session.prepare(h.session.position, TurnDirection.next);
      canceled.cancel();
      expect(await abandoned, isNull);
      await warm;
      final consumer = (await live)!;
      final warmed = h.session.ready(h.session.position, TurnDirection.next)!;
      expect(identical(consumer, warmed), isFalse);
      final lateConsumer = (await h.session.prepare(
        h.session.position,
        TurnDirection.next,
      ))!;
      expect(identical(lateConsumer, consumer), isFalse);
      expect(pictures, hasLength(1));
      expect(h.pool.owners, 2);
      warmed.release();
      lateConsumer.release();
      expect(pictures.single.debugDisposed, isFalse);
      final navigation = await h.session.navigate(
        h.session.position,
        TurnDirection.next,
        consumer,
      );
      expect(navigation.kind, TurnNavigationKind.verified);
      expect(
        await h.session.prove(navigation.position!, preview: consumer),
        isTrue,
      );
      h.session.accept(navigation.position!);
      consumer.release();
      h.session.unbind();
      expect(h.pool.owners, 1);
      expect(pictures.single.debugDisposed, isFalse);
    },
  );

  test('retired generation cannot publish; same-origin new generation starts fresh', () async {
    final h = await SurfaceHarness.open();
    addTearDown(h.close);
    final oldWarm = h.session.warm(TurnDirection.next);
    final oldPrepare = h.session.prepare(
      h.session.position,
      TurnDirection.next,
    );
    h.session.invalidatePreparation();
    final newWarm = h.session.warm(TurnDirection.next);
    await oldWarm;
    expect(await oldPrepare, isNull);
    await newWarm;
    final fresh = h.session.ready(h.session.position, TurnDirection.next);
    expect(fresh, isNotNull);
    expect(h.pool.owners, 2);
    fresh!.release();
    expect(h.pool.owners, 1);
    expect(
      await h.session.prepare(
        changePosition(
          h.session.position,
          generation: h.session.position.layoutGeneration + 1,
        ),
        TurnDirection.next,
      ),
      isNull,
    );
  });

  test('motion suppresses optional work and its late publication, preserving required waiter', () async {
    final h = await SurfaceHarness.open();
    addTearDown(h.close);
    final warm = h.session.warm(TurnDirection.next);
    final required = h.session.prepare(h.session.position, TurnDirection.next);
    h.session.optionalWorkAllowed(false);
    await warm;
    final preview = (await required)!;
    expect(h.session.ready(h.session.position, TurnDirection.next), isNull);
    await h.session.warm(TurnDirection.previous);
    expect(h.pool.owners, 2);
    preview.release();
    expect(h.pool.owners, 1);
    h.session.optionalWorkAllowed(true);
    await h.session.warm(TurnDirection.previous);
    expect(
      h.session.ready(h.session.position, TurnDirection.previous),
      isNotNull,
    );
  });

  test('close drains late warm/prepare owners without publishing', () async {
    final h = await SurfaceHarness.open();
    addTearDown(h.close);
    final warm = h.session.warm(TurnDirection.next);
    final prepare = h.session.prepare(h.session.position, TurnDirection.next);
    h.session.close();
    await warm;
    expect(await prepare, isNull);
    await h.session.stopAndDrain();
    expect(h.pool.owners, 0);
  });

  test('controller generation change revokes unbound warm work synchronously', () async {
    final h = await SurfaceHarness.open();
    addTearDown(h.close);
    final oldWarm = h.session.warm(TurnDirection.next);
    ReaderWorkGuard.callback(h.controller.settingsChanged);
    await oldWarm;
    // No posted control task has run yet, but old work already cannot publish.
    expect(h.session.ready(h.session.position, TurnDirection.next), isNull);
    expect(h.pool.owners, 1);
    await h.clock.flush();
    await h.session.warm(TurnDirection.next);
    final fresh = h.session.ready(h.session.position, TurnDirection.next);
    expect(fresh, isNotNull);
    fresh!.release();
    await h.session.warm(TurnDirection.next);
    ReaderWorkGuard.callback(h.controller.layoutChanged);
    // Retained warm pictures are released only by the posted control task.
    expect(h.pool.owners, 2);
    await h.clock.flush();
    expect(h.pool.owners, 1);
  });
}
