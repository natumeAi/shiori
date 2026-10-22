import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/router.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/l10n/l10n.dart';

class ShioriApp extends ConsumerWidget {
  const ShioriApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      routerConfig: ref.watch(routerProvider),
      onGenerateTitle: (context) => context.l10n.appTitle,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
