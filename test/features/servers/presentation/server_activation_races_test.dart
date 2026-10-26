import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/server_key.dart';
import 'package:shiori/core/config/validated_snapshot.dart';
import 'package:shiori/core/network/session_transport.dart';
import 'package:shiori/features/servers/data/server_activation_state.dart';

import '../server_activation_test_support.dart';

void main() {
  for (final phase in ['health', 'snapshot']) {
    test(
      'cancel during $phase completes silently, consumes late error, never retries',
      () async {
        final entered = Completer<void>();
        final pending = Completer<ResponseBody>();
        var retries = 0;
        final h = ActivationHarness(
          retry: (_, _) {
            retries++;
            return null;
          },
          respond: (_, options, index) {
            if (options.uri.path.endsWith(phase)) {
              entered.complete();
              return pending.future;
            }
            return jsonBody(fixture('health_ok.json'));
          },
        );
        await h.restore();
        final call = h.activate('a');
        await entered.future;
        h.controller.cancelCandidate();
        await call;
        expect(h.state.session, isNull);
        expect(h.state.failure, isNull);
        expect(h.state.phase, CandidatePhase.idle);
        expect(h.candidates.single.forceClosed, isTrue);
        pending.completeError(StateError('abandoned adapter error'));
        await pumpEventQueue(times: 3);
        expect(h.states.any((s) => s.hasError), isFalse);
        expect(h.store.commits, isEmpty);
        expect(retries, 0);
      },
    );
  }

  for (final aPhase in ['health', 'snapshot']) {
    for (final bPhase in ['health', 'snapshot']) {
      test(
        'A($aPhase) -> B($bPhase) -> A discards both late responses',
        () async {
          final aEntered = Completer<void>();
          final bEntered = Completer<void>();
          final lateA = Completer<ResponseBody>();
          final lateB = Completer<ResponseBody>();
          var aSessions = 0;
          final h = ActivationHarness(
            respond: (session, options, index) {
              final isA = session.endpoint == endpoint('a');
              if (isA && index == 0) aSessions++;
              if (isA && aSessions == 1 && options.uri.path.endsWith(aPhase)) {
                aEntered.complete();
                return lateA.future;
              }
              if (!isA && options.uri.path.endsWith(bPhase)) {
                bEntered.complete();
                return lateB.future;
              }
              return jsonBody(index == 0 ? fixture('health_ok.json') : '{}');
            },
          );
          await h.restore();
          final firstA = h.activate('a');
          await aEntered.future;
          final b = h.activate('b');
          await bEntered.future;
          final secondA = h.activate('a');
          await secondA;
          await Future.wait([firstA, b]);
          final selected = h.state.session!;
          expect(selected.endpoint, endpoint('a'));
          expect(h.candidates.take(2).every((a) => a.forceClosed), isTrue);
          lateB.complete(
            jsonBody(bPhase == 'health' ? fixture('health_ok.json') : '{}'),
          );
          lateA.complete(
            jsonBody(aPhase == 'health' ? fixture('health_ok.json') : '{}'),
          );
          await pumpEventQueue(times: 3);
          expect(h.state.session, same(selected));
          expect(h.state.failure, isNull);
          expect(h.store.commits, [selected.serverKey]);
        },
      );
    }
  }

  test(
    'supersession completes even when snapshot validator ignores cancellation',
    () async {
      final entered = Completer<void>();
      final abandoned = Completer<ValidatedSnapshot>();
      final validator = FakeSnapshotValidator()
        ..respond = (transport) {
          if (transport.session.endpoint == endpoint('a')) {
            entered.complete();
            return abandoned.future;
          }
          return Future.value(snapshot('B payload'));
        };
      final h = ActivationHarness(validator: validator);
      await h.restore();
      final first = h.activate('a');
      await entered.future;
      await h.activate('b');
      await first;
      abandoned.completeError(
        StateError('late worker-like validation failure'),
      );
      await pumpEventQueue(times: 3);
      expect(h.state.session!.endpoint, endpoint('b'));
      expect(h.state.failure, isNull);
      expect(h.store.commits, [ServerKey(endpoint('b'))]);
    },
  );

  test('active A -> B -> A rejects delayed HTTP, cover, file and worker publications', () async {
    final h = ActivationHarness();
    await h.restore();
    await h.activate('a');
    final a = h.state.session!;
    final lateA = Completer<void>();
    final lateB = Completer<void>();
    final published = <String>[];
    final first = lateA.future.then((_) {
      for (final kind in ['HTTP', 'cover', 'file', 'worker']) {
        h.guard.publish(a, () => published.add('old A $kind'));
      }
    });
    await h.activate('b');
    final b = h.state.session!;
    final second = lateB.future.then((_) {
      for (final kind in ['HTTP', 'cover', 'file', 'worker']) {
        h.guard.publish(b, () => published.add('old B $kind'));
      }
    });
    await h.activate('a');
    final current = h.state.session!;
    expect(current.serverKey, a.serverKey);
    expect(current.generation, greaterThan(b.generation));
    lateA.complete();
    lateB.complete();
    await Future.wait([first, second]);
    expect(published, isEmpty);
    h.guard.publish(current, () => published.add('current'));
    expect(published, ['current']);
    expect(h.state.session, same(current));
    expect(h.activeAdapters.take(2).every((a) => a.forceClosed), isTrue);
  });

  test('cancel validation keeps the active transport usable', () async {
    final entered = Completer<void>();
    final pending = Completer<ResponseBody>();
    final h = ActivationHarness(
      respond: (session, _, index) {
        if (session.endpoint == endpoint('b')) {
          entered.complete();
          return pending.future;
        }
        return jsonBody(index == 0 ? fixture('health_ok.json') : '{}');
      },
    );
    await h.restore();
    await h.activate('a');
    final old = h.state.session!;
    final switching = h.activate('b');
    await entered.future;
    expect(h.state.session, same(old));
    h.controller.cancelCandidate();
    await switching;
    expect(h.state.session, same(old));
    final active = h.container.read(sessionTransportProvider(old));
    expect((await active.getJson(['api', 'health'])).statusCode, 200);
    expect(h.activeAdapters.single.closed, isFalse);
    expect(h.state.failure, isNull);
    pending.complete(jsonBody(fixture('health_ok.json')));
  });

  test(
    'container disposal completes pending validation without publishing',
    () async {
      final entered = Completer<void>();
      final abandoned = Completer<ValidatedSnapshot>();
      final validator = FakeSnapshotValidator()
        ..respond = (_) {
          entered.complete();
          return abandoned.future;
        };
      final h = ActivationHarness(validator: validator);
      await h.restore();
      final call = h.activate('a');
      await entered.future;
      h.container.dispose();
      await call;
      abandoned.complete(snapshot());
      await pumpEventQueue(times: 3);
      expect(h.store.commits, isEmpty);
      expect(h.candidates.single.closed, isTrue);
    },
  );

  test('commit critical section serializes admission, latest queued candidate wins', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    final store = MemorySelectionStore()
      ..beforeCommit = () {
        if (!entered.isCompleted) {
          entered.complete();
          return release.future;
        }
        return Future.value();
      };
    final h = ActivationHarness(store: store);
    await h.restore();
    final a = h.activate('a');
    await entered.future;
    expect(h.state.phase, CandidatePhase.committing);
    final b = h.activate('b');
    final c = h.activate('c');
    await Future<void>.value();
    expect(h.candidates, hasLength(1));
    release.complete();
    await Future.wait([a, b, c]);
    expect(store.maxInFlight, 1);
    expect(store.commits, [ServerKey(endpoint('a')), ServerKey(endpoint('c'))]);
    expect(h.state.session!.endpoint, endpoint('c'));
    expect(h.candidates, hasLength(2));
  });

  test('cancel during dispatched commit cancels queued admission and completes transaction', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    final store = MemorySelectionStore()
      ..beforeCommit = () {
        entered.complete();
        return release.future;
      };
    final h = ActivationHarness(store: store);
    await h.restore();
    final a = h.activate('a');
    await entered.future;
    final b = h.activate('b');
    h.controller.cancelCandidate();
    release.complete();
    await Future.wait([a, b]);
    expect(h.state.session!.endpoint, endpoint('a'));
    expect(h.state.failure, isNull);
    expect(store.active, h.state.session!.serverKey);
    expect(h.candidates, hasLength(1));
  });
}
