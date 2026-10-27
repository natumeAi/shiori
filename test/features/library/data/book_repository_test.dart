import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/core/config/server_endpoint.dart';
import 'package:shiori/core/config/server_key.dart';
import 'package:shiori/core/config/session_publication_guard.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/core/network/request_cancelled.dart';
import 'package:shiori/core/network/session_transport.dart';
import 'package:shiori/features/library/data/book_repository.dart';
import 'package:shiori/features/library/data/models/book_detail_result.dart';
import 'package:shiori/features/servers/data/server_activation_dependencies.dart';

import '../../../core/network/fake_server_adapter.dart';
import 'library_test_support.dart';

void main() {
  late FakeServerAdapter adapter;
  late SessionTransport transport;
  late BookRepository repository;
  late SessionPublicationGuard guard;
  final active = session();
  final key = BookKey(active.serverKey, 7);

  setUp(() {
    guard = SessionPublicationGuard()..select(active);
    addTearDown(guard.retire);
    adapter = FakeServerAdapter(
      (_, _) => jsonBody(fixture('book_detail.json')),
    );
    transport = SessionTransport(active, adapter: adapter);
    repository = BookRepository(transport, guard);
    addTearDown(repository.dispose);
    addTearDown(transport.dispose);
  });

  test(
    'detail 200 uses BookKey and prefixed GET through session provider',
    () async {
      final container = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [
          sessionPublicationGuardProvider.overrideWithValue(guard),
          sessionTransportProvider(active).overrideWith((ref) => transport),
        ],
      );
      addTearDown(container.dispose);
      final result = await container
          .read(bookRepositoryProvider(active))
          .fetchBook(key);
      expect(result, isA<BookAvailable>());
      final available = result as BookAvailable;
      expect(available.key, key);
      expect(available.book.id, 7);
      expect(available.book.description, 'Synthetic fixture description.');
      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.uri.path, '/Reader/api/books/7');
      expect(
        adapter.requests.single.headers.containsKey('If-None-Match'),
        isFalse,
      );
    },
  );

  test('detail fixture 404 is typed unavailable', () async {
    final missing = SessionTransport(
      active,
      adapter: FakeServerAdapter(
        (_, _) => jsonBody(fixture('book_not_found.json'), 404),
      ),
    );
    addTearDown(missing.dispose);
    final result = await BookRepository(missing, guard).fetchBook(key);
    expect(result, BookDetailResult.unavailable(key));
  });

  test('foreign BookKey fails before HTTP', () async {
    final foreign = BookKey(
      ServerKey(ServerEndpoint.parse('https://other.test').endpoint!),
      7,
    );
    await expectLater(repository.fetchBook(foreign), throwsArgumentError);
    expect(adapter.requests, isEmpty);
  });

  for (final mutation in [
    'wrongId',
    'missing',
    'shape',
    'fileSize',
    'timestamp',
  ]) {
    test('malformed detail $mutation is sanitized parse failure', () async {
      final body = payload('book_detail.json');
      final book = body['book']! as Map<String, Object?>;
      switch (mutation) {
        case 'wrongId':
          book['id'] = 8;
        case 'missing':
          book.remove('author');
        case 'shape':
          body['book'] = [];
        case 'fileSize':
          book['fileSize'] = -1;
        case 'timestamp':
          book['createdAt'] = '2026-01-01T01:00:00';
      }
      final invalid = SessionTransport(
        active,
        adapter: FakeServerAdapter((_, _) => jsonBody(jsonEncode(body))),
      );
      addTearDown(invalid.dispose);
      await expectLater(
        BookRepository(invalid, guard).fetchBook(key),
        throwsA(isA<ParseException>().having((e) => e.cause, 'cause', isNull)),
      );
    });
  }
  for (final status in [401, 403, 500, 304]) {
    test('detail HTTP $status retains transport classification', () async {
      final failing = SessionTransport(
        active,
        adapter: FakeServerAdapter((_, _) => jsonBody('{}', status)),
      );
      addTearDown(failing.dispose);
      await expectLater(
        BookRepository(failing, guard).fetchBook(key),
        throwsA(
          status == 401 || status == 403
              ? isA<UnauthorizedException>()
              : isA<ServerException>().having(
                  (e) => e.statusCode,
                  'status',
                  status,
                ),
        ),
      );
    });
  }
  for (final type in [
    DioExceptionType.connectionError,
    DioExceptionType.badCertificate,
  ]) {
    test('detail Dio $type remains typed', () async {
      final failing = SessionTransport(
        active,
        adapter: FakeServerAdapter((options, _) {
          throw DioException(requestOptions: options, type: type);
        }),
      );
      addTearDown(failing.dispose);
      await expectLater(
        BookRepository(failing, guard).fetchBook(key),
        throwsA(
          type == DioExceptionType.badCertificate
              ? isA<TlsException>()
              : isA<NetworkException>(),
        ),
      );
    });
  }
  test('disposed detail transport stays cancellation control flow', () async {
    transport.dispose();
    await expectLater(
      repository.fetchBook(key),
      throwsA(isA<RequestCancelled>()),
    );
    expect(adapter.requests, isEmpty);
  });

  test('repository itself rejects retired detail even when transport is still open', () async {
    final entered = Completer<void>();
    final response = Completer<ResponseBody>();
    final delayed = SessionTransport(
      active,
      adapter: FakeServerAdapter((_, _) {
        entered.complete();
        return response.future;
      }),
    );
    addTearDown(delayed.dispose);
    final repo = BookRepository(delayed, guard);
    addTearDown(repo.dispose);
    final result = repo.fetchBook(key);
    final cancelled = expectLater(result, throwsA(isA<RequestCancelled>()));
    await entered.future;
    guard.retire();
    await cancelled;
    response.complete(jsonBody(fixture('book_detail.json')));
    await Future<void>.value();
  });
}
