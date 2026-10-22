import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:shiori/features/home/presentation/home_screen.dart';

part 'routes.g.dart';

@TypedGoRoute<HomeRoute>(path: '/')
class HomeRoute extends GoRouteData with $HomeRoute {
  const HomeRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const HomeScreen();
}
