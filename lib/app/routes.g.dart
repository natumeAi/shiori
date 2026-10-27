// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [
  $homeRoute,
  $serverSetupRoute,
  $startupRoute,
];

RouteBase get $homeRoute => GoRouteData.$route(
  path: '/',
  hasOverriddenOnExit: false,
  factory: $HomeRoute._fromState,
  routes: [
    GoRouteData.$route(
      path: 'folders/:id',
      hasOverriddenOnExit: false,
      factory: $FolderRoute._fromState,
    ),
    GoRouteData.$route(
      path: 'books/:id',
      hasOverriddenOnExit: false,
      factory: $BookRoute._fromState,
    ),
  ],
);

mixin $HomeRoute on GoRouteData {
  static HomeRoute _fromState(GoRouterState state) => const HomeRoute();

  @override
  String get location => GoRouteData.$location('/');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $FolderRoute on GoRouteData {
  static FolderRoute _fromState(GoRouterState state) =>
      FolderRoute(id: int.parse(state.pathParameters['id']!));

  FolderRoute get _self => this as FolderRoute;

  @override
  String get location => GoRouteData.$location(
    '/folders/${Uri.encodeComponent(_self.id.toString())}',
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $BookRoute on GoRouteData {
  static BookRoute _fromState(GoRouterState state) =>
      BookRoute(id: int.parse(state.pathParameters['id']!));

  BookRoute get _self => this as BookRoute;

  @override
  String get location => GoRouteData.$location(
    '/books/${Uri.encodeComponent(_self.id.toString())}',
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $serverSetupRoute => GoRouteData.$route(
  path: '/servers/setup',
  hasOverriddenOnExit: false,
  factory: $ServerSetupRoute._fromState,
);

mixin $ServerSetupRoute on GoRouteData {
  static ServerSetupRoute _fromState(GoRouterState state) =>
      const ServerSetupRoute();

  @override
  String get location => GoRouteData.$location('/servers/setup');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $startupRoute => GoRouteData.$route(
  path: '/startup',
  hasOverriddenOnExit: false,
  factory: $StartupRoute._fromState,
);

mixin $StartupRoute on GoRouteData {
  static StartupRoute _fromState(GoRouterState state) => const StartupRoute();

  @override
  String get location => GoRouteData.$location('/startup');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}
