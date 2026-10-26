import 'package:shiori/core/config/server_endpoint.dart';
import 'package:shiori/core/config/server_session.dart';

/// One provider-container lifetime owns this clock and publication boundary.
final class SessionPublicationGuard {
  int _generation = 0;
  ServerSession? _current;
  final Set<void Function()> _pending = {};

  ServerSession? get current => _current;

  /// Temporary candidates also get distinct identities, but are never current.
  ServerSession createSession(ServerEndpoint endpoint) =>
      ServerSession(endpoint: endpoint, generation: ++_generation);

  bool isCurrent(ServerSession session) => _current == session;

  /// Call immediately before a synchronous state/cache/file/worker publication.
  /// Do not await between this check and the write.
  bool publish(ServerSession session, void Function() publication) {
    if (!isCurrent(session)) return false;
    publication();
    return true;
  }

  /// Retirement callbacks must be synchronous, idempotent and nonthrowing.
  /// Returns an unregister function for work that finished normally.
  void Function() onRetire(ServerSession session, void Function() cancel) {
    if (!isCurrent(session)) {
      cancel();
      return () {};
    }
    void registered() => cancel();
    _pending.add(registered);
    return () => _pending.remove(registered);
  }

  void retire() {
    _current = null;
    final pending = _pending.toList();
    _pending.clear();
    for (final cancel in pending) {
      cancel();
    }
  }

  /// The activation owner must retire old transport/work before selecting.
  void select(ServerSession session) {
    assert(_current == null);
    _current = session;
  }
}
