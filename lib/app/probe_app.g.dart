// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'probe_app.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [$probeHomeRoute];

RouteBase get $probeHomeRoute => GoRouteData.$route(
  path: '/',
  hasOverriddenOnExit: false,
  factory: $ProbeHomeRoute._fromState,
  routes: [
    GoRouteData.$route(
      path: 'synthetic',
      hasOverriddenOnExit: false,
      factory: $ProbeSyntheticRoute._fromState,
    ),
    GoRouteData.$route(
      path: 'reader',
      hasOverriddenOnExit: false,
      factory: $ProbeReaderRoute._fromState,
    ),
  ],
);

mixin $ProbeHomeRoute on GoRouteData {
  static ProbeHomeRoute _fromState(GoRouterState state) =>
      const ProbeHomeRoute();

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

mixin $ProbeSyntheticRoute on GoRouteData {
  static ProbeSyntheticRoute _fromState(GoRouterState state) =>
      const ProbeSyntheticRoute();

  @override
  String get location => GoRouteData.$location('/synthetic');

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

mixin $ProbeReaderRoute on GoRouteData {
  static ProbeReaderRoute _fromState(GoRouterState state) =>
      const ProbeReaderRoute();

  @override
  String get location => GoRouteData.$location('/reader');

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
