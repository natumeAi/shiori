import 'package:shiori/core/config/server_endpoint.dart';
import 'package:shiori/core/errors/app_exception.dart';

/// Per-request redirect history. A redirect never changes the session identity.
final class RedirectPolicy {
  RedirectPolicy(ServerEndpoint endpoint, Uri initial)
    : _root = Uri.parse(endpoint.canonicalRoot),
      _visited = {initial.toString()};

  final Uri _root;
  final Set<String> _visited;
  int _followed = 0;

  static bool isRedirect(int? status) =>
      const {301, 302, 303, 307, 308}.contains(status);

  Uri next(Uri current, String? location) {
    if (_followed >= 5) throw const RedirectException(.limit);
    if (location == null ||
        location.isEmpty ||
        RegExp(r'[\s\x00-\x1f\x7f\\]').hasMatch(location) ||
        RegExp(r'%(?![0-9a-fA-F]{2})').hasMatch(location)) {
      throw const RedirectException(.invalidTarget);
    }
    // Uri normalizes an empty userinfo delimiter away; reject it beforehand.
    final authority = RegExp(r'^(?:[a-zA-Z][a-zA-Z0-9+.-]*:)?//([^/?#]*)')
        .firstMatch(location)
        ?.group(1);
    if (authority != null && authority.contains('@')) {
      throw const RedirectException(.outsideDeployment);
    }
    late Uri target;
    try {
      target = current.resolve(location).normalizePath().removeFragment();
      for (final segment in target.path.split('/')) {
        final decoded = Uri.decodeComponent(segment);
        if (decoded.contains(r'\') ||
            decoded.split('/').any((part) => part == '..' || part == '.')) {
          throw const RedirectException(.invalidTarget);
        }
      }
    } on FormatException {
      throw const RedirectException(.invalidTarget);
    }
    if (target.scheme != _root.scheme ||
        target.host != _root.host ||
        target.port != _root.port ||
        target.authority.contains('@') ||
        !target.path.startsWith(_root.path)) {
      throw const RedirectException(.outsideDeployment);
    }
    if (!_visited.add(target.toString())) throw const RedirectException(.loop);
    _followed++;
    return target;
  }
}
