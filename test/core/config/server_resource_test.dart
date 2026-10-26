import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/server_endpoint.dart';

void main() {
  final endpoint = ServerEndpoint.parse(
    'https://example.test/Reader%20Library/a%2Fb',
  ).endpoint!;

  test('API segments encode delimiters, Unicode and literal percent once', () {
    final url = endpoint.api(['api', 'a/b', '?#', '%2F', '书 名']);
    expect(
      url.toString(),
      'https://example.test/Reader%20Library/a%2Fb/'
      'api/a%2Fb/%3F%23/%252F/%E4%B9%A6%20%E5%90%8D',
    );
  });

  test('API data cannot replace the origin', () {
    expect(
      endpoint.api(['https://other.test', '//other.test']).toString(),
      'https://example.test/Reader%20Library/a%2Fb/'
      'https%3A%2F%2Fother.test/%2F%2Fother.test',
    );
  });

  for (final segments in <List<String>>[
    [],
    [''],
    ['api', '.'],
    ['api', '..', 'health'],
    ['api', '', 'health'],
  ]) {
    test('API rejects empty or dot segments: $segments', () {
      expect(() => endpoint.api(segments), throwsArgumentError);
    });
  }

  test('cover preserves encoded delimiters and opaque query ordering', () {
    const resource =
        '/covers/A%2FB%23C%3FD%25.webp'
        '?v=x%2By&v=z%26w&empty=&bare';
    expect(
      endpoint.cover(resource).toString(),
      'https://example.test/Reader%20Library/a%2Fb'
      '$resource',
    );
  });

  test('cover keeps empty query and encoded traversal text in query', () {
    expect(endpoint.cover('/covers/a?').toString(), endsWith('/covers/a?'));
    expect(
      endpoint.cover('/covers/a?next=..%2Felsewhere').query,
      'next=..%2Felsewhere',
    );
  });

  test('cover normalizes literal dot inside the covers directory', () {
    expect(
      endpoint.cover('/covers/./a.webp').toString(),
      'https://example.test/Reader%20Library/a%2Fb/covers/a.webp',
    );
  });

  for (final resource in [
    'https://other.test/covers/a',
    'https://example.test/Reader%20Library/a%2Fb/covers/a',
    '//other.test/covers/a',
    '/api/health',
    'covers/a',
    '/covers/../api/health',
    '/covers/a/../../../elsewhere',
    '/covers/%2e%2e/api/health',
    '/covers/.%2E/api/health',
    '/covers/%2e%2e%2Fapi/health',
    '/covers/a%2F..%2F..%2Fapi/health',
    '/covers/%5C..%5Capi/health',
    '/covers/../../Reader%20Library/a%2Fb/covers/a',
    r'/covers/a\b',
    '/covers/a#fragment',
    '/covers/a#',
    '/covers/a%2G',
    '/covers/a%',
    '/covers/a?v=%2',
    '/covers/a b',
    '/covers/a\n',
    '/covers/%FF',
  ]) {
    test('cover rejects unsafe resource: $resource', () {
      expect(
        () => endpoint.cover(resource),
        throwsA(
          isA<FormatException>()
              .having((e) => e.source, 'source', isNull)
              .having((e) => e.offset, 'offset', isNull)
              .having(
                (e) => e.message,
                'message',
                'Invalid server cover resource',
              ),
        ),
      );
    });
  }
}
