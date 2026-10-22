import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/core/widgets/error_view.dart';
import 'package:shiori/l10n/l10n.dart';

import '../../helpers/pump_app.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('zh'));

  testWidgets('shows the mapped message and a working retry button', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpApp(
      ErrorView(error: const NetworkException(), onRetry: () => retries++),
    );

    expect(find.text(l10n.errorNetwork), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, l10n.commonRetry));
    expect(retries, 1);
  });

  testWidgets('hides the retry button without onRetry', (tester) async {
    await tester.pumpApp(const ErrorView(error: ParseException()));

    expect(find.text(l10n.errorServer), findsOneWidget);
    expect(find.text(l10n.commonRetry), findsNothing);
  });
}
