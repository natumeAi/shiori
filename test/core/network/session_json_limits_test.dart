import 'dart:async';
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
  SessionTransport transport(FakeServerAdapter adapter) {
    final client = SessionTransport(
      ServerSession(
        endpoint: ServerEndpoint.parse('https://example.test/').endpoint!,
        generation: 1,
      ),
      adapter: adapter,
    );
    addTearDown(client.dispose);
    return client;
  }

  final routes = [
    (['api', 'health'], 64 * 1024, 'health_additive.json'),
    (['api', 'library', 'snapshot'], 8 * 1024 * 1024, 'snapshot_typical.json'),
    (['api', 'books', '7'], 256 * 1024, 'book_detail.json'),
    (['api', 'books', '7', 'file'], 64 * 1024, 'error_400.json'),
  ];
  for (final (route, limit, fixture) in routes) {
    for (final status in [200, 500]) {
      test(
        '$route status=$status cancels oversized unfinished chunked JSON',
        () async {
          final listening = Completer<void>();
          final cancelled = Completer<void>();
          final closed = Completer<void>();
          final source = StreamController<Uint8List>(
            onListen: listening.complete,
            onCancel: cancelled.complete,
          );
          addTearDown(source.close);
          final adapter = FakeServerAdapter(
            (_, _) => ResponseBody(
              source.stream,
              status,
              headers: {
                'content-type': ['application/json'],
              },
              onClose: closed.complete,
            ),
          );
          final check = expectLater(
            transport(adapter).getJson(route),
            throwsA(
              status == 200
                  ? isA<ParseException>().having(
                      (e) => e.cause,
                      'cause',
                      isNull,
                    )
                  : isA<ServerException>()
                        .having((e) => e.statusCode, 'status', status)
                        .having((e) => e.code, 'code', isNull),
            ),
          );
          await listening.future;
          final bound = status == 200 ? limit : 64 * 1024;
          final chunk = Uint8List(32 * 1024);
          for (var sent = 0; sent < bound; sent += chunk.length) {
            source.add(chunk);
          }
          source.add(Uint8List(1));
          await check;
          await cancelled.future;
          await closed.future;
          expect(source.isClosed, isFalse);
          expect(adapter.requests.single.cancelToken!.isCancelled, isTrue);
        },
      );
    }

    test('$route accepts JSON exactly at its byte limit', () async {
      final bytes = Uint8List(limit)..fillRange(0, limit, 0x20);
      bytes.setRange(0, 2, utf8.encode('{}'));
      final client = transport(
        FakeServerAdapter(
          (_, _) => ResponseBody.fromBytes(
            bytes,
            200,
            headers: {
              'content-type': ['application/json'],
            },
          ),
        ),
      );
      expect((await client.getJson(route)).body, <String, Object?>{});
    });

    test('$route still accepts $fixture', () async {
      final payload = File('test/fixtures/server/$fixture').readAsStringSync();
      final client = transport(FakeServerAdapter((_, _) => jsonBody(payload)));
      if (fixture.startsWith('error')) {
        await expectLater(
          client.getJson(route),
          throwsA(isA<ServerException>()),
        );
      } else {
        expect((await client.getJson(route)).body, jsonDecode(payload));
      }
    });
  }

  for (final status in [200, 500]) {
    test(
      'incompatible content type at $status fails without waiting for body',
      () async {
        final cancelled = Completer<void>();
        final closed = Completer<void>();
        final source = StreamController<Uint8List>(
          onCancel: cancelled.complete,
        );
        addTearDown(source.close);
        final adapter = FakeServerAdapter(
          (_, _) => ResponseBody(
            source.stream,
            status,
            headers: {
              'content-type': ['text/html'],
            },
            onClose: closed.complete,
          ),
        );
        await expectLater(
          transport(adapter).getJson(['api', 'health']),
          throwsA(
            status == 200 ? isA<ParseException>() : isA<ServerException>(),
          ),
        );
        await cancelled.future;
        await closed.future;
        expect(source.isClosed, isFalse);
        expect(adapter.requests.single.cancelToken!.isCancelled, isTrue);
      },
    );
  }

  test(
    'sixteen MiB additive health JSON stops before full reception',
    () async {
      var emitted = 0;
      final closed = Completer<void>();
      Stream<Uint8List> body() async* {
        yield Uint8List.fromList(
          utf8.encode(
            '{"status":"ok","service":"epub-reader-server",'
            '"database":"ok","padding":"',
          ),
        );
        for (var i = 0; i < 256; i++) {
          final chunk = Uint8List(65536)..fillRange(0, 65536, 120);
          emitted += chunk.length;
          yield chunk;
        }
        yield Uint8List.fromList(utf8.encode('"}'));
      }

      final client = transport(
        FakeServerAdapter(
          (_, _) => ResponseBody(
            body(),
            200,
            headers: {
              'content-type': ['application/json'],
            },
            onClose: closed.complete,
          ),
        ),
      );
      await expectLater(
        client.getJson(['api', 'health']),
        throwsA(isA<ParseException>()),
      );
      await closed.future;
      expect(emitted, lessThan(16 * 1024 * 1024));
    },
  );
}
