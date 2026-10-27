import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/server_endpoint.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/core/network/session_transport.dart';

import 'fake_server_adapter.dart';

void main() {
  SessionTransport transport(
    FakeServerAdapter adapter, [
    String root = 'https://private.example.test:9443/deployment/',
  ]) {
    final value = SessionTransport(
      ServerSession(
        endpoint: ServerEndpoint.parse(root).endpoint!,
        generation: 1,
      ),
      adapter: adapter,
    );
    addTearDown(value.dispose);
    return value;
  }

  final fixtures = jsonDecode(
    File('test/fixtures/server/url_resolution.json').readAsStringSync(),
  ) as Map<String, Object?>;
  for (final value in fixtures['accepted'] as List<Object?>) {
    final fixture = value as Map<String, Object?>;
    final requests = fixture['requests'] as Map<String, Object?>;
    for (final entry in requests.entries) {
      test('actual ${fixture['name']} ${entry.key}', () async {
        final adapter = FakeServerAdapter((options, _) {
          expect(options.uri.toString(), entry.value);
          expect(options.method, 'GET');
          expect(options.followRedirects, isFalse);
          expect(options.connectTimeout, const Duration(seconds: 10));
          expect(options.receiveTimeout, const Duration(seconds: 20));
          expect(options.responseType, ResponseType.stream);
          expect(options.data, isNull);
          expect(options.cancelToken, isNotNull);
          return jsonBody();
        });
        final client = transport(adapter, fixture['input'] as String);
        if (entry.key.startsWith('/covers/')) {
          await client.getBytes(entry.key, maxBytes: 100);
        } else {
          await client.getJson(entry.key.split('/'));
        }
        expect(adapter.requests, hasLength(1));
      });
    }
  }

  test('conditional headers and response validators are opaque', () async {
    const etag = 'W/"opaque+etag"';
    const modified = 'Thu, 01 Jan 2026 00:00:00 GMT';
    final adapter = FakeServerAdapter((options, _) {
      expect(options.headers['If-None-Match'], etag);
      expect(options.headers['If-Modified-Since'], modified);
      return jsonBody('{"snapshot":{}}', 200, {
        'etag': [etag],
        'last-modified': [modified],
      });
    });
    final response = await transport(adapter).getJson(
      ['api', 'library', 'snapshot'],
      ifNoneMatch: etag,
      ifModifiedSince: modified,
    );
    expect(response.statusCode, 200);
    expect(response.body, {'snapshot': {}});
    expect(response.headers['etag'], [etag]);
    expect(response.headers['last-modified'], [modified]);
    expect(() => response.headers.clear(), throwsUnsupportedError);
    expect(() => response.headers['etag']!.clear(), throwsUnsupportedError);
  });

  for (final route in [
    ['api', 'health'],
    ['api', 'library', 'snapshot'],
    ['api', 'books', '7'],
    ['api', 'books', '7', 'file'],
  ]) {
    test('raw JSON text survives UTF-8 chunks and numeric spelling: $route', () async {
      const raw =
          ' { "text": "雪📚", "escaped": "\\u96ea", "whole": 1.00, "tiny": 1.0e-7 }\r\n';
      final bytes = utf8.encode(raw);
      final split =
          bytes.indexOf(0xe9) + 1; // Inside the first UTF-8 character.
      final adapter = FakeServerAdapter(
        (_, _) => ResponseBody(
          Stream.fromIterable([
            Uint8List.sublistView(bytes, 0, split),
            Uint8List.sublistView(bytes, split),
          ]),
          200,
          headers: {
            'content-type': ['application/json'],
          },
        ),
      );
      final response = await transport(adapter).getJson(route);
      expect(response.rawJsonText, raw);
      expect(utf8.encode(response.rawJsonText!), bytes);
      expect(response.body, {
        'text': '雪📚',
        'escaped': '雪',
        'whole': 1.0,
        'tiny': 1e-7,
      });
      expect(jsonEncode(response.body), isNot(raw));
      expect(jsonEncode(response.body).contains('1.00'), isFalse);
      expect(jsonEncode(response.body).contains('1.0e-7'), isFalse);
      expect(adapter.requests, hasLength(1));
    });
  }

  test('304 and byte responses leave raw JSON text absent', () async {
    for (final route in [
      ['api', 'library', 'snapshot'],
      ['api', 'books', '7', 'file'],
    ]) {
      final response = await transport(
        FakeServerAdapter((_, _) => jsonBody('', 304)),
      ).getJson(route, allowedTerminalStatuses: {200, 304});
      expect(response.rawJsonText, isNull);
    }
    final response = await transport(
      FakeServerAdapter((_, _) => ResponseBody.fromBytes([1, 2, 3], 200)),
    ).getBytes('/covers/a.webp', maxBytes: 3);
    expect(response.body, [1, 2, 3]);
    expect(response.rawJsonText, isNull);
  });

  test(
    'health fixture JSON is decoded and returned without DTO assumptions',
    () async {
      final body = File('test/fixtures/server/health_ok.json')
          .readAsStringSync();
      final client = transport(
        FakeServerAdapter((options, _) {
          expect(options.headers.containsKey('If-None-Match'), isFalse);
          expect(options.headers.containsKey('If-Modified-Since'), isFalse);
          return jsonBody(body);
        }),
      );
      expect((await client.getJson(['api', 'health'])).body, jsonDecode(body));
    },
  );

  test('cover 304 is rejected; unknown top-level code is retained', () async {
    final client = transport(FakeServerAdapter((_, _) => jsonBody('', 304)));
    await expectLater(
      client.getBytes('/covers/a', maxBytes: 3),
      throwsA(
        isA<ServerException>().having((e) => e.statusCode, 'status', 304),
      ),
    );
    final errorClient = transport(
      FakeServerAdapter(
        (_, _) => jsonBody(
          '{"error":"private message","code":"FUTURE_TOP_LEVEL"}',
          500,
        ),
      ),
    );
    await expectLater(
      errorClient.getJson(['api', 'health']),
      throwsA(
        isA<ServerException>().having(
          (e) => e.code,
          'code',
          'FUTURE_TOP_LEVEL',
        ),
      ),
    );
  });

  for (final route in [
    ['api', 'health'],
    ['api', 'library', 'snapshot'],
    ['api', 'books', '7'],
    ['api', 'books', '7', 'file'],
  ]) {
    test('304 rejected by default for ${route.join('/')}', () async {
      final client = transport(FakeServerAdapter((_, _) => jsonBody('', 304)));
      await expectLater(
        client.getJson(route),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'status', 304),
        ),
      );
    });
  }

  for (final route in [
    ['api', 'library', 'snapshot'],
    ['api', 'books', '7', 'file'],
  ]) {
    test(
      'explicit 304 bypasses JSON decoding for ${route.join('/')}',
      () async {
        final client = transport(
          FakeServerAdapter(
            (_, _) => ResponseBody.fromBytes(
              [],
              304,
              headers: {
                'etag': ['"v1"'],
              },
            ),
          ),
        );
        final result = await client.getJson(
          route,
          allowedTerminalStatuses: {200, 304},
        );
        expect(result.statusCode, 304);
        expect(result.body, isNull);
        expect(result.headers['etag'], ['"v1"']);
      },
    );
  }

  final manifest = jsonDecode(
    File('test/fixtures/server/manifest.json').readAsStringSync(),
  ) as Map<String, Object?>;
  for (final item in manifest['responses'] as List<Object?>) {
    final descriptor = item as Map<String, Object?>;
    final status = descriptor['status'] as int;
    if (status == 200 || status == 304) continue;
    test(
      'HTTP fixture ${descriptor['name']} retains status classification',
      () async {
        final file = descriptor['bodyFile'] as String?;
        final body = file == null
            ? ''
            : File('test/fixtures/server/$file').readAsStringSync();
        final client = transport(
          FakeServerAdapter((_, _) => jsonBody(body, status)),
        );
        await expectLater(
          client.getJson(['api', 'health']),
          throwsA(
            isA<ServerException>().having(
              (e) => e.statusCode,
              'status',
              status,
            ),
          ),
        );
      },
    );
  }

  for (final status in [401, 403]) {
    test('$status takes priority over an HTML body', () async {
      final client = transport(
        FakeServerAdapter(
          (_, _) =>
              ResponseBody.fromString('<html>private login</html>', status),
        ),
      );
      await expectLater(
        client.getJson(['api', 'health']),
        throwsA(isA<UnauthorizedException>()),
      );
    });
  }

  for (final status in [200, 400, 500]) {
    test('unknown JSON error code preserved at HTTP $status', () async {
      final client = transport(
        FakeServerAdapter(
          (_, _) => jsonBody(
            '{"error":{"code":"FUTURE_CODE","message":"private text"}}',
            status,
          ),
        ),
      );
      await expectLater(
        client.getJson(['api', 'health']),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'status', status)
              .having((e) => e.code, 'code', 'FUTURE_CODE')
              .having((e) => e.cause, 'cause', isNull),
        ),
      );
    });
  }

  for (final file in ['error_400.json', 'error_500.json']) {
    test('$file is an error envelope even on HTTP 200', () async {
      final body = File('test/fixtures/server/$file').readAsStringSync();
      final client = transport(FakeServerAdapter((_, _) => jsonBody(body)));
      await expectLater(
        client.getJson(['api', 'health']),
        throwsA(isA<ServerException>()),
      );
    });
  }

  for (final mediaType in [
    'text/html',
    'text/plain',
    'application/json',
    null,
  ]) {
    test(
      'HTML login with content type $mediaType is a content-free parse failure',
      () async {
        final body = File('test/fixtures/server/proxy_login.html')
            .readAsStringSync();
        final client = transport(
          FakeServerAdapter(
            (_, _) => ResponseBody.fromString(
              body,
              200,
              headers: {
                if (mediaType != null) 'content-type': [mediaType],
              },
            ),
          ),
        );
        await expectLater(
          client.getJson(['api', 'health']),
          throwsA(
            isA<ParseException>().having((e) => e.cause, 'cause', isNull),
          ),
        );
      },
    );
  }

  test('invalid JSON and UTF-8 do not become network retries', () async {
    for (final bytes in [
      [0xff],
      utf8.encode('{broken'),
    ]) {
      final client = transport(
        FakeServerAdapter((_, _) => ResponseBody.fromBytes(bytes, 200)),
      );
      await expectLater(
        client.getJson(['api', 'health']),
        throwsA(isA<ParseException>()),
      );
    }
  });

  test(
    'JSON structured suffix accepted; non-JSON content type rejected',
    () async {
      for (final mediaType in ['application/problem+json', 'text/plain']) {
        final client = transport(
          FakeServerAdapter(
            (_, _) => jsonBody('{"ok":true}', 200, {
              'content-type': [mediaType],
            }),
          ),
        );
        if (mediaType == 'text/plain') {
          await expectLater(
            client.getJson(['api', 'health']),
            throwsA(isA<ParseException>()),
          );
        } else {
          expect((await client.getJson(['api', 'health'])).body, {'ok': true});
        }
      }
    },
  );

  for (final types in <List<String>>[
    [],
    ['application/json', 'text/html'],
  ]) {
    test(
      'invalid Content-Type cardinality ${types.length} is a parse failure',
      () async {
        final client = transport(
          FakeServerAdapter(
            (_, _) => jsonBody('{"ok":true}', 200, {'content-type': types}),
          ),
        );
        await expectLater(
          client.getJson(['api', 'health']),
          throwsA(isA<ParseException>()),
        );
      },
    );
  }

  for (final declared in [null, '1', '999999']) {
    test(
      'cover limit enforced on chunks regardless of declared $declared',
      () async {
        var closed = false;
        final client = transport(
          FakeServerAdapter(
            (_, _) => ResponseBody(
              Stream.fromIterable([Uint8List(3), Uint8List(3), Uint8List(3)]),
              200,
              headers: {
                if (declared != null) 'content-length': [declared],
              },
              onClose: () => closed = true,
            ),
          ),
        );
        await expectLater(
          client.getBytes('/covers/a.webp', maxBytes: 5),
          throwsA(isA<ParseException>()),
        );
        // Dio closes the underlying response in the cancel-token microtask.
        await Future<void>.delayed(Duration.zero);
        expect(closed, isTrue);
      },
    );
  }

  test(
    'exact cover byte limit succeeds; invalid resource never reaches adapter',
    () async {
      final adapter = FakeServerAdapter(
        (_, _) => ResponseBody.fromBytes([1, 2, 3], 200),
      );
      final client = transport(adapter);
      expect((await client.getBytes('/covers/a.webp', maxBytes: 3)).body, [
        1,
        2,
        3,
      ]);
      await expectLater(
        client.getBytes('/covers/a.webp', maxBytes: 0),
        throwsArgumentError,
      );
      await expectLater(
        client.getBytes('https://foreign.test/a', maxBytes: 3),
        throwsA(isA<ParseException>()),
      );
      expect(adapter.requests, hasLength(1));
    },
  );

  test(
    'health/detail cannot opt into 304; unsupported routes make no request',
    () async {
      final adapter = FakeServerAdapter((_, _) => jsonBody());
      final client = transport(adapter);
      for (final route in [
        ['api', 'health'],
        ['api', 'books', '7'],
      ]) {
        await expectLater(
          client.getJson(route, allowedTerminalStatuses: {200, 304}),
          throwsArgumentError,
        );
      }
      for (final route in [
        ['api', 'books'],
        ['api', 'books', '../secret'],
        ['api', 'books', '9007199254740992'],
        ['api', 'goals'],
      ]) {
        await expectLater(client.getJson(route), throwsArgumentError);
      }
      await expectLater(
        client.getJson(['api', 'health'], allowedTerminalStatuses: {206}),
        throwsArgumentError,
      );
      expect(adapter.requests, isEmpty);
    },
  );
}
