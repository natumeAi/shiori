import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:logging/logging.dart';
import 'package:shiori/core/config/server_endpoint.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/core/network/guard_dio.dart';
import 'package:shiori/core/network/redacted_request_log.dart';
import 'package:shiori/core/network/request_cancelled.dart';
import 'package:shiori/core/network/server_route.dart';
import 'package:shiori/core/network/session_transport.dart';

import 'fake_server_adapter.dart';

void main() {
  late List<LogRecord> records;
  setUp(() {
    records = [];
    final previous = Logger.root.level;
    Logger.root.level = Level.ALL;
    final subscription = Logger.root.onRecord.listen(records.add);
    addTearDown(() async {
      await subscription.cancel();
      Logger.root.level = previous;
    });
  });

  void assertRedacted() {
    expect(records, isNotEmpty);
    for (final record in records) {
      expect(
        record.message,
        matches(
          RegExp(
            r'^GET (api/health|api/library/snapshot|api/books/\{id\}(/file)?|'
            r'covers/\{resource\}|\{route\}) status=(\d{3}|-) elapsedMs=\d+$',
          ),
        ),
      );
      expect(record.error, isNull);
      expect(record.stackTrace, isNull);
      final rendered = '${record.message} ${record.error} ${record.stackTrace}';
      for (final secret in [
        'private.example.test',
        '9443',
        'deployment',
        'secretQuery',
        'privateFixture',
        'privateHeader',
        'privateBook',
        'http:',
        'https:',
        'Internal Server Error',
        '<html',
        'Login',
      ]) {
        expect(rendered, isNot(contains(secret)));
      }
    }
  }

  SessionTransport transport(FakeServerAdapter adapter) {
    final value = SessionTransport(
      ServerSession(
        endpoint: ServerEndpoint.parse(
          'https://private.example.test:9443/deployment/',
        ).endpoint!,
        generation: 1,
      ),
      adapter: adapter,
    );
    addTearDown(value.dispose);
    return value;
  }

  test(
    'all route templates, redirect hops and fixtures are redacted',
    () async {
      var healthHop = false;
      final adapter = FakeServerAdapter((options, _) {
        if (options.uri.path.endsWith('/health') && !healthHop) {
          healthHop = true;
          return ResponseBody.fromString(
            'privateFixture',
            302,
            headers: {
              'location': ['/deployment/api/health?secretQuery=privateFixture'],
            },
          );
        }
        return jsonBody('{"privateBook":"privateFixture"}', 200, {
          'x-private': ['privateHeader'],
        });
      });
      final client = transport(adapter);
      for (final route in [
        ['api', 'health'],
        ['api', 'library', 'snapshot'],
        ['api', 'books', '7'],
        ['api', 'books', '7', 'file'],
      ]) {
        await client.getJson(route, ifNoneMatch: 'privateHeader');
      }
      await client.getBytes(
        '/covers/privateBook.webp?secretQuery=privateFixture',
        maxBytes: 100,
      );
      expect(records, hasLength(6));
      assertRedacted();
    },
  );

  test(
    'guard failures never attach raw Dio/JSON exceptions or stacks',
    () async {
      final options = RequestOptions(
        path: 'https://private.example.test:9443/deployment/privateBook?secretQuery=privateFixture',
        headers: {'Authorization': 'privateHeader'},
        data: 'privateFixture',
      );
      for (final type in DioExceptionType.values) {
        final error = DioException(
          requestOptions: options,
          type: type,
          message: 'privateFixture',
          response: Response<String>(
            requestOptions: options,
            statusCode: 500,
            data: 'privateFixture',
          ),
        );
        await expectLater(
          guardDio<void>(() => throw error),
          throwsA(
            type == DioExceptionType.cancel
                ? isA<RequestCancelled>()
                : isA<AppException>(),
          ),
        );
      }
      await expectLater(
        guardDio<void>(
          () => throw CheckedFromJsonException(
            {'privateBook': 'privateFixture'},
            'privateBook',
            'privateFixture',
            'privateFixture',
          ),
        ),
        throwsA(isA<ParseException>()),
      );
      await expectLater(
        guardDio<void>(
          () => throw const FormatException('privateFixture', 'privateBook'),
        ),
        throwsA(isA<ParseException>()),
      );
      assertRedacted();
    },
  );

  test(
    'HTML, error envelopes and HTTP errors only log safe status metadata',
    () async {
      for (final file in ['proxy_login.html', 'error_500.json']) {
        final body = File('test/fixtures/server/$file').readAsStringSync();
        for (final status in [200, 500]) {
          final client = transport(
            FakeServerAdapter((_, _) => jsonBody(body, status)),
          );
          await expectLater(
            client.getJson(['api', 'health']),
            throwsA(isA<AppException>()),
          );
        }
      }
      expect(records, hasLength(4));
      assertRedacted();
    },
  );

  test(
    'guard uses fixed route metadata and cancellation writes no failure',
    () async {
      final log = RedactedRequestLog(ServerRoute.book);
      final options = RequestOptions(
        path: '/deployment/privateBook',
        extra: {RedactedRequestLog.extraKey: log},
      );
      final exception = DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        message: 'privateFixture',
      );
      await expectLater(
        guardDio<void>(() => throw exception),
        throwsA(isA<NetworkException>()),
      );
      expect(records.single.message, contains('GET api/books/{id} status=-'));
      records.clear();
      await expectLater(
        guardDio<void>(
          () => throw DioException(
            requestOptions: options,
            type: DioExceptionType.cancel,
          ),
        ),
        throwsA(isA<RequestCancelled>()),
      );
      expect(records, isEmpty);
    },
  );
}
