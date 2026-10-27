import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/router.dart';
import 'package:shiori/app/routes.dart';
import 'package:shiori/features/library/presentation/widgets/book_cover.dart';

import '../../../app/product_ui_test_support.dart';

void main() {
  testWidgets(
    'root shelf order, folder order, metadata, cover fallback and back',
    (tester) async {
      final h = ProductUiHarness();
      await h.seed();
      await h.pump(tester);
      final first = tester.getTopLeft(find.text('Fixture Book 7')).dy;
      final second = tester.getTopLeft(find.text('Fixture Folder 7')).dy;
      final third = tester.getTopLeft(find.text('Fixture Book 8')).dy;
      expect(first, lessThan(second));
      expect(second, lessThan(third));
      expect(find.byIcon(Icons.menu_book_outlined), findsNWidgets(2));
      await tester.tap(find.text('Fixture Folder 7'));
      await tester.pumpAndSettle();
      expect(
        h.container
            .read(routerProvider)
            .routerDelegate
            .currentConfiguration
            .last
            .matchedLocation,
        const FolderRoute(id: 7).location,
      );
      expect(
        tester.getTopLeft(find.text('Fixture Book 10')).dy,
        lessThan(tester.getTopLeft(find.text('Fixture Book 9')).dy),
      );
      await tester.tap(find.text('Fixture Book 10'));
      await tester.pumpAndSettle();
      expect(
        h.container
            .read(routerProvider)
            .routerDelegate
            .currentConfiguration
            .last
            .matchedLocation,
        const BookRoute(id: 10).location,
      );
      expect(find.text('Fixture Author 10'), findsOneWidget);
      expect(find.text(l10n.libraryPreparationStart), findsOneWidget);
      expect(
        find.bySemanticsLabel(l10n.libraryCoverLabel('Fixture Book 10')),
        findsOneWidget,
      );
      h.container.read(routerProvider).pop();
      await tester.pumpAndSettle();
      expect(find.text('Fixture Folder 7'), findsOneWidget);
    },
  );

  testWidgets('refresh failure retains stale data; retry clears stale label', (
    tester,
  ) async {
    final h = ProductUiHarness();
    await h.seed();
    h.libraryResponse = (o) => throw DioException.connectionError(
      requestOptions: o,
      reason: 'synthetic offline',
    );
    await h.pump(tester);
    expect(find.text(l10n.libraryStale), findsOneWidget);
    expect(find.text(l10n.serverConnectionFailed), findsOneWidget);
    expect(find.text('Fixture Book 7'), findsOneWidget);
    h.libraryResponse = (_) => jsonBody(fixture('snapshot_empty.json'));
    await tester.tap(find.text(l10n.commonRetry));
    await tester.pumpAndSettle();
    expect(find.text(l10n.libraryStale), findsNothing);
    expect(find.text(l10n.libraryEmpty), findsOneWidget);
    expect(find.text('Fixture Book 7'), findsNothing);
    final count = h.activeAdapters.single.requests.length;
    await tester.tap(find.byTooltip(l10n.libraryRefresh));
    await tester.pumpAndSettle();
    expect(h.activeAdapters.single.requests, hasLength(count + 1));
  });

  testWidgets(
    'cached data is marked stale while refreshing and pull refresh works',
    (tester) async {
      final h = ProductUiHarness();
      await h.seed();
      final pending = Completer<ResponseBody>();
      h.libraryResponse = (_) => pending.future;
      await h.pump(tester, settle: false);
      expect(find.text(l10n.libraryStale), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      pending.complete(jsonBody(fixture('snapshot_typical.json')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.libraryStale), findsNothing);
      final count = h.activeAdapters.single.requests.length;
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(h.activeAdapters.single.requests.length, greaterThan(count));
    },
  );

  testWidgets('empty library and empty folder have distinct states', (
    tester,
  ) async {
    final h = ProductUiHarness();
    await h.seed();
    await h.pump(tester);
    await tester.tap(find.text('Fixture Folder 20'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.libraryFolderEmpty), findsOneWidget);
    h.container.read(routerProvider).pop();
    await tester.pumpAndSettle();
    h.libraryResponse = (_) => jsonBody(fixture('snapshot_empty.json'));
    await tester.tap(find.byTooltip(l10n.libraryRefresh));
    await tester.pumpAndSettle();
    expect(find.text(l10n.libraryEmpty), findsOneWidget);
  });

  testWidgets('load error without cached data offers retry', (tester) async {
    final h = ProductUiHarness();
    await h.seed();
    h.cache.values.clear();
    h.libraryResponse = (o) => throw DioException.connectionError(
      requestOptions: o,
      reason: 'synthetic',
    );
    await h.pump(tester);
    expect(find.text(l10n.serverConnectionFailed), findsOneWidget);
    expect(find.text(l10n.libraryEmpty), findsNothing);
    expect(find.text(l10n.libraryStale), findsNothing);
    h.libraryResponse = (_) => jsonBody(fixture('snapshot_typical.json'));
    await tester.tap(find.text(l10n.commonRetry));
    await tester.pumpAndSettle();
    expect(find.text('Fixture Book 7'), findsOneWidget);
  });

  testWidgets('unavailable IDs show recoverable missing states', (
    tester,
  ) async {
    final h = ProductUiHarness();
    await h.seed();
    await h.pump(tester);
    final context = tester.element(find.byType(BookCover).first);
    const FolderRoute(id: 999).go(context);
    await tester.pumpAndSettle();
    expect(find.text(l10n.libraryFolderMissing), findsOneWidget);
    const BookRoute(id: 999)
        .go(tester.element(find.byType(RefreshIndicator).last));
    await tester.pumpAndSettle();
    expect(find.text(l10n.libraryBookMissing), findsOneWidget);
  });

  testWidgets(
    'non-image cover response uses fallback without disrupting browsing',
    (tester) async {
      final h = ProductUiHarness();
      await h.seed();
      final body =
          jsonDecode(fixture('snapshot_typical.json')) as Map<String, dynamic>;
      body['snapshot']['books'][0]['coverThumbnail2xUrl'] =
          '/covers/synthetic.png';
      h.libraryResponse = (o) => o.uri.path.contains('/covers/')
          ? jsonBody('{}')
          : jsonBody(jsonEncode(body));
      await h.pump(tester);
      // CoverLoader crosses a native codec future: drain it outside fake time.
      await tester.runAsync(() async => Future<void>.value());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.menu_book_outlined), findsNWidgets(2));
      expect(
        h.activeAdapters.single.requests.any(
          (r) => r.uri.path.contains('/covers/'),
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
