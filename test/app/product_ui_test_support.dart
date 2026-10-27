import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/core/config/server_key.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/core/network/session_transport.dart';
import 'package:shiori/features/library/data/library_snapshot_cache.dart';
import 'package:shiori/features/library/data/library_snapshot_repository.dart';
import 'package:shiori/features/library/data/library_snapshot_validator.dart';
import 'package:shiori/features/library/presentation/covers/cover_loader.dart';
import 'package:shiori/features/servers/data/server_activation_dependencies.dart';
import 'package:shiori/features/servers/presentation/server_activation_controller.dart';
import 'package:shiori/l10n/l10n.dart';

import '../features/servers/server_activation_test_support.dart' as activation;
import '../features/library/data/snapshot_cache_test_support.dart';

export '../features/servers/server_activation_test_support.dart'
    show endpoint, jsonBody;
export '../features/library/data/library_test_support.dart' show fixture;
export '../features/library/data/snapshot_cache_test_support.dart'
    show storedFixture;

final l10n = lookupAppLocalizations(const Locale('zh'));

class ProductUiHarness {
  ProductUiHarness({List<Override> overrides = const []}) {
    final validator = activation.FakeSnapshotValidator()
      ..respond = (transport) {
        if (snapshotFailure case final error?) throw error;
        return const LibrarySnapshotValidator().validate(transport);
      };
    container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        ...overrides,
        serverSelectionStoreProvider.overrideWithValue(store),
        candidateSnapshotValidatorProvider.overrideWithValue(validator),
        librarySnapshotCacheProvider.overrideWithValue(cache),
        candidateTransportFactoryProvider.overrideWithValue((session) {
          final adapter = activation.FakeServerAdapter(
            (options, _) => candidateResponse(options),
          );
          candidates.add(adapter);
          return SessionTransport(session, adapter: adapter);
        }),
        sessionTransportProvider.overrideWith((ref, session) {
          final adapter = activation.FakeServerAdapter(
            (options, _) => libraryResponse(options),
          );
          activeAdapters.add(adapter);
          final transport = SessionTransport(session, adapter: adapter);
          ref.onDispose(transport.dispose);
          return transport;
        }),
        librarySnapshotRepositoryProvider.overrideWith((ref, session) {
          final repository = LibrarySnapshotRepository(
            ref.watch(sessionTransportProvider(session)),
            cache,
            ref.watch(sessionPublicationGuardProvider),
            waitBeforeRetry: (_) async {},
          );
          ref.onDispose(repository.dispose);
          return repository;
        }),
        coverLoaderProvider.overrideWith((ref, session) {
          final loader = CoverLoader(
            ref.watch(sessionTransportProvider(session)),
            ref.watch(sessionPublicationGuardProvider),
          );
          ref.onDispose(loader.dispose);
          return loader;
        }),
      ],
    );
  }

  final store = activation.MemorySelectionStore();
  final cache = MemorySnapshotCache();
  final candidates = <activation.FakeServerAdapter>[];
  final activeAdapters = <activation.FakeServerAdapter>[];
  late final ProviderContainer container;
  Object? snapshotFailure;
  FutureOr<ResponseBody> Function(RequestOptions) candidateResponse =
      (options) => activation.jsonBody(
        activation.fixture(
          options.uri.path.endsWith('/health')
              ? 'health_ok.json'
              : 'snapshot_typical.json',
        ),
      );
  FutureOr<ResponseBody> Function(RequestOptions) libraryResponse = (_) =>
      activation.jsonBody(activation.fixture('snapshot_typical.json'));

  ServerSession get session =>
      container.read(serverActivationControllerProvider).requireValue.session!;

  Future<void> seed() async {
    final server = activation.endpoint('a');
    await store.commitActivation(
      endpoint: server,
      key: ServerKey(server),
      snapshot: activation.snapshot(),
    );
    cache.values[store.active!] = storedFixture();
  }

  Future<void> pump(
    WidgetTester tester, {
    double scale = 1,
    Brightness brightness = Brightness.light,
    bool settle = true,
  }) async {
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const ShioriApp()),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
    }
  }

  Future<void> connect(WidgetTester tester, [String name = 'b']) async {
    await tester.enterText(
      find.byType(TextFormField),
      activation.endpoint(name).normalizedText,
    );
    await tester.ensureVisible(find.text(l10n.serverConnect));
    await tester.tap(find.text(l10n.serverConnect));
  }
}
