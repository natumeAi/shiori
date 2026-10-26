import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/selection_storage_exception.dart';
import 'package:shiori/core/config/server_key.dart';
import 'package:shiori/core/config/stored_server.dart';
import 'package:shiori/core/network/request_cancelled.dart';
import 'package:shiori/core/network/session_transport.dart';
import 'package:shiori/features/servers/data/server_activation_state.dart';
import 'package:shiori/features/servers/data/server_activation_failure.dart';
import 'package:shiori/features/servers/presentation/server_activation_controller.dart';

import '../server_activation_test_support.dart';

void main() {
  test('switch after relaunch does not rebuild activation through the retired family', () async {
    final store = MemorySelectionStore();
    await store.commitActivation(
      endpoint: endpoint('a'),
      key: ServerKey(endpoint('a')),
      snapshot: snapshot(),
    );
    final h = ActivationHarness(store: store);
    final restored = (await h.restore()).session!;
    await h.activate('b');
    await h.container.pump();
    expect(h.state.session!.endpoint, endpoint('b'));
    expect(h.state.session!.generation, greaterThan(restored.generation));
    expect(h.guard.isCurrent(h.state.session!), isTrue);
    expect(h.activeAdapters, hasLength(2));
    expect(h.activeAdapters.first.closed, isTrue);
    expect(h.activeAdapters.last.closed, isFalse);
  });

  test(
    'cancel while restoring leaves restoration in control of initial state',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final store = MemorySelectionStore()
        ..beforeRead = () {
          entered.complete();
          return release.future;
        };
      final h = ActivationHarness(store: store);
      await entered.future;
      final queued = h.activate('a');
      h.controller.cancelCandidate();
      expect(
        h.container.read(serverActivationControllerProvider).isLoading,
        isTrue,
      );
      release.complete();
      await h.restore();
      await queued;
      expect(h.candidates, isEmpty);
      expect(h.state.session, isNull);
    },
  );

  test('empty restore is unconfigured and sends no HTTP', () async {
    final h = ActivationHarness();
    expect(
      h.container.read(serverActivationControllerProvider).isLoading,
      isTrue,
    );
    expect((await h.restore()).session, isNull);
    expect(h.candidates, isEmpty);
    expect(h.activeAdapters, isEmpty);
    expect(h.store.commits, isEmpty);
  });

  test(
    'relaunch restores only committed canonical endpoint without HTTP',
    () async {
      final store = MemorySelectionStore();
      await store.commitActivation(
        endpoint: endpoint('a'),
        key: ServerKey(endpoint('a')),
        snapshot: snapshot(),
      );
      final h = ActivationHarness(store: store);
      final restored = (await h.restore()).session!;
      expect(restored.endpoint, endpoint('a'));
      expect(h.guard.isCurrent(restored), isTrue);
      expect(h.candidates, isEmpty);
      expect(h.activeAdapters.single.requests, isEmpty);
      h.container.invalidate(serverActivationControllerProvider);
      final relaunched = (await h.restore()).session!;
      expect(relaunched.serverKey, restored.serverKey);
      expect(relaunched.generation, greaterThan(restored.generation));
      expect(h.guard.isCurrent(restored), isFalse);
      expect(h.validator.calls, isEmpty);
      expect(store.touches, 0);
    },
  );

  for (final text in [
    'not a URL',
    'https://other.example.test/',
    'HTTPS://A.EXAMPLE.TEST:443/Reader',
  ]) {
    test(
      'invalid, mismatched or noncanonical stored endpoint is preserved: $text',
      () async {
        final store = MemorySelectionStore();
        final key = store.active = ServerKey(endpoint('a'));
        store.servers[key] = StoredServer(
          canonicalEndpoint: text,
          createdAt: DateTime.utc(2026),
          lastUsedAt: DateTime.utc(2026),
        );
        final h = ActivationHarness(store: store);
        await expectLater(
          h.restore(),
          throwsA(
            isA<SelectionStorageException>().having(
              (e) => e.issue,
              'issue',
              SelectionStorageIssue.invalidSelection,
            ),
          ),
        );
        expect(store.active, key);
        expect(store.servers[key]!.canonicalEndpoint, text);
        expect(h.candidates, isEmpty);
      },
    );
  }

  test('missing server row is a recoverable restore failure', () async {
    final store = MemorySelectionStore()..active = ServerKey(endpoint('a'));
    final h = ActivationHarness(store: store);
    await expectLater(h.restore(), throwsA(isA<SelectionStorageException>()));
    expect(store.active, isNotNull);
  });

  test('future schema restore is not reset or retried', () async {
    final store = MemorySelectionStore()
      ..failure = const SelectionStorageException(
        SelectionStorageIssue.newerSchema,
      );
    var retries = 0;
    final h = ActivationHarness(
      store: store,
      retry: (_, _) {
        retries++;
        return null;
      },
    );
    await expectLater(h.restore(), throwsA(isA<SelectionStorageException>()));
    expect(h.store.commits, isEmpty);
    expect(retries, 1); // Riverpod consults policy once, which declines retry.
  });

  test(
    'validates health then unconditional snapshot, commits raw value once',
    () async {
      final h = ActivationHarness();
      await h.restore();
      await h.activate('a');
      final requests = h.candidates.single.requests;
      expect(requests.map((r) => r.uri.path), [
        '/Reader/api/health',
        '/Reader/api/library/snapshot',
      ]);
      expect(requests.every((r) => r.method == 'GET'), isTrue);
      expect(
        requests.expand((r) => r.headers.keys),
        isNot(anyOf(contains('If-None-Match'), contains('If-Modified-Since'))),
      );
      expect(h.state.phase, CandidatePhase.idle);
      expect(h.state.session!.serverKey, ServerKey(endpoint('a')));
      expect(h.guard.isCurrent(h.validator.calls.single.session), isFalse);
      expect(
        h.state.session!.generation,
        greaterThan(h.validator.calls.single.session.generation),
      );
      final stored = await h.store.readCurrentSnapshot(h.store.active!);
      expect(stored!.payloadText, snapshot().payloadText);
      expect(stored.etag, 'W/"opaque ETag"');
      expect(stored.schemaVersion, 1);
      expect(stored.revision, 7);
      expect(stored.fetchedAt, snapshot().fetchedAt);
      expect(h.candidates.single.forceClosed, isTrue);
      expect(h.activeAdapters.single.closed, isFalse);
      expect(
        h.states.where((s) => s.hasValue).map((s) => s.requireValue.phase),
        containsAllInOrder([
          CandidatePhase.validating,
          CandidatePhase.committing,
          CandidatePhase.idle,
        ]),
      );
    },
  );

  test(
    'commit failure preserves previous selection, snapshot, transport and work',
    () async {
      final h = ActivationHarness();
      await h.restore();
      await h.activate('a');
      final old = h.state.session!;
      final oldSnapshot = h.store.snapshots[old.serverKey];
      var cancelled = false;
      h.guard.onRetire(old, () => cancelled = true);
      h.store.failure = const SelectionStorageException(
        SelectionStorageIssue.unavailable,
      );
      await h.activate('b');
      expect(h.state.session, same(old));
      expect(h.state.failure!.kind, ActivationFailureKind.storage);
      expect(h.store.active, old.serverKey);
      expect(h.store.snapshots[old.serverKey], same(oldSnapshot));
      expect(h.store.servers.containsKey(ServerKey(endpoint('b'))), isFalse);
      expect(h.activeAdapters.single.closed, isFalse);
      expect(cancelled, isFalse);
      expect(h.guard.isCurrent(old), isTrue);
    },
  );

  test(
    'success retires transport and pending work before new session publication',
    () async {
      final h = ActivationHarness();
      await h.restore();
      await h.activate('a');
      final old = h.state.session!;
      final transport = h.container.read(sessionTransportProvider(old));
      var cancelled = false;
      h.guard.onRetire(old, () {
        cancelled = true;
        expect(h.guard.isCurrent(old), isFalse);
        expect(h.state.session, old);
      });
      await h.activate('b');
      expect(cancelled, isTrue);
      expect(h.activeAdapters.first.forceClosed, isTrue);
      await expectLater(
        transport.getJson(['api', 'health']),
        throwsA(isA<RequestCancelled>()),
      );
      expect(
        h.store.servers.keys,
        containsAll([old.serverKey, h.state.session!.serverKey]),
      );
      expect(h.store.snapshots.keys, containsAll(h.store.servers.keys));
      expect(h.store.unexpectedCalls, isEmpty);
    },
  );

  test('invalid candidate makes no client and keeps selected server', () async {
    final h = ActivationHarness();
    await h.restore();
    await h.activate('a');
    final old = h.state.session;
    await h.controller.activate('https://user:secret@example.test/');
    expect(h.state.session, same(old));
    expect(h.state.failure!.kind, ActivationFailureKind.invalidEndpoint);
    expect(h.state.failure!.endpointIssue, isNotNull);
    expect(h.candidates, hasLength(1));
  });
}
