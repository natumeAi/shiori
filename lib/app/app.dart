import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/router.dart';
import 'package:shiori/app/routes.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/servers/presentation/server_activation_controller.dart';
import 'package:shiori/l10n/l10n.dart';

class ShioriApp extends ConsumerWidget {
  const ShioriApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    ref.listen(serverActivationControllerProvider, (previous, next) {
      final session = next.value?.session;
      if (session != null && session != previous?.value?.session) {
        router.go(const HomeRoute().location);
      }
    });
    return MaterialApp.router(
      routerConfig: router,
      onGenerateTitle: (context) => context.l10n.appTitle,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
