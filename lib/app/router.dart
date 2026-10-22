import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shiori/app/routes.dart';

part 'router.g.dart';

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final router = GoRouter(routes: $appRoutes);
  ref.onDispose(router.dispose);
  return router;
}
