import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiori/app/startup_screen.dart';
import 'package:shiori/features/library/presentation/library_screen.dart';
import 'package:shiori/features/servers/presentation/server_activation_controller.dart';
import 'package:shiori/features/servers/presentation/server_setup_screen.dart';

part 'routes.g.dart';

@TypedGoRoute<HomeRoute>(
  path: '/',
  routes: [
    TypedGoRoute<FolderRoute>(path: 'folders/:id'),
    TypedGoRoute<BookRoute>(path: 'books/:id'),
  ],
)
class HomeRoute extends GoRouteData with $HomeRoute {
  const HomeRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const _LibraryPage();
}

class FolderRoute extends GoRouteData with $FolderRoute {
  const FolderRoute({required this.id});
  final int id;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      _LibraryPage(folderId: id);
}

class BookRoute extends GoRouteData with $BookRoute {
  const BookRoute({required this.id});
  final int id;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      _LibraryPage(bookId: id);
}

@TypedGoRoute<ServerSetupRoute>(path: '/servers/setup')
class ServerSetupRoute extends GoRouteData with $ServerSetupRoute {
  const ServerSetupRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ServerSetupScreen();
}

@TypedGoRoute<StartupRoute>(path: '/startup')
class StartupRoute extends GoRouteData with $StartupRoute {
  const StartupRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const StartupScreen();
}

class _LibraryPage extends ConsumerWidget {
  const _LibraryPage({this.folderId, this.bookId});
  final int? folderId;
  final int? bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref
        .watch(serverActivationControllerProvider)
        .value
        ?.session;
    if (session == null) return const StartupScreen();
    return LibraryScreen(
      key: ValueKey((session, folderId, bookId)),
      session: session,
      folderId: folderId,
      bookId: bookId,
      onChangeServer: () => const ServerSetupRoute().push<void>(context),
      onFolder: (id) => FolderRoute(id: id).push<void>(context),
      onBook: (id) => BookRoute(id: id).push<void>(context),
    );
  }
}
