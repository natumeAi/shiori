import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/server_endpoint.dart';
import 'package:shiori/core/config/server_key.dart';
import 'package:shiori/core/config/server_session.dart';

void main() {
  ServerSession session(String root, int generation) => ServerSession(
    endpoint: ServerEndpoint.parse(root).endpoint!,
    generation: generation,
  );

  test('activation equality includes canonical server and generation', () {
    final first = session('https://example.test/reader', 1);
    final alias = session('HTTPS://EXAMPLE.TEST:443/reader/', 1);
    expect(first, alias);
    expect(first.hashCode, alias.hashCode);
    expect(first.serverKey, ServerKey(first.endpoint));
    expect(first, isNot(session('https://example.test/reader', 2)));
    expect(first, isNot(session('https://other.test/reader', 1)));
    expect(first, isNot(session('https://example.test/other', 1)));
    expect(first.toString(), isNot(contains('example.test')));
  });

  test('activation generations must be positive', () {
    for (final generation in [-1, 0]) {
      expect(
        () => session('https://example.test', generation),
        throwsArgumentError,
      );
    }
  });
}
