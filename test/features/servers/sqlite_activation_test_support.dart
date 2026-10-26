import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/core/config/server_selection_store.dart';
import 'package:shiori/core/config/session_publication_guard.dart';
import 'package:shiori/core/config/validated_snapshot.dart';
import 'package:shiori/core/network/session_transport.dart';
import 'package:shiori/core/storage/app_directories.dart';
import 'package:shiori/core/storage/sqlite_store.dart';
import 'package:shiori/features/servers/data/server_activation_dependencies.dart';
import 'package:shiori/features/servers/data/server_activation_state.dart';
import 'package:shiori/features/servers/presentation/server_activation_controller.dart';

import '../../core/storage/store_test_support.dart';
import 'server_activation_test_support.dart' as fake;

/// Real production selection binding and SQLite worker; only HTTP and Phase C
/// validation are substituted. Fault tests may supply a real fault-hook worker.
final class SqliteActivationHarness {
  SqliteActivationHarness(
    StoreFixture directories, {
    SqliteStore? worker,
    ServerSelectionStore? selectionStore,
    bool configureValidator = true,
  }) {
    validator.respond = (transport) async {
      await transport.getJson(['api', 'library', 'snapshot']);
      return snapshots[transport.session.serverKey.canonicalRoot] ??
          fake.snapshot();
    };
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appDirectoriesProvider.overrideWithValue(directories),
        if (selectionStore != null)
          serverSelectionStoreProvider.overrideWithValue(selectionStore),
        if (worker != null)
          sqliteStoreProvider.overrideWith((ref) async {
            ref.onDispose(() => unawaited(worker.close()));
            return worker;
          }),
        if (configureValidator)
          candidateSnapshotValidatorProvider.overrideWithValue(validator),
        candidateTransportFactoryProvider.overrideWithValue((session) {
          final adapter = fake.FakeServerAdapter((options, _) {
            if (options.uri.path.endsWith('/api/health')) {
              return fake.jsonBody(fake.fixture('health_ok.json'));
            }
            return fake.jsonBody('{}');
          });
          candidates.add(adapter);
          return SessionTransport(session, adapter: adapter);
        }),
        sessionTransportProvider.overrideWith((ref, session) {
          final adapter = fake.FakeServerAdapter((_, _) => fake.jsonBody());
          activeAdapters.add(adapter);
          final transport = SessionTransport(session, adapter: adapter);
          ref.onDispose(transport.dispose);
          return transport;
        }),
      ],
    );
    subscription = container.listen(
      serverActivationControllerProvider,
      (_, _) {},
    );
  }

  final validator = fake.FakeSnapshotValidator();
  final snapshots = <String, ValidatedSnapshot>{};
  final candidates = <fake.FakeServerAdapter>[];
  final activeAdapters = <fake.FakeServerAdapter>[];
  late final ProviderContainer container;
  late final ProviderSubscription<AsyncValue<ServerActivationState>>
  subscription;
  bool _closed = false;

  ServerSelectionStore get store =>
      container.read(serverSelectionStoreProvider);
  SessionPublicationGuard get guard =>
      container.read(sessionPublicationGuardProvider);
  ServerActivationState get state =>
      container.read(serverActivationControllerProvider).requireValue;
  Future<ServerActivationState> restore() =>
      container.read(serverActivationControllerProvider.future);
  Future<void> activate(String name) => container
      .read(serverActivationControllerProvider.notifier)
      .activate(fake.endpoint(name).canonicalRoot);

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final worker = container.read(sqliteStoreProvider).asData?.value;
    subscription.close();
    container.dispose();
    if (worker != null) await worker.close();
  }
}
