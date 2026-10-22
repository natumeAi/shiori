import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/home/presentation/home_screen.dart';
import 'package:shiori/l10n/l10n.dart';

import '../../../helpers/pump_app.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('zh'));

  testWidgets('shows the localized title and welcome text', (tester) async {
    await tester.pumpApp(const HomeScreen());

    expect(find.text(l10n.homeTitle), findsOneWidget);
    expect(find.text(l10n.homeWelcome), findsOneWidget);
  });
}
