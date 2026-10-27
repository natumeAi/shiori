import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/server_endpoint.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/core/config/session_publication_guard.dart';
import 'package:shiori/core/network/session_transport.dart';
import 'package:shiori/features/library/presentation/covers/cover_failure.dart';
import 'package:shiori/features/library/presentation/covers/cover_image_exception.dart';
import 'package:shiori/features/library/presentation/covers/cover_loader.dart';
import 'package:shiori/features/library/presentation/covers/session_cover_image.dart';
import 'package:shiori/features/servers/data/server_activation_dependencies.dart';

import '../../../../core/network/fake_server_adapter.dart';
import '../../../../helpers/pump_app.dart';
import '../../data/library_test_support.dart';
import 'cover_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final active = session();
  late SessionPublicationGuard guard;

  CoverLoader makeLoader(
    ServerSession session,
    FakeServerAdapter adapter, {
    int decoded = 16,
  }) {
    final transport = SessionTransport(session, adapter: adapter);
    final loader = CoverLoader(transport, guard, decodedBudget: decoded);
    addTearDown(() {
      loader.dispose();
      transport.dispose();
    });
    return loader;
  }

  setUp(() {
    guard = SessionPublicationGuard()..select(active);
    addTearDown(guard.retire);
  });

  test('image-provider key includes server key, generation and path', () {
    final adapter = FakeServerAdapter((_, _) => throw StateError('no traffic'));
    final a = makeLoader(active, adapter);
    final b = makeLoader(
      ServerSession(
        endpoint: ServerEndpoint.parse('https://b.test').endpoint!,
        generation: 2,
      ),
      adapter,
    );
    final a2 = makeLoader(
      ServerSession(endpoint: active.endpoint, generation: 3),
      adapter,
    );
    expect(
      SessionCoverImage(a, '/covers/x'),
      SessionCoverImage(a, '/covers/x'),
    );
    expect(
      SessionCoverImage(a, '/covers/x'),
      isNot(SessionCoverImage(a, '/covers/y')),
    );
    expect(
      SessionCoverImage(a, '/covers/x'),
      isNot(SessionCoverImage(b, '/covers/x')),
    );
    expect(
      SessionCoverImage(a, '/covers/x'),
      isNot(SessionCoverImage(a2, '/covers/x')),
    );
    expect(
      SessionCoverImage(a, '/covers/x', maxWidth: 144),
      SessionCoverImage(a, '/covers/x', maxWidth: 144),
    );
    expect(
      SessionCoverImage(a, '/covers/x', maxWidth: 144),
      isNot(SessionCoverImage(a, '/covers/x', maxWidth: 360)),
    );
  });

  test('image stream decodes at the requested display width', () async {
    final bytes = await png(width: 8, height: 4);
    final loader = makeLoader(
      active,
      FakeServerAdapter((_, _) => imageBody(bytes)),
    );
    final stream = SessionCoverImage(
      loader,
      '/covers/a',
      maxWidth: 2,
    ).resolve(ImageConfiguration.empty);
    final ready = Completer<ImageInfo>();
    final listener = ImageStreamListener(
      (info, _) => ready.complete(info),
      onError: ready.completeError,
    );
    stream.addListener(listener);
    final info = await ready.future;
    expect((info.image.width, info.image.height), (2, 1));
    stream.removeListener(listener);
    info.dispose();
  });

  test('image stream pins pixels, bypasses global cache, and unpins on listener removal', () async {
    final bytes = await png();
    final loader = makeLoader(
      active,
      FakeServerAdapter((_, _) => imageBody(bytes)),
      decoded: 4,
    );
    final globalBytes = PaintingBinding.instance.imageCache.currentSizeBytes;
    final stream = SessionCoverImage(
      loader,
      '/covers/a',
    ).resolve(ImageConfiguration.empty);
    final ready = Completer<ImageInfo>();
    final listener = ImageStreamListener(
      (info, _) => ready.complete(info),
      onError: ready.completeError,
    );
    stream.addListener(listener);
    final info = await ready.future;
    expect(info.image.width, 1);
    expect(await loader.load('/covers/b'), placeholder(CoverFailure.cacheBusy));
    stream.removeListener(listener);
    info.dispose();
    final b = await loader.load('/covers/b');
    release(b);
    expect(loader.decodedBytes, 4);
    expect(PaintingBinding.instance.imageCache.currentSizeBytes, globalBytes);
  });

  test(
    'keep-alive stream handles retain their pixel lease without listeners',
    () async {
      final bytes = await png();
      final loader = makeLoader(
        active,
        FakeServerAdapter((_, _) => imageBody(bytes)),
        decoded: 4,
      );
      final stream = SessionCoverImage(
        loader,
        '/covers/a',
      ).resolve(ImageConfiguration.empty);
      final ready = Completer<ImageInfo>();
      final listener = ImageStreamListener(
        (info, _) => ready.complete(info),
        onError: ready.completeError,
      );
      stream.addListener(listener);
      final info = await ready.future;
      final handle = stream.completer!.keepAlive();
      stream.removeListener(listener);
      expect(
        await loader.load('/covers/b'),
        placeholder(CoverFailure.cacheBusy),
      );
      var resumed = 0;
      final returning = ImageStreamListener((info, _) {
        resumed++;
        info.dispose();
      });
      stream.addListener(returning);
      expect(resumed, 1);
      stream.removeListener(returning);
      handle.dispose();
      info.dispose();
      release(await loader.load('/covers/b'));
      expect(loader.decodedBytes, 4);
    },
  );

  testWidgets('non-image typed error is rendered as widget placeholder', (
    tester,
  ) async {
    final loader = makeLoader(
      active,
      FakeServerAdapter((_, _) => ResponseBody.fromString('not an image', 200)),
    );
    final failed = Completer<CoverImageException>();
    await tester.runAsync(() async {
      await tester.pumpApp(
        Image(
          image: SessionCoverImage(loader, '/covers/bad'),
          errorBuilder: (_, error, _) {
            if (!failed.isCompleted) {
              failed.complete(error as CoverImageException);
            }
            return const SizedBox(key: Key('cover-placeholder'));
          },
        ),
      );
      // Decode runs on the engine's real async queue, outside the widget clock.
      await loader.load('/covers/bad');
    });
    await tester.pump();
    expect((await failed.future).reason, CoverFailure.nonImage);
    expect(find.byKey(const Key('cover-placeholder')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('retirement completes pending loads, discards late bytes and sends no image error', () async {
    final bytes = await png();
    final entered = Completer<void>();
    final response = Completer<ResponseBody>();
    final adapter = FakeServerAdapter((_, _) {
      entered.complete();
      return response.future;
    });
    final loader = makeLoader(active, adapter);
    var images = 0;
    var errors = 0;
    final stream = SessionCoverImage(
      loader,
      '/covers/late',
    ).resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener(
      (info, _) {
        images++;
        info.dispose();
      },
      onError: (_, _) {
        errors++;
      },
    );
    stream.addListener(listener);
    final waiting = loader.load('/covers/late');
    await entered.future;
    guard.retire();
    expect(await waiting, placeholder(CoverFailure.cancelled));
    response.complete(imageBody(bytes));
    await Future<void>.value();
    await Future<void>.value();
    expect(images, 0);
    expect(errors, 0);
    expect(loader.encodedBytes, 0);
    expect(loader.decodedBytes, 0);
    stream.removeListener(listener);
  });

  test(
    'provider disposal clears cache even while the session remains current',
    () async {
      final bytes = await png();
      final transport = SessionTransport(
        active,
        adapter: FakeServerAdapter((_, _) => imageBody(bytes)),
      );
      addTearDown(transport.dispose);
      final container = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [
          sessionPublicationGuardProvider.overrideWithValue(guard),
          sessionTransportProvider(active).overrideWithValue(transport),
        ],
      );
      final loader = container.read(coverLoaderProvider(active));
      release(await loader.load('/covers/a'));
      expect(loader.decodedBytes, 4);
      container.dispose();
      expect(loader.decodedBytes, 0);
      expect(loader.encodedBytes, 0);
      expect(
        await loader.load('/covers/a'),
        placeholder(CoverFailure.cancelled),
      );
    },
  );
}
