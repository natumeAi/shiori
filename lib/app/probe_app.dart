import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shiori/app/theme.dart';
import 'package:shiori/features/diagnostics/presentation/diagnostics_screen.dart';
import 'package:shiori/features/diagnostics/presentation/reader_probe/reader_probe_screen.dart';
import 'package:shiori/l10n/l10n.dart';

part 'probe_app.g.dart';

class ProbeApp extends StatefulWidget {
  const ProbeApp({super.key});
  @override
  State<ProbeApp> createState() => _ProbeAppState();
}

class _ProbeAppState extends State<ProbeApp> {
  late final _router = GoRouter(routes: $appRoutes);
  @override
  Widget build(BuildContext context) => MaterialApp.router(
    onGenerateTitle: (context) => context.l10n.diagnosticsTitle,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: _router,
  );
  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }
}

@TypedGoRoute<ProbeHomeRoute>(
  path: '/',
  routes: [
    TypedGoRoute<ProbeSyntheticRoute>(path: 'synthetic'),
    TypedGoRoute<ProbeReaderRoute>(path: 'reader'),
  ],
)
class ProbeHomeRoute extends GoRouteData with $ProbeHomeRoute {
  const ProbeHomeRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) => const _ProbeHome();
}

class ProbeSyntheticRoute extends GoRouteData with $ProbeSyntheticRoute {
  const ProbeSyntheticRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const DiagnosticsScreen();
}

class ProbeReaderRoute extends GoRouteData with $ProbeReaderRoute {
  const ProbeReaderRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ReaderProbeScreen();
}

class _ProbeHome extends StatelessWidget {
  const _ProbeHome();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.diagnosticsTitle)),
    body: ListView(
      children: [
        ListTile(
          title: Text(context.l10n.probeSynthetic),
          onTap: () => const ProbeSyntheticRoute().push<void>(context),
        ),
        ListTile(
          title: Text(context.l10n.readerProbeTitle),
          onTap: () => const ProbeReaderRoute().push<void>(context),
        ),
      ],
    ),
  );
}
