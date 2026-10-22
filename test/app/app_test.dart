import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/app.dart';
import 'package:shiori/features/home/presentation/home_screen.dart';
import 'package:shiori/l10n/l10n.dart';

void main() {
  testWidgets('starts on the home screen', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('zh'));

    await tester.pumpWidget(
      ProviderScope(retry: (_, _) => null, child: const ShioriApp()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text(l10n.homeTitle), findsOneWidget);
  });
}
