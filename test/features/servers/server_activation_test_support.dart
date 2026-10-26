import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/selection_storage_exception.dart';
import 'package:shiori/core/config/server_endpoint.dart';
import 'package:shiori/core/config/server_key.dart';
import 'package:shiori/core/config/server_selection_store.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/core/config/session_publication_guard.dart';
import 'package:shiori/core/config/stored_server.dart';
import 'package:shiori/core/config/validated_snapshot.dart';
import 'package:shiori/core/network/session_transport.dart';
import 'package:shiori/features/servers/data/candidate_snapshot_validator.dart';
import 'package:shiori/features/servers/data/server_activation_dependencies.dart';
import 'package:shiori/features/servers/data/server_activation_state.dart';
import 'package:shiori/features/servers/presentation/server_activation_controller.dart';

import '../../core/network/fake_server_adapter.dart';
export '../../core/network/fake_server_adapter.dart';

ServerEndpoint endpoint(String name) =>
    ServerEndpoint.parse('https://$name.example.test/Reader/').endpoint!;
String fixture(String name) =>
    File('test/fixtures/server/$name').readAsStringSync();
ValidatedSnapshot snapshot([String payload = 'validated synthetic payload']) =>
    ValidatedSnapshot(
      payloadText: payload,
      schemaVersion: 1,
      revision: 7,
      etag: 'W/"opaque ETag"',
      fetchedAt: DateTime.utc(2026, 10, 26),
    );

/// Unknown calls (including any delete) are recorded and fail.
final class MemorySelectionStore implements ServerSelectionStore {
  final Map<ServerKey, StoredServer> servers = {};
  final Map<ServerKey, ValidatedSnapshot> snapshots = {};
  final List<ServerKey> commits = [];
  final List<Symbol> unexpectedCalls = [];
  ServerKey? active;
  SelectionStorageException? failure;
  Future<void> Function()? beforeCommit;
  Future<void> Function()? beforeRead;
  int inFlight = 0;
  int maxInFlight = 0;
  int touches = 0;

  @override
  Future<ServerKey?> readActiveServer() async {
    await beforeRead?.call();
    if (failure != null) throw failure!;
    return active;
  }

  @override
  Future<StoredServer?> readServer(ServerKey key) async => servers[key];
  @override
  Future<ValidatedSnapshot?> readCurrentSnapshot(ServerKey key) async =>
      snapshots[key];
  @override
  Future<void> touchLastUsed(ServerKey key) async {
    touches++;
    final old = servers[key]!;
    servers[key] = StoredServer(
      canonicalEndpoint: old.canonicalEndpoint,
      createdAt: old.createdAt,
      lastUsedAt: DateTime.utc(2026, 10, 27),
    );
  }

  @override
  Future<void> commitActivation({
    required ServerEndpoint endpoint,
    required ServerKey key,
    required ValidatedSnapshot snapshot,
  }) async {
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    try {
      await beforeCommit?.call();
      if (failure != null) throw failure!;
      expect(key, ServerKey(endpoint));
      final now = DateTime.utc(2026, 10, 26);
      servers[key] = StoredServer(
        canonicalEndpoint: endpoint.canonicalRoot,
        createdAt: servers[key]?.createdAt ?? now,
        lastUsedAt: now,
      );
      snapshots[key] = snapshot;
      active = key;
      commits.add(key);
    } finally {
      inFlight--;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    unexpectedCalls.add(invocation.memberName);
    throw StateError('Unexpected selection store command');
  }
}

final class FakeSnapshotValidator implements CandidateSnapshotValidator {
  final List<SessionTransport> calls = [];
  Future<ValidatedSnapshot> Function(SessionTransport)? respond;

  @override
  Future<ValidatedSnapshot> validate(SessionTransport transport) async {
    calls.add(transport);
    if (respond != null) return respond!(transport);
    await transport.getJson(['api', 'library', 'snapshot']);
    return snapshot();
  }
}

final class ActivationHarness {
  ActivationHarness({
    MemorySelectionStore? store,
    FakeSnapshotValidator? validator,
    FutureOr<ResponseBody> Function(ServerSession, RequestOptions, int)?
    respond,
    Duration? Function(int, Object)? retry,
  }) : store = store ?? MemorySelectionStore(),
       validator = validator ?? FakeSnapshotValidator() {
    container = ProviderContainer.test(
      retry: retry ?? (_, _) => null,
      overrides: [
        serverSelectionStoreProvider.overrideWithValue(this.store),
        candidateSnapshotValidatorProvider.overrideWithValue(this.validator),
        candidateTransportFactoryProvider.overrideWithValue((session) {
          final adapter = FakeServerAdapter(
            (options, index) =>
                respond?.call(session, options, index) ??
                jsonBody(index == 0 ? fixture('health_ok.json') : '{}'),
          );
          candidates.add(adapter);
          return SessionTransport(session, adapter: adapter);
        }),
        sessionTransportProvider.overrideWith((ref, session) {
          final adapter = FakeServerAdapter((_, _) => jsonBody());
          activeAdapters.add(adapter);
          final transport = SessionTransport(session, adapter: adapter);
          ref.onDispose(transport.dispose);
          return transport;
        }),
      ],
    );
    container.listen(
      serverActivationControllerProvider,
      (_, next) => states.add(next),
    );
    addTearDown(() => expect(this.store.unexpectedCalls, isEmpty));
  }

  final MemorySelectionStore store;
  final FakeSnapshotValidator validator;
  final List<FakeServerAdapter> candidates = [];
  final List<FakeServerAdapter> activeAdapters = [];
  final List<AsyncValue<ServerActivationState>> states = [];
  late final ProviderContainer container;
  ServerActivationController get controller =>
      container.read(serverActivationControllerProvider.notifier);
  ServerActivationState get state =>
      container.read(serverActivationControllerProvider).requireValue;
  SessionPublicationGuard get guard =>
      container.read(sessionPublicationGuardProvider);
  Future<ServerActivationState> restore() =>
      container.read(serverActivationControllerProvider.future);
  Future<void> activate(String name) =>
      controller.activate(endpoint(name).canonicalRoot);
}
