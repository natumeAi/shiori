import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'product_ui_test_support.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      '200 percent text on narrow screen with ${brightness.name} theme',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final h = ProductUiHarness();
        await h.seed();
        await h.pump(tester, scale: 2, brightness: brightness);
        expect(
          Theme.of(tester.element(find.byType(CustomScrollView))).brightness,
          brightness,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Fixture Book 7'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text(l10n.libraryPreparationPlaceholder),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip(l10n.serverChangeTitle));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField), 'invalid');
        await tester.ensureVisible(find.text(l10n.serverConnect));
        await tester.tap(find.text(l10n.serverConnect));
        await tester.pumpAndSettle();
        expect(find.text(l10n.serverUrlScheme), findsOneWidget);
        await tester.ensureVisible(find.text(l10n.serverLocalNetworkHelp));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
