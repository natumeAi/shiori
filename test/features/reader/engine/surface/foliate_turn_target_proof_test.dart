import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/cfi/cfi.dart';
import 'package:shiori/features/reader/data/source/source_position.dart';
import 'package:shiori/features/reader/engine/motion/page_turn_engine.dart';
import 'package:shiori/features/reader/engine/motion/turn_acceptance.dart';
import 'package:shiori/features/reader/engine/motion/turn_intent_queue.dart';
import 'package:shiori/features/reader/engine/motion/turn_session.dart';
import 'package:shiori/features/reader/engine/pagination/anchor.dart';
import 'package:shiori/features/reader/engine/surface/prepared_page_position.dart';

import '../layout/layout_test_support.dart';
import 'surface_test_support.dart';

PreparedTurn _preview(PreparedTurn p, TurnPosition target) => PreparedTurn(
  origin: p.origin,
  target: target,
  direction: p.direction,
  releaseCallback: () {},
);

void main() {
  initEngineBinding();
  // foliateTurnTargetProof.test.ts:86-152. Fixed-layout iframe proof (:154)
  // remains outside S2's reflowable native page engine.
  test(
    'a different preview anchor on the same verified page is accepted',
    () async {
      final h = await SurfaceHarness.open();
      addTearDown(h.close);
      final origin = h.session.position;
      final preview = (await h.session.prepare(origin, TurnDirection.next))!;
      final result = await h.session.navigate(
        origin,
        TurnDirection.next,
        preview,
      );
      final foreground = result.position!;
      final span = h.section.pages[foreground.pageIndex].map.spans.first;
      final cfi = Cfi.export(
        h.section.document,
        SourcePosition(nodeIndex: span.nodeIndex, offset: span.start),
        sectionBase: h.section.sectionBase,
      );
      expect(cfi, isNot(foreground.cfi));
      final different = _preview(
        preview,
        changePosition(preview.target, cfi: cfi),
      );
      expect(
        await TurnAcceptance.verify(h.session, origin, foreground, different),
        isNull,
      );
      expect(h.session.position.cfi, foreground.cfi);
      expect(h.session.position.pageIndex, 11);
    },
  );

  test(
    'an invisible preview anchor is a mismatch and the session stays ready',
    () async {
      final h = await SurfaceHarness.open();
      addTearDown(h.close);
      final origin = h.session.position;
      final preview = (await h.session.prepare(origin, TurnDirection.next))!;
      final result = await h.session.navigate(
        origin,
        TurnDirection.next,
        preview,
      );
      final hidden = preparedPagePosition(
        h.section,
        12,
        atStart: false,
        atEnd: false,
      )!;
      final different = _preview(
        preview,
        changePosition(preview.target, cfi: hidden.cfi),
      );
      expect(
        await TurnAcceptance.verify(
          h.session,
          origin,
          result.position!,
          different,
        ),
        'anchor',
      );
      expect(h.session.state, TurnSessionState.ready);
      expect(await h.session.restore(origin), isTrue);
      expect(h.session.position, origin);
    },
  );

  test('an anchor that does not round-trip exactly is a mismatch', () async {
    final h = await SurfaceHarness.open();
    addTearDown(h.close);
    final origin = h.session.position;
    final preview = (await h.session.prepare(origin, TurnDirection.next))!;
    final result = await h.session.navigate(
      origin,
      TurnDirection.next,
      preview,
    );
    // DOM offsets convert through ToUint32; the resolved point is unchanged,
    // but exporting it cannot reproduce the oversized offset.
    final alias = preview.target.cfi.replaceFirstMapped(
      RegExp(r':(\d+)\)$'),
      (match) => ':${int.parse(match[1]!) + 0x100000000})',
    );
    expect(alias, isNot(preview.target.cfi));
    expect(
      PageAnchors(h.section).prove(alias).failure,
      AnchorFailure.roundTrip,
    );
    final different = _preview(
      preview,
      changePosition(preview.target, cfi: alias),
    );
    expect(
      await TurnAcceptance.verify(
        h.session,
        origin,
        result.position!,
        different,
      ),
      'anchor',
    );
  });

  final mismatches = <String, (TurnPosition Function(TurnPosition), String)>{
    'page': ((p) => changePosition(p, page: 12), 'page'),
    'page total': ((p) => changePosition(p, total: 26), 'page'),
    'section': ((p) => changePosition(p, section: 1), 'section'),
    'layout': ((p) => changePosition(p, layout: 'other-layout'), 'layout'),
    'anchor in another section': (
      (p) => changePosition(p, cfi: p.cfi.replaceFirst('/6/2!', '/6/4!')),
      'anchor',
    ),
  };
  for (final entry in mismatches.entries) {
    test(
      'a preview whose ${entry.key} differs from foreground is rejected',
      () async {
        final h = await SurfaceHarness.open();
        addTearDown(h.close);
        final origin = h.session.position;
        final preview = (await h.session.prepare(origin, TurnDirection.next))!;
        final result = await h.session.navigate(
          origin,
          TurnDirection.next,
          preview,
        );
        final different = _preview(preview, entry.value.$1(preview.target));
        expect(
          await TurnAcceptance.verify(
            h.session,
            origin,
            result.position!,
            different,
          ),
          entry.value.$2,
        );
        expect(h.session.state, TurnSessionState.ready);
        expect(h.session.position.pageIndex, 11);
      },
    );
  }

  test('a preview from another origin never navigates', () async {
    final h = await SurfaceHarness.open();
    addTearDown(h.close);
    final origin = h.session.position;
    final preview = (await h.session.prepare(origin, TurnDirection.next))!;
    final stale = changePosition(origin, cfi: '${origin.cfi}-stale');
    final result = await h.session.navigate(stale, TurnDirection.next, preview);
    expect(result.kind, TurnNavigationKind.mismatch);
    expect(result.reason, 'origin');
    expect(h.session.position, origin);
  });

  test(
    'a turn without a preview keeps the verified static and boundary paths',
    () async {
      final h = await SurfaceHarness.open();
      addTearDown(h.close);
      h.controller.configure(reducedMotion: true);
      expect((await h.turn(TurnDirection.next)).kind, TurnResultKind.committed);
      expect(h.controller.accepted.pageIndex, 11);
      expect(await h.session.prove(h.controller.accepted), isTrue);
      final end = await SurfaceHarness.open(page: 24);
      addTearDown(end.close);
      end.controller.configure(reducedMotion: true);
      expect(
        (await end.turn(TurnDirection.next)).kind,
        TurnResultKind.boundary,
      );
      expect(end.accepted, isEmpty);
      expect(end.controller.accepted.pageIndex, 24);
    },
  );
}
