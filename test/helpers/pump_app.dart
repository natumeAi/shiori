import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/l10n/l10n.dart';

extension PumpApp on WidgetTester {
  /// Pumps [widget] inside a `ProviderScope` (retry disabled), the app theme,
  /// and the `zh` localizations.
  Future<void> pumpApp(Widget widget, {List<Override> overrides = const []}) {
    return pumpWidget(
      ProviderScope(
        overrides: overrides,
        retry: (_, _) => null,
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: widget,
        ),
      ),
    );
  }
}
