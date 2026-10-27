import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shiori/app/routes.dart';
import 'package:shiori/features/servers/presentation/server_activation_controller.dart';

part 'router.g.dart';

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(serverActivationControllerProvider, (previous, next) {
    refresh.value++;
  });
  final router = GoRouter(
    routes: $appRoutes,
    refreshListenable: refresh,
    redirect: (context, state) {
      final activation = ref.read(serverActivationControllerProvider);
      if (activation.isLoading || activation.hasError) {
        return state.matchedLocation == const StartupRoute().location
            ? null
            : const StartupRoute().location;
      }
      if (activation.requireValue.session == null) {
        return state.matchedLocation == const ServerSetupRoute().location
            ? null
            : const ServerSetupRoute().location;
      }
      if (state.matchedLocation == const StartupRoute().location) {
        return const HomeRoute().location;
      }
      return null;
    },
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
}
