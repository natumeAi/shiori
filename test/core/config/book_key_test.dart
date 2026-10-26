import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/core/config/server_endpoint.dart';
import 'package:shiori/core/config/server_key.dart';

void main() {
  final server = ServerKey(
    ServerEndpoint.parse('https://example.test').endpoint!,
  );
  final alias = ServerKey(
    ServerEndpoint.parse('https://EXAMPLE.TEST:443/').endpoint!,
  );
  final other = ServerKey(
    ServerEndpoint.parse('https://example.test/other').endpoint!,
  );

  test('equal server and book IDs have value equality and matching hashes', () {
    final left = BookKey(server, 7);
    final right = BookKey(alias, 7);
    expect(left, right);
    expect(left.hashCode, right.hashCode);
    expect(left.serverKey, server);
    expect(left.bookId, 7);
    expect({left, right}, hasLength(1));
  });

  test('same numeric ID on different deployments never compares equal', () {
    expect(BookKey(server, 7), isNot(BookKey(other, 7)));
    expect(BookKey(server, 7), isNot(BookKey(server, 8)));
    expect(BookKey(server, 7), isNot(7));
  });

  for (final id in [1, 9007199254740991]) {
    test('accepts safe positive boundary $id', () {
      expect(BookKey(server, id).bookId, id);
    });
  }

  for (final id in [0, -1, 9007199254740992, 9223372036854775807]) {
    test('rejects unsafe book ID $id at runtime', () {
      expect(() => BookKey(server, id), throwsRangeError);
    });
  }
}
