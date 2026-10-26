import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/core/network/guard_dio.dart';
import 'package:shiori/core/network/request_cancelled.dart';
import 'package:shiori/core/network/retry_policy.dart';

void main() {
  final requestOptions = RequestOptions(path: '/bookmarks');

  DioException badResponse(int statusCode) => DioException.badResponse(
    statusCode: statusCode,
    requestOptions: requestOptions,
    response: Response<void>(
      requestOptions: requestOptions,
      statusCode: statusCode,
    ),
  );

  test('returns the value of a successful request', () async {
    expect(await guardDio(() async => 42), 42);
  });

  for (final statusCode in [401, 403]) {
    test('maps a $statusCode response to UnauthorizedException', () {
      final error = badResponse(statusCode);

      expect(
        guardDio<void>(() => throw error),
        throwsA(
          isA<UnauthorizedException>().having((e) => e.cause, 'cause', error),
        ),
      );
    });
  }

  test('maps any other bad response to ServerException with its status', () {
    final error = badResponse(500);

    expect(
      guardDio<void>(() => throw error),
      throwsA(
        isA<ServerException>()
            .having((e) => e.statusCode, 'statusCode', 500)
            .having((e) => e.cause, 'cause', error),
      ),
    );
  });

  test('maps a bad response without a response to ServerException(null)', () {
    final error = DioException(
      requestOptions: requestOptions,
      type: DioExceptionType.badResponse,
    );

    expect(
      guardDio<void>(() => throw error),
      throwsA(
        isA<ServerException>().having((e) => e.statusCode, 'statusCode', null),
      ),
    );
  });

  for (final type in DioExceptionType.values.where(
    (type) =>
        type != DioExceptionType.badResponse &&
        type != DioExceptionType.cancel &&
        type != DioExceptionType.badCertificate,
  )) {
    test('maps ${type.name} to NetworkException', () {
      final error = DioException(requestOptions: requestOptions, type: type);

      expect(
        guardDio<void>(() => throw error),
        throwsA(isA<NetworkException>().having((e) => e.cause, 'cause', error)),
      );
    });
  }

  test('cancellation is control flow and never retried', () async {
    final error = DioException(
      requestOptions: requestOptions,
      type: DioExceptionType.cancel,
    );
    try {
      await guardDio<void>(() => throw error);
      fail('Expected cancellation');
    } on RequestCancelled catch (cancelled) {
      expect(cancelled, isNot(isA<AppException>()));
      expect(retryNetworkErrors(0, cancelled), isNull);
    }
  });

  test('bad certificate is not a retryable connection failure', () async {
    final error = DioException(
      requestOptions: requestOptions,
      type: DioExceptionType.badCertificate,
    );
    await expectLater(
      guardDio<void>(() => throw error),
      throwsA(isA<TlsException>()),
    );
    expect(retryNetworkErrors(0, TlsException(error)), isNull);
  });

  for (final type in [
    DioExceptionType.unknown,
    DioExceptionType.connectionError,
  ]) {
    test('HandshakeException in ${type.name} is TLS failure', () {
      final error = DioException(
        requestOptions: requestOptions,
        type: type,
        error: const HandshakeException('private certificate details'),
      );
      expect(guardDio<void>(() => throw error), throwsA(isA<TlsException>()));
    });
  }

  test('direct HandshakeException is TLS failure', () {
    expect(
      guardDio<void>(() => throw const HandshakeException()),
      throwsA(isA<TlsException>()),
    );
  });

  test('direct FormatException discards its private source', () {
    expect(
      guardDio<void>(() => throw const FormatException('bad', 'private')),
      throwsA(isA<ParseException>().having((e) => e.cause, 'cause', isNull)),
    );
  });

  test('maps an undecodable response body to ParseException', () {
    // What Dio throws when the transformer cannot decode the body.
    final error = DioException(
      requestOptions: requestOptions,
      error: const FormatException('Unexpected end of input'),
    );

    expect(
      guardDio<void>(() => throw error),
      throwsA(isA<ParseException>().having((e) => e.cause, 'cause', error)),
    );
  });

  test('maps an unknown socket failure to NetworkException', () {
    final error = DioException(
      requestOptions: requestOptions,
      error: const SocketException('Connection reset by peer'),
    );

    expect(
      guardDio<void>(() => throw error),
      throwsA(isA<NetworkException>().having((e) => e.cause, 'cause', error)),
    );
  });

  test('maps CheckedFromJsonException to ParseException', () {
    final error = CheckedFromJsonException(
      const {'id': 1},
      'id',
      'Bookmark',
      'type int is not a subtype of String',
    );

    expect(
      guardDio<void>(() => throw error),
      throwsA(isA<ParseException>().having((e) => e.cause, 'cause', error)),
    );
  });

  test('maps a failed cast at the JSON boundary to ParseException', () {
    const Object json = ['not', 'a', 'map'];

    expect(
      guardDio(() async => json as Map<String, Object?>),
      throwsA(
        isA<ParseException>().having((e) => e.cause, 'cause', isA<TypeError>()),
      ),
    );
  });

  test('lets unrelated errors through unchanged', () {
    final error = StateError('bug');

    expect(guardDio<void>(() => throw error), throwsA(same(error)));
  });

  test('bad response preserves opaque top-level server code', () {
    final error = DioException(
      requestOptions: requestOptions,
      type: DioExceptionType.badResponse,
      response: Response<Object?>(
        requestOptions: requestOptions,
        statusCode: 422,
        data: {'error': 'private message', 'code': 987654},
      ),
    );
    expect(
      guardDio<void>(() => throw error),
      throwsA(isA<ServerException>().having((e) => e.code, 'code', 987654)),
    );
  });
}
