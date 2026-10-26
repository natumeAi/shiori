import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/server_endpoint.dart';
import 'package:shiori/core/config/server_key.dart';

ServerKey key(String input) => ServerKey(ServerEndpoint.parse(input).endpoint!);

void main() {
  test('server key is the exact lowercase SHA-256 of the canonical root', () {
    final server = key('HTTP://H:80');
    expect(server.canonicalRoot, 'http://h/');
    // Independently calculated with Python hashlib, not the production helper.
    expect(
      server.value,
      'ad8295a7a69d6f00bcbec158f753e9310e81a0ffc377dbe0d6d40de0b76d7142',
    );
    expect(server.value, matches(RegExp(r'^[0-9a-f]{64}$')));
  });

  for (final pair in [
    ('http://h', 'http://h:80/'),
    ('https://h:443', 'https://h/'),
    ('https://H/Reader', 'https://h/Reader/'),
    ('https://h/a/../Reader/./', 'https://h/Reader/'),
  ]) {
    test('canonical aliases have equal keys: $pair', () {
      final left = key(pair.$1);
      final right = key(pair.$2);
      expect(left, right);
      expect(left.hashCode, right.hashCode);
      expect({left, right}, hasLength(1));
    });
  }

  test('scheme, nondefault port, prefix, path case and host isolate keys', () {
    final servers = [
      'http://h/',
      'https://h/',
      'http://h:8080/',
      'http://h/reader/',
      'http://h/Reader/',
      'http://other/',
      'http://h/a%2Fb/',
      'http://h/a/b/',
    ].map(key).toList();
    expect(servers.toSet(), hasLength(servers.length));
    expect(servers.map((e) => e.value).toSet(), hasLength(servers.length));
    expect(servers.first, isNot('http://h/'));
  });
}
