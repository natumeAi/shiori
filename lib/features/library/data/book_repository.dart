import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/core/config/session_publication_guard.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/core/network/guard_dio.dart';
import 'package:shiori/core/network/request_cancelled.dart';
import 'package:shiori/core/network/session_transport.dart';
import 'package:shiori/features/library/data/library_decode_exception.dart';
import 'package:shiori/features/library/data/library_session_scope.dart';
import 'package:shiori/features/library/data/models/book_detail_result.dart';
import 'package:shiori/features/library/data/models/book_response.dart';
import 'package:shiori/features/servers/data/server_activation_dependencies.dart';

part 'book_repository.g.dart';

final class BookRepository {
  BookRepository(this._transport, SessionPublicationGuard guard)
    : _scope = LibrarySessionScope(_transport.session, guard);
  final SessionTransport _transport;
  final LibrarySessionScope _scope;

  void dispose() => _scope.dispose();

  Future<BookDetailResult> fetchBook(BookKey key) => guardDio(() async {
    _scope.check();
    if (key.serverKey != _transport.session.serverKey) {
      throw ArgumentError('Book key does not belong to this session');
    }
    try {
      final response = await _scope.wait(
        _transport.getJson(['api', 'books', '${key.bookId}']),
      );
      final book = decodeLibraryValue(
        () => BookResponse.fromJson(response.body as Map<String, Object?>).book,
      );
      if (book.id != key.bookId) {
        throw const LibraryDecodeException(LibraryInvariant.detailIdentity);
      }
      return BookDetailResult.available(key, book);
    } on ServerException catch (error) {
      if (error.statusCode == 404) return BookDetailResult.unavailable(key);
      rethrow;
    } on LibraryDecodeException {
      throw const ParseException();
    }
  });
}

@Riverpod(keepAlive: true)
BookRepository bookRepository(Ref ref, ServerSession session) {
  final repository = BookRepository(
    ref.watch(sessionTransportProvider(session)),
    ref.watch(sessionPublicationGuardProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
}

/// UI-facing detail read: a retired/disposed view completes without AsyncError.
@riverpod
Future<BookDetailResult?> bookDetail(
  Ref ref,
  ServerSession session,
  BookKey key,
) async {
  final repository = ref.watch(bookRepositoryProvider(session));
  final scope = LibrarySessionScope(
    session,
    ref.watch(sessionPublicationGuardProvider),
  );
  ref.onDispose(scope.dispose);
  try {
    scope.check();
    return await scope.wait(repository.fetchBook(key));
  } on RequestCancelled {
    return null;
  }
}
