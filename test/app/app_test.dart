import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/app/router.dart';
import 'package:shiori/app/routes.dart';
import 'package:shiori/app/startup_screen.dart';
import 'package:shiori/features/servers/presentation/server_setup_screen.dart';
import 'package:shiori/features/servers/presentation/server_activation_controller.dart';

import 'product_ui_test_support.dart';

void main() {
  testWidgets('restores before routing to setup without making requests', (
    tester,
  ) async {
    final h = ProductUiHarness();
    final restore = Completer<void>();
    h.store.beforeRead = () => restore.future;
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: h.container,
        child: const ShioriApp(),
      ),
    );
    await tester.pump();
    expect(find.byType(StartupScreen), findsOneWidget);
    expect(h.candidates, isEmpty);
    restore.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ServerSetupScreen), findsOneWidget);
  });

  testWidgets('successful setup validates then resets the route stack', (
    tester,
  ) async {
    final h = ProductUiHarness();
    await h.pump(tester);
    await h.connect(tester);
    await tester.pumpAndSettle();
    final router = h.container.read(routerProvider);
    expect(
      router.routeInformationProvider.value.uri.path,
      const HomeRoute().location,
    );
    expect(router.canPop(), isFalse);
    expect(find.text(l10n.libraryTitle), findsOneWidget);
    expect(h.candidates.single.requests.map((r) => r.uri.path), [
      '/Reader/api/health',
      '/Reader/api/library/snapshot',
    ]);
    expect(h.store.active, h.session.serverKey);
    expect(find.byType(ServerSetupScreen), findsNothing);
  });

  testWidgets('switch from a book discards all deep routes and old images', (
    tester,
  ) async {
    final h = ProductUiHarness();
    await h.seed();
    await h.pump(tester);
    final old = h.session;
    await tester.tap(find.text('Fixture Book 7'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(l10n.serverChangeTitle));
    await tester.pumpAndSettle();
    await h.connect(tester);
    await tester.pumpAndSettle();
    expect(h.session, isNot(old));
    expect(h.activeAdapters.first.closed, isTrue);
    final router = h.container.read(routerProvider);
    expect(
      router.routeInformationProvider.value.uri.path,
      const HomeRoute().location,
    );
    expect(router.canPop(), isFalse);
    expect(find.text(l10n.libraryPreparationPlaceholder), findsNothing);
    expect(
      find.text(l10n.serverCurrent(endpoint('b').normalizedText)),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip(l10n.serverChangeTitle));
    await tester.pumpAndSettle();
    await h.connect(tester, 'a');
    await tester.pumpAndSettle();
    expect(h.session.serverKey, old.serverKey);
    expect(h.session.generation, greaterThan(old.generation));
    expect(router.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('restore error offers retry and keeps stored selection', (
    tester,
  ) async {
    final h = ProductUiHarness();
    await h.seed();
    final selected = h.store.active;
    h.store.beforeRead = () =>
        Future.error(StateError('synthetic restore failure'));
    await h.pump(tester);
    expect(find.text(l10n.serverRestoreFailed), findsOneWidget);
    expect(h.store.active, selected);
    h.store.beforeRead = null;
    await tester.tap(find.text(l10n.commonRetry));
    await tester.pumpAndSettle();
    expect(find.text(l10n.libraryTitle), findsOneWidget);
    expect(
      h.container.read(serverActivationControllerProvider).hasError,
      isFalse,
    );
  });
}
