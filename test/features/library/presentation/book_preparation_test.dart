import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/router.dart';
import 'package:shiori/app/routes.dart';
import 'package:shiori/features/library/data/publications/prepare_book_exception.dart';

import 'preparation_ui_test_support.dart';

void main() {
  testWidgets('prepare, byte progress, check and honest ready; refresh', (
    tester,
  ) async {
    final h = PreparationUiHarness();
    await h.open(tester);
    expect(h.controller.refreshes, isEmpty);
    await tester.tap(find.text(l10n.libraryPreparationStart));
    await tester.pump();
    expect(h.controller.refreshes, [false]);
    expect(find.text(l10n.libraryPreparationWorking), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      isNull,
    );
    h.controller.progress(25, 100);
    await tester.pump();
    expect(find.text(l10n.libraryPreparationProgress(25)), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      .25,
    );
    h.controller.progress(100, 100);
    await tester.pump();
    expect(find.text(l10n.libraryPreparationCheckingHelp), findsOneWidget);
    expect(find.text(l10n.libraryPreparationReady), findsNothing);
    final book = h.controller.complete();
    await tester.pumpAndSettle();
    expect(find.text(l10n.libraryPreparationReady), findsOneWidget);
    expect(find.text(l10n.libraryPreparationRefreshHelp), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining(book.identity.sha256), findsNothing);
    await tester.tap(find.text(l10n.libraryPreparationRefresh));
    await tester.pump();
    expect(h.controller.refreshes, [false, true]);
    expect(book.isReleased, isTrue);
    expect(find.text(l10n.libraryPreparationReady), findsNothing);
    h.controller.complete();
    await tester.pumpAndSettle();
    expect(find.text(l10n.libraryPreparationReady), findsOneWidget);
  });

  testWidgets(
    'unknown or zero totals stay indeterminate; cancel permits prepare',
    (tester) async {
      final h = PreparationUiHarness();
      await h.open(tester);
      await tester.tap(find.text(l10n.libraryPreparationStart));
      for (final total in [null, 0]) {
        h.controller.progress(10, total);
        await tester.pump();
        expect(
          tester
              .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator),
              )
              .value,
          isNull,
        );
      }
      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();
      expect(h.controller.cancellations, 1);
      expect(find.text(l10n.libraryPreparationStart), findsOneWidget);
      expect(find.text(l10n.commonRetry), findsNothing);
      await tester.tap(find.text(l10n.libraryPreparationStart));
      await tester.pump();
      expect(h.controller.refreshes, [false, false]);
    },
  );

  final failures = {
    PrepareBookFailure.unavailable: l10n.libraryPreparationUnavailable,
    PrepareBookFailure.network: l10n.serverConnectionFailed,
    PrepareBookFailure.tooLarge: l10n.libraryPreparationTooLarge,
    PrepareBookFailure.cacheBusy: l10n.libraryPreparationBusy,
    PrepareBookFailure.invalidStructure: l10n.libraryPreparationInvalid,
    PrepareBookFailure.unsupportedStructure: l10n.libraryPreparationUnsupported,
    PrepareBookFailure.storage: l10n.libraryPreparationStorage,
    PrepareBookFailure.unauthorized: l10n.serverAccessDenied,
    PrepareBookFailure.tls: l10n.serverTlsFailed,
    PrepareBookFailure.server: l10n.serverResponseFailed,
    PrepareBookFailure.redirect: l10n.serverFinalAddress,
    PrepareBookFailure.workerUnavailable: l10n.libraryPreparationInterrupted,
  };

  testWidgets(
    'leaving the route retains progress and metadata, releasing ready owners',
    (tester) async {
      final h = PreparationUiHarness();
      await h.open(tester);
      await tester.tap(find.text(l10n.libraryPreparationStart));
      await tester.pump();
      final controller = h.controller;
      h.app.container.read(routerProvider).pop();
      await tester.pumpAndSettle();
      expect(controller.disposed, isFalse);
      expect(controller.cancellations, 0);
      controller.progress(60, 100);
      await tester.pump();
      final book = controller.complete();
      await tester.pumpAndSettle();
      expect(controller.disposed, isFalse);
      expect(book.isReleased, isTrue);
      await tester.tap(find.text('Fixture Book 7'));
      await tester.pumpAndSettle();
      expect(h.controllers, hasLength(1));
      expect(find.text(l10n.libraryPreparationReady), findsOneWidget);
      final reacquired = controller.owned!;
      expect(reacquired.isReleased, isFalse);
      h.app.container.read(routerProvider).pop();
      await tester.pumpAndSettle();
      expect(reacquired.isReleased, isTrue);
      await tester.tap(find.byTooltip(l10n.serverChangeTitle));
      await tester.pumpAndSettle();
      await h.app.connect(tester);
      await tester.pumpAndSettle();
      expect(controller.disposed, isTrue);
      expect(book.isReleased, isTrue);
    },
  );

  testWidgets(
    'server switch discards preparing route and late first-A result',
    (tester) async {
      final h = PreparationUiHarness();
      await h.open(tester);
      final firstA = h.app.session;
      await tester.tap(find.text(l10n.libraryPreparationStart));
      await tester.pump();
      final oldController = h.controller;
      await tester.tap(find.byTooltip(l10n.serverChangeTitle));
      await tester.pumpAndSettle();
      await h.app.connect(tester);
      await tester.pumpAndSettle();
      expect(h.app.container.read(routerProvider).canPop(), isFalse);
      expect(
        h.app.container
            .read(routerProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        const HomeRoute().location,
      );
      expect(find.text(l10n.libraryPreparationWorking), findsNothing);
      expect(oldController.disposed, isTrue);
      await tester.tap(find.text('Fixture Book 7'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.libraryPreparationStart), findsOneWidget);
      expect(h.controller.capturedSession, isNot(firstA));
      await tester.tap(find.byTooltip(l10n.serverChangeTitle));
      await tester.pumpAndSettle();
      await h.app.connect(tester, 'a');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fixture Book 7'));
      await tester.pumpAndSettle();
      expect(h.app.session.serverKey, firstA.serverKey);
      expect(h.app.session.generation, greaterThan(firstA.generation));
      final late = oldController.complete();
      await tester.pumpAndSettle();
      expect(late.isReleased, isTrue);
      expect(find.text(l10n.libraryPreparationReady), findsNothing);
      expect(find.text(l10n.libraryPreparationStart), findsOneWidget);
      expect(h.controller.refreshes, isEmpty);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'all preparation states fit 200% text at 320px in ${brightness.name}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final h = PreparationUiHarness();
        await h.open(tester, scale: 2);
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text(l10n.libraryPreparationStart).hitTestable(),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.text(l10n.libraryPreparationStart));
        await tester.pump();
        await tester.scrollUntilVisible(
          find.text(l10n.commonCancel).hitTestable(),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        expect(tester.takeException(), isNull);
        h.controller.progress(5, 10);
        await tester.pump();
        expect(tester.takeException(), isNull);
        h.controller.complete();
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text(l10n.libraryPreparationRefresh).hitTestable(),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        expect(tester.takeException(), isNull);
        for (final failure in failures.keys) {
          h.controller.fail(failure);
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text(l10n.commonRetry).hitTestable(),
            200,
            scrollable: find.byType(Scrollable).last,
          );
          expect(tester.takeException(), isNull, reason: failure.name);
        }
      },
    );
  }
  for (final entry in failures.entries) {
    testWidgets('${entry.key.name} has recovery copy and retries preparation', (
      tester,
    ) async {
      final h = PreparationUiHarness();
      await h.open(tester);
      await tester.tap(find.text(l10n.libraryPreparationStart));
      h.controller.fail(entry.key);
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
      await tester.ensureVisible(find.text(l10n.commonRetry));
      await tester.tap(find.text(l10n.commonRetry));
      await tester.pump();
      expect(h.controller.refreshes, [false, false]);
      expect(find.text(entry.value), findsNothing);
      h.controller.complete();
      await tester.pumpAndSettle();
      expect(find.text(l10n.libraryPreparationReady), findsOneWidget);
    });
  }
}
