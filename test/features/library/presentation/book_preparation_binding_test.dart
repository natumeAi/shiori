import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/core/storage/stored_publication.dart';
import 'package:shiori/features/library/data/publications/preparation_controller.dart';
import 'package:shiori/features/library/data/publications/preparation_state.dart';
import 'package:shiori/features/library/data/publications/publication_cache_exception.dart';
import 'package:shiori/features/library/presentation/book_preparation_binding.dart';

import '../data/publications/prepare_test_support.dart';
import '../data/library_test_support.dart' show fixture;

void main() {
  test(
    'real work finishes off-screen and releases its lease for eviction',
    () async {
      final h = await PrepareHarness.create();
      final binding = bookPreparationBindingProvider(h.session, h.key);
      final route = h.container.listen(binding, (_, _) {});
      final body = HeldBody();
      h.respondFile = (_) => fileBody(stream: body.controller.stream);
      final pending = h.controller.prepare();
      await body.started.future;
      await h.container.pump();
      route.close();
      await h.container.pump();
      expect(h.state, isA<PreparationPreparing>());
      final progress = Completer<void>();
      final observer = h.container.listen(
        preparationControllerProvider(h.session, h.key),
        (_, next) {
          if (next case PreparationPreparing(receivedBytes: final int count)
              when count > 0) {
            if (!progress.isCompleted) progress.complete();
          }
        },
      );
      body.controller.add(Uint8List.sublistView(h.bytes, 0, 10));
      await progress.future;
      observer.close();
      await h.container.pump();
      body.controller.add(Uint8List.sublistView(h.bytes, 10));
      await body.controller.close();
      await pending;
      await h.container.pump();
      final summary = (h.state as PreparationDetached).publication;
      final charge = await h.f.cache.reserveBytes(h.f.cache.budget.limit);
      charge.release();
      // The retained summary is safe even after its cached bytes are evicted.
      expect(summary.identity.bookKey, h.key);
      expect(await h.f.store.readPublicationHead(h.key), isNull);
      await h.clean();
    },
  );

  test('returning to ready reacquires a verified lease without HTTP', () async {
    final h = await PrepareHarness.create();
    final binding = bookPreparationBindingProvider(h.session, h.key);
    final route = h.container.listen(binding, (_, _) {});
    await h.controller.prepare();
    final book = (h.state as PreparationReady).book;
    route.close();
    await h.container.pump();
    expect(book.isReleased, isTrue);
    expect(
      (h.state as PreparationDetached).publication,
      same(book.publication),
    );
    final requests = h.adapter.requests.length;
    final returned = h.container.listen(binding, (_, _) {});
    await waitForReturn(h);
    final reacquired = (h.state as PreparationReady).book;
    expect(reacquired.publication, same(book.publication));
    expect(reacquired.isReleased, isFalse);
    expect(h.adapter.requests, hasLength(requests));
    returned.close();
    await h.container.pump();
    expect(reacquired.isReleased, isTrue);
    h.f.guard.retire();
    await h.container.pump();
    expect(h.container.exists(binding), isFalse);
    expect(
      h.container.exists(preparationControllerProvider(h.session, h.key)),
      isFalse,
    );
    await h.clean();
  });

  for (final loss in ['evicted', 'missing', 'corrupt', 'changed', 'version']) {
    test(
      'return with $loss head offers prepare instead of stale ready',
      () async {
        final h = await PrepareHarness.create();
        final binding = bookPreparationBindingProvider(h.session, h.key);
        final route = h.container.listen(binding, (_, _) {});
        await h.controller.prepare();
        final book = (h.state as PreparationReady).book;
        route.close();
        await h.container.pump();
        if (loss == 'evicted') {
          final charge = await h.f.cache.reserveBytes(h.f.cache.budget.limit);
          charge.release();
        } else if (loss == 'missing') {
          await File(book.lease.local.path).delete();
        } else if (loss == 'corrupt') {
          final corrupt = Uint8List.fromList(h.bytes);
          corrupt[0] ^= 1;
          await File(book.lease.local.path).writeAsBytes(corrupt, flush: true);
        } else if (loss == 'changed') {
          h.bytes = importZip(
            importEntries(
              sources: [sourcePage(body: '<p>Changed synthetic text</p>')],
            ),
          );
          final replacement = await h.service.prepare(h.key, refresh: true);
          expect(replacement.identity, isNot(book.identity));
          replacement.release();
        } else {
          final head = book.lease.generation;
          await h.f.store.publishGeneration(
            StoredPublication(
              key: head.key,
              sha256: head.sha256,
              byteLength: head.byteLength,
              parserVersion: head.parserVersion + 1,
              canonicalVersion: head.canonicalVersion,
              accessedAt: head.accessedAt,
            ),
          );
        }
        final requests = h.adapter.requests.length;
        final returned = h.container.listen(binding, (_, _) {});
        await waitForReturn(h);
        expect(h.state, isA<PreparationIdle>());
        expect(h.adapter.requests, hasLength(requests));
        // Neither the old owner nor a rejected replacement is pinned.
        final charge = await h.f.cache.reserveBytes(h.f.cache.budget.limit);
        charge.release();
        returned.close();
        await h.clean();
      },
    );
  }

  test(
    'independent file owners remain pinned after the route leaves',
    () async {
      final h = await PrepareHarness.create();
      final binding = bookPreparationBindingProvider(h.session, h.key);
      final route = h.container.listen(binding, (_, _) {});
      await h.controller.prepare();
      final book = (h.state as PreparationReady).book;
      final independent = (await h.f.cache.acquireHead(h.session, h.key))!;
      route.close();
      await h.container.pump();
      expect(book.isReleased, isTrue);
      expect(await File(independent.local.path).exists(), isTrue);
      await expectLater(
        h.f.cache.reserveBytes(h.f.cache.budget.limit),
        throwsA(
          isA<PublicationCacheException>().having(
            (error) => error.failure,
            'failure',
            PublicationCacheFailure.cacheBusy,
          ),
        ),
      );
      independent.release();
      final charge = await h.f.cache.reserveBytes(h.f.cache.budget.limit);
      charge.release();
      await h.clean();
    },
  );

  test(
    'returning during preparation keeps the same work and visible lease',
    () async {
      final h = await PrepareHarness.create();
      final binding = bookPreparationBindingProvider(h.session, h.key);
      final route = h.container.listen(binding, (_, _) {});
      final body = HeldBody();
      h.respondFile = (_) => fileBody(stream: body.controller.stream);
      final pending = h.controller.prepare();
      await body.started.future;
      route.close();
      await h.container.pump();
      final requests = h.adapter.requests.length;
      final returned = h.container.listen(binding, (_, _) {});
      await h.container.pump();
      expect(h.state, isA<PreparationPreparing>());
      body.controller.add(h.bytes);
      await body.controller.close();
      await pending;
      final book = (h.state as PreparationReady).book;
      expect(book.isReleased, isFalse);
      expect(h.adapter.requests, hasLength(requests));
      returned.close();
      await h.container.pump();
      expect(book.isReleased, isTrue);
      await h.clean();
    },
  );

  test('the last visible route releases the shared view lease', () async {
    final h = await PrepareHarness.create();
    final binding = bookPreparationBindingProvider(h.session, h.key);
    final first = h.container.listen(binding, (_, _) {});
    final second = h.container.listen(binding, (_, _) {});
    await h.controller.prepare();
    final book = (h.state as PreparationReady).book;
    first.close();
    await h.container.pump();
    expect(h.state, isA<PreparationReady>());
    expect(book.isReleased, isFalse);
    second.close();
    await h.container.pump();
    expect(h.state, isA<PreparationDetached>());
    expect(book.isReleased, isTrue);
    await h.clean();
  });

  for (final action in ['leave', 'cancel', 'retire']) {
    test('$action during local return cannot retain a late lease', () async {
      final h = await PrepareHarness.create();
      final session = h.session;
      final key = h.key;
      final binding = bookPreparationBindingProvider(session, key);
      final route = h.container.listen(binding, (_, _) {});
      await h.controller.prepare();
      route.close();
      await h.container.pump();
      final requests = h.adapter.requests.length;
      final controller = h.controller;
      final returned = h.container.listen(binding, (_, _) {});
      final started = Completer<void>();
      final finished = Completer<void>();
      final observer = h.container.listen(
        preparationControllerProvider(session, key),
        (_, next) {
          if (next is PreparationPreparing && !started.isCompleted) {
            started.complete();
            switch (action) {
              case 'leave':
                returned.close();
              case 'cancel':
                controller.cancel();
              case 'retire':
                h.f.select(serverB);
            }
          } else if (started.isCompleted && !finished.isCompleted) {
            finished.complete();
          }
        },
      );
      await started.future;
      await finished.future;
      await h.container.pump();
      expect(
        h.container.read(preparationControllerProvider(session, key)),
        action == 'leave' ? isA<PreparationDetached>() : isA<PreparationIdle>(),
      );
      expect(h.adapter.requests, hasLength(requests));
      final charge = await h.f.cache.reserveBytes(h.f.cache.budget.limit);
      charge.release();
      observer.close();
      returned.close();
      await h.clean();
    });
  }

  test('departed ready books cannot fill the cache with leases', () async {
    final bytes = importZip(importEntries());
    final h = await PrepareHarness.create(limit: bytes.length * 2);
    final session = h.session;
    h.adapter = FakeServerAdapter((options, _) {
      if (options.uri.path.endsWith('/file')) {
        return ResponseBody.fromBytes(
          bytes,
          200,
          headers: {
            'content-type': ['application/epub+zip'],
            'content-length': ['${bytes.length}'],
          },
        );
      }
      final detail =
          jsonDecode(fixture('book_detail.json')) as Map<String, dynamic>;
      (detail['book'] as Map<String, dynamic>)['id'] = int.parse(
        options.uri.pathSegments.last,
      );
      return jsonBody(jsonEncode(detail));
    });
    for (final id in [7, 8, 9, 10, 11]) {
      final key = BookKey(h.session.serverKey, id);
      final binding = bookPreparationBindingProvider(h.session, key);
      final route = h.container.listen(binding, (_, _) {});
      final provider = preparationControllerProvider(h.session, key);
      await h.container.read(provider.notifier).prepare();
      final book = (h.container.read(provider) as PreparationReady).book;
      route.close();
      await h.container.pump();
      expect(h.container.exists(binding), isTrue);
      expect(h.container.read(provider), isA<PreparationDetached>());
      expect(book.isReleased, isTrue);
    }
    expect(await h.f.store.readPublicationHead(h.key), isNull);
    h.f.select(serverB);
    await h.container.pump();
    for (final id in [7, 8, 9, 10, 11]) {
      final key = BookKey(session.serverKey, id);
      // All detached summaries belong to the retired activation.
      expect(
        h.container.exists(bookPreparationBindingProvider(session, key)),
        isFalse,
      );
    }
    await h.clean();
  });

  test('binding retirement during real download rejects late work', () async {
    final h = await PrepareHarness.create();
    final oldSession = h.session;
    final oldKey = h.key;
    final binding = bookPreparationBindingProvider(oldSession, oldKey);
    final route = h.container.listen(binding, (_, _) {});
    final body = HeldBody();
    h.respondFile = (_) => fileBody(stream: body.controller.stream);
    final pending = h.controller.prepare();
    await body.started.future;
    await h.container.pump();
    route.close();
    await h.container.pump();
    h.f.select(serverB);
    await pending;
    await h.container.pump();
    expect(await h.f.store.readPublicationHead(oldKey), isNull);
    expect(h.container.exists(binding), isFalse);
    await h.clean();
  });
}

Future<void> waitForReturn(PrepareHarness h) async {
  final settled = Completer<void>();
  final observer = h.container.listen(
    preparationControllerProvider(h.session, h.key),
    (_, next) {
      if (next is! PreparationPreparing && next is! PreparationDetached) {
        if (!settled.isCompleted) settled.complete();
      }
    },
    fireImmediately: true,
  );
  await settled.future;
  observer.close();
}
