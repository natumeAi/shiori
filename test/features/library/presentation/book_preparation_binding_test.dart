import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/library/data/publications/preparation_controller.dart';
import 'package:shiori/features/library/data/publications/preparation_state.dart';
import 'package:shiori/features/library/presentation/book_preparation_binding.dart';

import '../data/publications/prepare_test_support.dart';

void main() {
  test(
    'real D5 work and ready lease survive losing the route listener',
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
      final book = (h.state as PreparationReady).book;
      expect(book.isReleased, isFalse);
      final returned = h.container.listen(binding, (_, _) {});
      expect((h.state as PreparationReady).book, same(book));
      returned.close();
      await h.container.pump();
      expect(book.isReleased, isFalse);
      h.f.guard.retire();
      await h.container.pump();
      expect(book.isReleased, isTrue);
      await h.clean();
    },
  );

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
