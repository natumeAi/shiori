import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/server_endpoint.dart';
import 'package:shiori/core/config/session_publication_guard.dart';

void main() {
  final a = ServerEndpoint.parse('https://a.example.test/').endpoint!;
  final b = ServerEndpoint.parse('https://b.example.test/').endpoint!;

  test('A -> B -> A rejects old A and B immediately before publication', () {
    final guard = SessionPublicationGuard();
    final first = guard.createSession(a);
    guard.select(first);
    expect(guard.publish(first, () {}), isTrue);
    guard.retire();
    final second = guard.createSession(b);
    guard.select(second);
    guard.retire();
    final third = guard.createSession(a);
    guard.select(third);
    var writes = 0;
    expect(first.serverKey, third.serverKey);
    expect(third.generation, greaterThan(second.generation));
    expect(guard.publish(first, () => writes++), isFalse);
    expect(guard.publish(second, () => writes++), isFalse);
    expect(guard.publish(third, () => writes++), isTrue);
    expect(writes, 1);
  });

  test('temporary sessions cannot publish', () {
    final guard = SessionPublicationGuard();
    final candidate = guard.createSession(a);
    expect(guard.isCurrent(candidate), isFalse);
    expect(
      guard.publish(candidate, () => fail('candidate published')),
      isFalse,
    );
  });

  test('retirement invalidates guard before releasing pending work', () {
    final guard = SessionPublicationGuard();
    final session = guard.createSession(a);
    guard.select(session);
    var cancels = 0;
    guard.onRetire(session, () {
      expect(guard.isCurrent(session), isFalse);
      cancels++;
    });
    guard.retire();
    guard.retire();
    expect(cancels, 1);
    guard.onRetire(session, () => cancels++);
    expect(cancels, 2);
  });

  test(
    'completed work unregisters and repeated callbacks own separate leases',
    () {
      final guard = SessionPublicationGuard();
      final session = guard.createSession(a);
      guard.select(session);
      var cancels = 0;
      void cancel() => cancels++;
      final unregister = guard.onRetire(session, cancel);
      guard.onRetire(session, cancel);
      unregister();
      unregister();
      guard.retire();
      expect(cancels, 1);
    },
  );
}
