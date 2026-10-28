import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/server_endpoint.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/features/reader/data/resources/reader_resource_budget.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_source_lease.dart';
import 'package:shiori/features/reader/engine/layout/font_registry.dart';
import 'package:shiori/features/reader/engine/layout/process_font_budget.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/motion/page_turn_engine.dart';
import 'package:shiori/features/reader/engine/motion/reader_preparation_failure.dart';
import 'package:shiori/features/reader/engine/motion/turn_session.dart';
import 'package:shiori/features/reader/engine/style/css_style_resolver.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';
import 'package:shiori/features/reader/engine/surface/page_surface_pool.dart';
import 'package:shiori/features/reader/engine/surface/fixed_unit_navigation.dart';
import 'package:shiori/features/reader/engine/surface/prepared_reader_session.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_section_preparer.dart';
import 'package:shiori/features/reader/engine/support/section_capability.dart';

import '../style/style_test_support.dart';
import 'fixed_session_test_support.dart';
import 'surface_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final kind in [
    ReaderPreparationFailureKind.pictureAdmission,
    ReaderPreparationFailureKind.imageAdmission,
    ReaderPreparationFailureKind.processFontExhausted,
    ReaderPreparationFailureKind.requiredFont,
    ReaderPreparationFailureKind.fixedCapability,
    ReaderPreparationFailureKind.sceneAdmission,
    ReaderPreparationFailureKind.encodedAdmission,
  ]) {
    test('$kind keeps accepted reflow picture, position and proof', () async {
      final f = FixedSessionFixture();
      await f.prepareNavigation();
      addTearDown(f.dispose);
      final pool = PageSurfacePool(
        resourceBudget: kind == ReaderPreparationFailureKind.sceneAdmission
            ? SceneResourceBudget(
                limits: {
                  ...SceneResourceBudget.provisionalLimits,
                  SceneResource.paragraphs: 1,
                },
              )
            : null,
        maxPictureBytes: kind == ReaderPreparationFailureKind.pictureAdmission
            ? 512 * 1024
            : 16 * 1024 * 1024,
      );
      var decoded = 0;
      if (kind == ReaderPreparationFailureKind.imageAdmission) {
        f.images[1] = {
          'unused': FixedImageRequest(
            width: 4096,
            height: 4096,
            acquire: (_) {
              decoded++;
              throw StateError('must refuse before decode');
            },
          ),
        };
      }
      if (kind == ReaderPreparationFailureKind.requiredFont) f.badFonts.add(1);
      if (kind == ReaderPreparationFailureKind.fixedCapability) {
        final doc = f.documents[1]!;
        // The reflow profile from section zero cannot stand in for fixed styles.
        f.styles[1] = const CssStyleResolver().resolve(
          f.book,
          0,
          doc,
          const ReaderSettings(),
        );
      }
      final registry = FontRegistry(
        processBudget: kind == ReaderPreparationFailureKind.processFontExhausted
            ? ProcessFontBudget(maxBytes: 1)
            : ProcessFontBudget(),
      );
      final encoded = ReaderResourceBudget(maxBytes: 0);
      final sources = f.sources(fonts: registry);
      final fixedSources = FixedUnitSources(
        loadSource: (page) async {
          if (kind == ReaderPreparationFailureKind.encodedAdmission) {
            encoded.createSession().reserve({'fixed.xhtml': 1});
          }
          return sources.loadSource(page);
        },
        layoutFor: sources.layoutFor,
        sectionBaseFor: sources.sectionBaseFor,
        fonts: registry,
      );
      final session = (await PreparedReaderSession.openUnit(
        pool: pool,
        unit: f.navigator.units.first,
        navigator: f.navigator,
        fixedSources: fixedSources,
        loadSection: (i) async => f.reflow[i],
        theme: surfaceTheme,
        activation: surfaceActivation(1),
        isActivationCurrent: (_) => true,
      ))!;
      addTearDown(session.close);
      final accepted = session.position, frame = session.frames.value;
      var publications = 0;
      session.frames.addListener(() => publications++);
      final result = await session.navigate(accepted, TurnDirection.next, null);
      expect(result.kind, TurnNavigationKind.failed);
      expect(result.failure!.kind, kind);
      expect(session.lastFailure, same(result.failure));
      expect(session.position.sameOrigin(accepted), true);
      expect(session.frames.value, same(frame));
      expect(publications, 0);
      expect(await session.prove(accepted), true);
      expect(pool.owners, 1);
      expect(pool.liveSurfaces, 1);
      expect(decoded, 0);
      expect(f.acquired, f.released);
      session.close();
      await session.closed;
      expect(pool.pictureBytes, 0);
      expect(pool.images.totalBytes, 0);
      expect(pool.resourceBudget.used.values, everyElement(0));
      expect(encoded.accountedBytes, 0);
    });
  }

  test(
    'unpainted fixed source reports capability failure and keeps accepted page',
    () async {
      final f = FixedSessionFixture();
      final sample = StyleSample.html(
        '<div id="source" style="opacity:0">Invisible source</div>',
        css: 'html,body{margin:0;width:320px;height:240px}',
        head: '<meta name="viewport" content="width=320,height=240"/>',
        metadata: '<meta property="rendition:layout">pre-paginated</meta>',
      );
      f.documents[1] = sample.document;
      f.styles[1] = const CssStyleResolver().resolve(
        sample.book,
        0,
        sample.document,
        const ReaderSettings(),
      );
      await f.prepareNavigation();
      addTearDown(f.dispose);
      addTearDown(sample.book.archive.close);
      final pool = PageSurfacePool();
      final session = (await PreparedReaderSession.openUnit(
        pool: pool,
        unit: f.navigator.units.first,
        navigator: f.navigator,
        fixedSources: f.sources(),
        loadSection: (i) async => f.reflow[i],
        theme: surfaceTheme,
        activation: surfaceActivation(1),
        isActivationCurrent: (_) => true,
      ))!;
      addTearDown(session.close);
      final accepted = session.position, frame = session.frames.value;
      final result = await session.navigate(accepted, TurnDirection.next, null);
      expect(result.kind, TurnNavigationKind.failed);
      expect(
        result.failure!.kind,
        ReaderPreparationFailureKind.fixedCapability,
      );
      final capability =
          (result.failure!.cause as FixedPreparationFailure).capability;
      expect(capability, isA<RenderSectionCapability>());
      expect(capability.constructs.single.identifier, 'fixed-anchor-proof');
      expect(session.frames.value, same(frame));
      expect(session.position.sameOrigin(accepted), true);
      expect(await session.prove(accepted), true);
      expect(f.acquired, f.released);
      expect(pool.owners, 1);
      session.close();
      await session.closed;
      expect(pool.resourceBudget.used.values, everyElement(0));
      expect(pool.pictureBytes, 0);
    },
  );

  test('cancel during native font work retains reservations through physical drain', () async {
    final f = FixedSessionFixture();
    await f.prepareNavigation();
    addTearDown(f.dispose);
    final entered = Completer<void>(), native = Completer<void>();
    final registry = FontRegistry(
      processBudget: ProcessFontBudget(),
      register: (_, _) {
        entered.complete();
        return native.future;
      },
    );
    final pool = PageSurfacePool();
    final session = (await PreparedReaderSession.openUnit(
      pool: pool,
      unit: f.navigator.units.first,
      navigator: f.navigator,
      fixedSources: f.sources(fonts: registry),
      loadSection: (i) async => f.reflow[i],
      theme: surfaceTheme,
      activation: surfaceActivation(1),
      isActivationCurrent: (_) => true,
    ))!;
    final accepted = session.position;
    final preparing = session.prepare(accepted, TurnDirection.next);
    await entered.future;
    session.invalidatePreparation();
    var drained = false;
    final barrier = session.stopAndDrain().then((_) => drained = true);
    await Future<void>.delayed(Duration.zero);
    expect(drained, false);
    expect(f.released, isEmpty);
    expect(pool.resourceBudget.used[SceneResource.sourcePages], 2);
    native.complete();
    await barrier;
    expect(await preparing, isNull);
    expect(registry.records, isEmpty);
    expect(registry.processBudget.registeredFaces, 1);
    expect(pool.owners, 1);
    expect(await session.prove(accepted), true);
    session.close();
    await session.closed;
    expect(pool.resourceBudget.used.values, everyElement(0));
  });

  test(
    'A to B to A rejects late fixed preparation while fresh A can prepare',
    () async {
      final f = FixedSessionFixture();
      await f.prepareNavigation();
      addTearDown(f.dispose);
      final entered = Completer<void>(), native = Completer<void>();
      var current = surfaceActivation(1);
      final budget = SceneResourceBudget(),
          allocations = SurfaceAllocationBudget();
      final registry = FontRegistry(
        processBudget: ProcessFontBudget(),
        register: (Uint8List _, String alias) {
          entered.complete();
          return native.future;
        },
      );
      Future<PreparedReaderSession> open(FontRegistry fonts) async =>
          (await PreparedReaderSession.openUnit(
            pool: PageSurfacePool(
              resourceBudget: budget,
              allocations: allocations,
            ),
            unit: f.navigator.units.first,
            navigator: f.navigator,
            fixedSources: f.sources(fonts: fonts),
            loadSection: (i) async => f.reflow[i],
            theme: surfaceTheme,
            activation: current,
            isActivationCurrent: (captured) => captured == current,
          ))!;
      final old = await open(registry);
      final pending = old.prepare(old.position, TurnDirection.next);
      await entered.future;
      current = ServerSession(
        endpoint: ServerEndpoint.parse('https://b.example.test/').endpoint!,
        generation: 2,
      );
      old.invalidatePreparation();
      current = surfaceActivation(3);
      final fresh = await open(
        FontRegistry(processBudget: ProcessFontBudget()),
      );
      native.complete();
      expect(await pending, isNull);
      await old.stopAndDrain();
      expect(await old.prove(old.position), false);
      final turn = (await fresh.prepare(fresh.position, TurnDirection.next))!;
      expect(turn.target.sectionIndex, 1);
      turn.release();
      old.close();
      fresh.close();
      await Future.wait([old.closed, fresh.closed]);
      expect(budget.used.values, everyElement(0));
      expect(allocations.images.totalBytes, 0);
    },
  );
}
