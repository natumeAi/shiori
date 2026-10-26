import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/server_endpoint.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/core/network/request_cancelled.dart';
import 'package:shiori/core/network/retry_policy.dart';
import 'package:shiori/core/network/session_transport.dart';

import 'fake_server_adapter.dart';

void main() {
  ServerSession session(int generation) => ServerSession(
    endpoint: ServerEndpoint.parse('https://private.example.test/deployment/')
        .endpoint!,
    generation: generation,
  );
  SessionTransport transport(FakeServerAdapter adapter) {
    final value = SessionTransport(session(1), adapter: adapter);
    addTearDown(value.dispose);
    return value;
  }

  for (final type in DioExceptionType.values) {
    test(
      'adapter ${type.name} is classified after real request dispatch',
      () async {
        final adapter = FakeServerAdapter(
          (options, _) => throw DioException(
            requestOptions: options,
            type: type,
            response: type == DioExceptionType.badResponse
                ? Response<void>(requestOptions: options, statusCode: 503)
                : null,
          ),
        );
        final Matcher expected = switch (type) {
          DioExceptionType.cancel => isA<RequestCancelled>(),
          DioExceptionType.badCertificate => isA<TlsException>(),
          DioExceptionType.badResponse => isA<ServerException>(),
          _ => isA<NetworkException>(),
        };
        await expectLater(
          transport(adapter).getJson(['api', 'health']),
          throwsA(expected),
        );
        expect(adapter.requests.single.uri.path, '/deployment/api/health');
      },
    );
  }

  test('adapter HandshakeException remains non-retried TLS error', () async {
    final client = transport(
      FakeServerAdapter(
        (_, _) => throw const HandshakeException('private host/certificate'),
      ),
    );
    await expectLater(
      client.getJson(['api', 'health']),
      throwsA(isA<TlsException>()),
    );
    expect(retryNetworkErrors(0, const TlsException()), isNull);
  });

  for (final error in <Object>[
    const SocketException('private socket'),
    const HttpException('private HTTP'),
    TimeoutException('private timeout'),
    const HandshakeException('private TLS'),
  ]) {
    test(
      'receiving ${error.runtimeType} is classified after headers',
      () async {
        final client = transport(
          FakeServerAdapter(
            (_, _) => ResponseBody(Stream<Uint8List>.error(error), 200),
          ),
        );
        await expectLater(
          client.getJson(['api', 'health']),
          throwsA(
            error is HandshakeException
                ? isA<TlsException>()
                : isA<NetworkException>(),
          ),
        );
      },
    );
  }

  test(
    'cover overflow cancels a source that has not finished receiving',
    () async {
      final listening = Completer<void>();
      final cancelled = Completer<void>();
      final source = StreamController<Uint8List>(
        onListen: () => listening.complete(),
        onCancel: () => cancelled.complete(),
      );
      addTearDown(source.close);
      final client = transport(
        FakeServerAdapter((_, _) => ResponseBody(source.stream, 200)),
      );
      final check = expectLater(
        client.getBytes('/covers/a', maxBytes: 5),
        throwsA(isA<ParseException>()),
      );
      await listening.future;
      source.add(Uint8List(3));
      source.add(Uint8List(3));
      await check;
      await cancelled.future;
      // No end-of-stream or Content-Length was needed to detect overflow.
      expect(source.isClosed, isFalse);
    },
  );

  test(
    'dispose cancels every pending header request and future calls',
    () async {
      final entered = Completer<void>();
      final pending = Completer<ResponseBody>();
      final adapter = FakeServerAdapter((_, index) {
        if (index == 2) entered.complete();
        return pending.future;
      });
      final client = transport(adapter);
      final calls = [
        client.getJson(['api', 'health']),
        client.getJson(['api', 'books', '7']),
        client.getBytes('/covers/a', maxBytes: 4),
      ];
      final checks = calls
          .map((call) => expectLater(call, throwsA(isA<RequestCancelled>())))
          .toList();
      await entered.future;
      client.dispose();
      client.dispose();
      await Future.wait(checks);
      expect(adapter.closed, isTrue);
      expect(adapter.forceClosed, isTrue);
      expect(adapter.requests.every((r) => r.cancelToken!.isCancelled), isTrue);
      await expectLater(
        client.getJson(['api', 'health']),
        throwsA(isA<RequestCancelled>()),
      );
      expect(adapter.requests, hasLength(3));
      expect(retryNetworkErrors(0, const RequestCancelled()), isNull);
      // A late adapter completion cannot resurrect or publish the retired call.
      pending.complete(jsonBody());
      await Future<void>.delayed(Duration.zero);
    },
  );

  for (final cover in [false, true]) {
    test(
      'dispose cancels stalled ${cover ? 'cover' : 'JSON'} response stream',
      () async {
        final listening = Completer<void>();
        final source = StreamController<Uint8List>(
          onListen: () => listening.complete(),
        );
        addTearDown(source.close);
        var bodyClosed = false;
        final client = transport(
          FakeServerAdapter(
            (_, _) => ResponseBody(
              source.stream,
              200,
              onClose: () => bodyClosed = true,
            ),
          ),
        );
        final request = cover
            ? client.getBytes('/covers/a', maxBytes: 10)
            : client.getJson(['api', 'health']);
        final check = expectLater(request, throwsA(isA<RequestCancelled>()));
        await listening.future;
        source.add(Uint8List.fromList([123]));
        client.dispose();
        await check;
        expect(bodyClosed, isTrue);
      },
    );
  }

  test(
    'generation families isolate A to B to A and dispose their owners',
    () async {
      final container = ProviderContainer(retry: (_, _) => null);
      final first = container.read(sessionTransportProvider(session(1)));
      expect(container.read(sessionTransportProvider(session(1))), same(first));
      final bSession = ServerSession(
        endpoint: ServerEndpoint.parse('https://other.test').endpoint!,
        generation: 2,
      );
      final second = container.read(sessionTransportProvider(bSession));
      final third = container.read(sessionTransportProvider(session(3)));
      expect(first, isNot(same(second)));
      expect(first, isNot(same(third)));
      container.invalidate(sessionTransportProvider(session(1)));
      await expectLater(
        first.getJson(['api', 'health']),
        throwsA(isA<RequestCancelled>()),
      );
      container.dispose();
      await expectLater(
        second.getJson(['api', 'health']),
        throwsA(isA<RequestCancelled>()),
      );
      await expectLater(
        third.getJson(['api', 'health']),
        throwsA(isA<RequestCancelled>()),
      );
    },
  );
}
