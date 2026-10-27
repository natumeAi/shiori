import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/core/network/request_cancelled.dart';
import 'package:shiori/core/network/session_transport.dart';

import '../../features/library/data/library_test_support.dart';
import 'fake_server_adapter.dart';

void main() {
  Future<int> consume(Stream<Uint8List> chunks) async =>
      chunks.fold<int>(0, (count, chunk) => count + chunk.length);

  SessionTransport client(FakeServerAdapter adapter) {
    final transport = SessionTransport(session(), adapter: adapter);
    addTearDown(transport.dispose);
    return transport;
  }

  test('a consumer that abandons the stream cannot return success', () async {
    final adapter = FakeServerAdapter(
      (_, _) => ResponseBody.fromBytes(
        [1, 2],
        200,
        headers: {
          'content-type': ['application/epub+zip'],
        },
      ),
    );
    await expectLater(
      client(adapter).getFile<int>(7, maxBytes: 64, consume: (_) async => 0),
      throwsA(isA<ParseException>()),
    );
    expect(adapter.requests.single.cancelToken!.isCancelled, isTrue);
  });

  for (final conditional in [false, true]) {
    test(
      '304 is admitted only with an explicit conditional header: $conditional',
      () async {
        var consumed = false;
        final adapter = FakeServerAdapter(
          (_, _) => ResponseBody.fromString('', 304),
        );
        final future = client(adapter).getFile<int>(
          7,
          maxBytes: 64,
          ifNoneMatch: conditional ? 'W/"opaque"' : null,
          consume: (_) async {
            consumed = true;
            return 0;
          },
        );
        if (conditional) {
          expect((await future).statusCode, 304);
        } else {
          await expectLater(
            future,
            throwsA(
              isA<ServerException>().having((e) => e.statusCode, 'status', 304),
            ),
          );
        }
        expect(consumed, isFalse);
        expect(adapter.requests.length, 1);
      },
    );
  }

  test('raw source stays paused while file sink is blocked', () async {
    var emitted = 0;
    final blocked = Completer<void>();
    final writing = Completer<void>();
    Stream<Uint8List> chunks() async* {
      for (var index = 0; index < 10000; index++) {
        emitted++;
        yield Uint8List(16);
      }
    }

    final adapter = FakeServerAdapter(
      (_, _) => ResponseBody(
        chunks(),
        200,
        headers: {
          'content-type': ['application/octet-stream'],
        },
      ),
    );
    final cancel = CancelToken();
    final future = client(adapter).getFile<int>(
      7,
      maxBytes: 64,
      cancelToken: cancel,
      consume: (stream) async {
        await for (final _ in stream) {
          if (!writing.isCompleted) writing.complete();
          await blocked.future;
        }
        return 0;
      },
    );
    final assertion = expectLater(future, throwsA(isA<RequestCancelled>()));
    await writing.future;
    await Future<void>.delayed(Duration.zero);
    expect(emitted, lessThanOrEqualTo(3));
    cancel.cancel();
    blocked.complete();
    await assertion;
  });

  test(
    'safe redirects retain prefix, conditions and GET without Range',
    () async {
      final adapter = FakeServerAdapter(
        (_, index) => index == 0
            ? ResponseBody.fromString(
                '',
                302,
                headers: {
                  'location': ['file?full=1'],
                },
              )
            : ResponseBody.fromBytes(
                [1, 2],
                200,
                headers: {
                  'content-type': ['application/epub+zip'],
                },
              ),
      );
      final result = await client(adapter).getFile<int>(
        7,
        maxBytes: 2,
        ifNoneMatch: 'W/"opaque"',
        ifModifiedSince: 'untouched date',
        consume: consume,
      );
      expect(result.body, 2);
      expect(adapter.requests.length, 2);
      for (final request in adapter.requests) {
        expect(request.method, 'GET');
        expect(request.uri.path, '/Reader/api/books/7/file');
        expect(request.headers['If-None-Match'], 'W/"opaque"');
        expect(request.headers['If-Modified-Since'], isNull);
        expect(request.headers['Range'], isNull);
        expect(request.headers['If-Range'], isNull);
      }
    },
  );

  test(
    'per-call cancel before headers does not dispose the shared session',
    () async {
      final headers = Completer<ResponseBody>();
      final requested = Completer<void>();
      final adapter = FakeServerAdapter((_, index) {
        if (index == 0) {
          requested.complete();
          return headers.future;
        }
        return jsonBody();
      });
      final transport = client(adapter);
      final cancel = CancelToken();
      final future = transport.getFile<int>(
        7,
        maxBytes: 32,
        consume: consume,
        cancelToken: cancel,
      );
      final assertion = expectLater(future, throwsA(isA<RequestCancelled>()));
      await requested.future;
      cancel.cancel();
      await assertion;
      expect((await transport.getJson(['api', 'health'])).statusCode, 200);
      headers.complete(ResponseBody.fromString('', 200));
    },
  );
}
