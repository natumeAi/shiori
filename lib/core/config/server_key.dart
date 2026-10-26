import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shiori/core/config/server_endpoint.dart';

/// Private namespace identity, not authentication or a remote server ID.
final class ServerKey {
  ServerKey(ServerEndpoint endpoint)
    : canonicalRoot = endpoint.canonicalRoot,
      value = sha256.convert(utf8.encode(endpoint.canonicalRoot)).toString();

  final String value;

  /// Retain alongside the digest and compare when opening a namespace.
  final String canonicalRoot;

  @override
  bool operator ==(Object other) =>
      other is ServerKey &&
      value == other.value &&
      canonicalRoot == other.canonicalRoot;

  @override
  int get hashCode => Object.hash(value, canonicalRoot);
}
