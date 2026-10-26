import 'package:shiori/core/config/server_endpoint.dart';
import 'package:shiori/core/config/server_key.dart';

/// One activation of a deployment. Reactivation must use a fresh generation.
final class ServerSession {
  ServerSession({required this.endpoint, required this.generation})
    : serverKey = ServerKey(endpoint) {
    if (generation < 1) throw ArgumentError('Invalid activation generation');
  }

  final ServerEndpoint endpoint;
  final ServerKey serverKey;
  final int generation;

  @override
  bool operator ==(Object other) =>
      other is ServerSession &&
      serverKey == other.serverKey &&
      generation == other.generation;

  @override
  int get hashCode => Object.hash(serverKey, generation);
}
