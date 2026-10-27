import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/resources/reader_resource_budget.dart';
import 'package:shiori/features/reader/data/resources/reader_resource_source.dart';

Matcher failure(ReaderResourceFailure value) => isA<ReaderResourceException>()
    .having((error) => error.failure, 'failure', value);

PreloadedReaderResourceSource admit(
  ReaderResourceSession session,
  String path,
  int size,
) => session.reserve({path: size}).commit({path: Uint8List(size)});

void main() {
  test('default global ceiling and invalid injectable limits', () {
    expect(ReaderResourceBudget.shared.maxBytes, 128 * 1024 * 1024);
    expect(() => ReaderResourceBudget(maxBytes: -1), throwsArgumentError);
    expect(
      () => ReaderResourceBudget(
        maxBytes: ReaderResourceBudget.defaultMaxBytes + 1,
      ),
      throwsArgumentError,
    );
  });

  test('all adapters share accounting; pinned admission fails atomically', () {
    final budget = ReaderResourceBudget(maxBytes: 8);
    final a = budget.createSession();
    final b = budget.createSession();
    final first = admit(a, 'image', 5);
    final second = admit(b, 'image', 3);
    expect(budget.retainedBytes, 8);
    expect(
      () => a.reserve({'another': 1}),
      throwsA(failure(ReaderResourceFailure.budgetExceeded)),
    );
    expect(budget.retainedBytes, 8);
    first.dispose();
    first.dispose();
    expect(budget.retainedBytes, 3);
    expect(second.bytes('image'), hasLength(3));
    second.dispose();
    expect(budget.accountedBytes, 0);
  });

  test(
    'shared cache hit leases prevent early disposal and duplicate copies',
    () {
      final budget = ReaderResourceBudget(maxBytes: 5);
      final session = budget.createSession();
      final first = admit(session, 'image', 5);
      final reservation = session.reserve({'image': 5});
      expect(reservation.missingLengths, isEmpty);
      final second = reservation.commit({});
      expect(identical(first.bytes('image'), second.bytes('image')), isTrue);
      expect(() => second.bytes('image')![0] = 1, throwsUnsupportedError);
      first.dispose();
      expect(budget.retainedBytes, 5);
      expect(second.bytes('image'), hasLength(5));
      second.dispose();
      expect(budget.accountedBytes, 0);
    },
  );

  test('LRU evicts only unleased entries, including across sessions', () {
    final budget = ReaderResourceBudget(maxBytes: 6);
    final session = budget.createSession();
    admit(session, 'a', 2).releaseToCache();
    admit(session, 'b', 2).releaseToCache();
    final pinned = admit(session, 'pinned', 2);
    final hit = session.reserve({'a': 2});
    hit.commit({}).releaseToCache(); // a was touched after b.
    final other = budget.createSession();
    final fresh = admit(other, 'fresh', 2);
    expect(budget.retainedBytes, 6);
    final b = session.reserve({'b': 2});
    expect(b.missingLengths, {'b': 2}); // b was evicted first.
    b.dispose();
    expect(pinned.bytes('pinned'), hasLength(2));
    fresh.dispose();
    session.retire();
    other.retire();
    expect(budget.accountedBytes, 0);
  });

  test(
    'reservation bytes count before commit and block competing admissions',
    () {
      final budget = ReaderResourceBudget(maxBytes: 4);
      final session = budget.createSession();
      final pending = session.reserve({'x': 4});
      expect(budget.reservedBytes, 4);
      expect(budget.retainedBytes, 0);
      expect(
        () => session.reserve({'x': 4}),
        throwsA(failure(ReaderResourceFailure.busy)),
      );
      expect(
        () => budget.createSession().reserve({'y': 1}),
        throwsA(failure(ReaderResourceFailure.budgetExceeded)),
      );
      pending.dispose();
      pending.dispose();
      expect(budget.accountedBytes, 0);
      admit(session, 'x', 4).dispose();
      expect(budget.accountedBytes, 0);
    },
  );

  test('malformed or oversized backing buffers roll back reservations', () {
    final budget = ReaderResourceBudget(maxBytes: 4);
    final session = budget.createSession();
    for (final bytes in [
      <String, Uint8List>{},
      {'x': Uint8List(3)},
      {'x': Uint8List.sublistView(Uint8List(20), 0, 4)},
    ]) {
      final pending = session.reserve({'x': 4});
      expect(
        () => pending.commit(bytes),
        throwsA(failure(ReaderResourceFailure.invalidTransfer)),
      );
      expect(budget.accountedBytes, 0);
    }
  });

  test(
    'retirement frees leased, idle and in-flight bytes and revokes adapters',
    () {
      final budget = ReaderResourceBudget(maxBytes: 10);
      final session = budget.createSession();
      final live = admit(session, 'live', 3);
      admit(session, 'idle', 3).releaseToCache();
      final pending = session.reserve({'pending': 4});
      session.retire();
      session.retire();
      expect(budget.accountedBytes, 0);
      expect(budget.entryCount, 0);
      expect(live.bytes('live'), isNull);
      expect(live.miss('live'), ReaderResourceMiss.retired);
      expect(
        () => pending.commit({'pending': Uint8List(4)}),
        throwsA(failure(ReaderResourceFailure.retired)),
      );
      expect(
        () => session.reserve({}),
        throwsA(failure(ReaderResourceFailure.retired)),
      );
    },
  );

  test(
    'missing, unrequested, empty and disposed are distinct without content',
    () {
      final budget = ReaderResourceBudget(maxBytes: 0);
      final session = budget.createSession();
      final events = <ReaderResourceMiss>[];
      final source = session
          .reserve({'empty': 0})
          .commit(
            {'empty': Uint8List(0)},
            absent: {'missing'},
            onMiss: events.add,
          );
      expect(source.contains('empty'), isTrue);
      expect(source.bytes('empty'), isEmpty);
      expect(source.bytes('missing'), isNull);
      expect(source.bytes('unknown-private-path'), isNull);
      expect(events, [
        ReaderResourceMiss.absent,
        ReaderResourceMiss.notPreloaded,
      ]);
      source.dispose();
      expect(source.miss('empty'), ReaderResourceMiss.disposed);
      expect(source.bytes('empty'), isNull);
    },
  );
}
