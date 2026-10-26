import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/server_endpoint.dart';

void main() {
  final fixtures = jsonDecode(
    File('test/fixtures/server/url_resolution.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final accepted = fixtures['accepted'] as List<Object?>;
  for (final value in accepted) {
    final fixture = value as Map<String, Object?>;
    final input = fixture['input'] as String;
    final canonical = fixture['canonicalRoot'] as String;
    final name = fixture['name'] as String;
    test('fixture $name canonical round trip and idempotence', () {
      final result = ServerEndpoint.parse(input);
      expect(result.issue, isNull);
      final endpoint = result.endpoint!;
      expect(endpoint.canonicalRoot, canonical);
      expect(endpoint.normalizedText, canonical);
      final roundTrip = ServerEndpoint.parse(endpoint.canonicalRoot).endpoint!;
      expect(roundTrip, endpoint);
      expect(roundTrip.hashCode, endpoint.hashCode);
      expect(ServerEndpoint.parse(roundTrip.normalizedText).endpoint, endpoint);
    });
    final requests = fixture['requests'] as Map<String, Object?>;
    for (final request in requests.entries) {
      test('fixture $name resolves ${request.key}', () {
        final endpoint = ServerEndpoint.parse(input).endpoint!;
        final actual = request.key.startsWith('/covers/')
            ? endpoint.cover(request.key)
            : endpoint.api(request.key.split('/'));
        expect(actual.toString(), request.value);
      });
    }
  }

  final issues = <String, ServerEndpointIssue>{
    'userinfo': .userInfo,
    'empty_userinfo': .userInfo,
    'query': .query,
    'empty_query': .query,
    'fragment': .fragment,
    'empty_fragment': .fragment,
    'non_http_scheme': .scheme,
    'missing_scheme': .scheme,
    'missing_host': .host,
    'malformed_host': .host,
    'malformed_ipv6': .host,
    'invalid_port_large': .port,
    'invalid_port_zero': .port,
    'invalid_port_text': .port,
    'backslash': .backslash,
    'invalid_percent_escape': .percentEscape,
    'truncated_percent_escape': .percentEscape,
  };
  for (final value in fixtures['rejected'] as List<Object?>) {
    final fixture = value as Map<String, Object?>;
    test('fixture rejects ${fixture['reason']} without traffic', () {
      var clientCreations = 0;
      HttpOverrides.runZoned(
        () {
          final result = ServerEndpoint.parse(fixture['input'] as String);
          expect(result.endpoint, isNull);
          expect(result.issue, issues[fixture['reason']]);
        },
        createHttpClient: (_) {
          clientCreations++;
          throw StateError('Network forbidden');
        },
      );
      expect(clientCreations, fixture['expectedRequests']);
    });
  }

  final roots = <String, String>{
    'HTTP://[2001:DB8::7]/Reader': 'http://[2001:db8::7]/Reader/',
    'https://[2001:db8::7]:443': 'https://[2001:db8::7]/',
    'https://[::1]:8443/a': 'https://[::1]:8443/a/',
    'http://h:00080/a///': 'http://h/a/',
    'http://h/../../a/./b/..': 'http://h/a/',
    'http://h/A%2fb/%23%3f%25': 'http://h/A%2Fb/%23%3F%25/',
    'http://h/a//b': 'http://h/a//b/',
  };
  for (final entry in roots.entries) {
    test('additional normalization ${entry.key}', () {
      final endpoint = ServerEndpoint.parse(entry.key).endpoint!;
      expect(endpoint.canonicalRoot, entry.value);
      expect(ServerEndpoint.parse(entry.value).endpoint, endpoint);
      expect(
        endpoint.api(['api', 'health']).toString(),
        '${entry.value}api/health',
      );
    });
  }

  for (final input in [
    'http://[fe80::7%25en0]/',
    'http://[fe80::7%25eth0]:8080/reader',
  ]) {
    test('zone identifiers have a dedicated content-free reason: $input', () {
      final result = ServerEndpoint.parse(input);
      expect(result.endpoint, isNull);
      expect(result.issue, ServerEndpointIssue.ipv6ZoneIdentifier);
    });
  }

  for (final input in [
    '',
    '//example.test/',
    'https:example.test/',
    'https://:80/',
    'https://h:/',
    'https://h:-1/',
    'https://h:+80/',
    'https://h:80:90/',
    'https://[::1]suffix/',
    'https://[not-ipv6]/',
    'https://h:999999999999999999999999999/',
    'https://h%20x/',
  ]) {
    test('additional malformed root returns a typed result: $input', () {
      final result = ServerEndpoint.parse(input);
      expect(result.endpoint, isNull);
      expect(result.issue, isA<ServerEndpointIssue>());
    });
  }
}
