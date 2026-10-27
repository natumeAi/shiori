import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/session_publication_guard.dart';
import 'package:shiori/core/network/session_transport.dart';
import 'package:shiori/features/library/presentation/covers/cover_failure.dart';
import 'package:shiori/features/library/presentation/covers/cover_load_result.dart';
import 'package:shiori/features/library/presentation/covers/cover_loader.dart';

import '../../../../core/network/fake_server_adapter.dart';
import '../../data/library_test_support.dart';
import 'cover_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SessionPublicationGuard guard;
  late FakeServerAdapter adapter;
  late CoverLoader loader;
  final active = session();

  void setup(
    FutureOr<ResponseBody> Function(RequestOptions, int) respond, {
    int encoded = CoverLoader.defaultBudget,
    int decoded = CoverLoader.defaultBudget,
  }) {
    adapter = FakeServerAdapter(respond);
    final transport = SessionTransport(active, adapter: adapter);
    loader = CoverLoader(
      transport,
      guard,
      encodedBudget: encoded,
      decodedBudget: decoded,
    );
    addTearDown(() {
      loader.dispose();
      transport.dispose();
    });
  }

  setUp(() {
    guard = SessionPublicationGuard()..select(active);
    addTearDown(guard.retire);
  });

  test('server path uses prefixed GET preserving encoded path and query, decoded hit shares bytes', () async {
    final bytes = await png();
    setup((_, _) => imageBody(bytes));
    const path = '/covers/a%20b.png?v=a%2Fb';
    final first = await loader.load(path);
    final second = await loader.load(path);
    expect(first, isA<CoverLoaded>());
    expect(second, isA<CoverLoaded>());
    expect(adapter.requests.single.method, 'GET');
    expect(
      adapter.requests.single.uri.toString(),
      'https://example.test/Reader/covers/a%20b.png?v=a%2Fb',
    );
    expect(loader.encodedBytes, bytes.length);
    expect(loader.decodedBytes, 4);
    release(first);
    release(second);
    expect(CoverLoader.individualLimit, 8 * 1024 * 1024);
    expect(CoverLoader.defaultBudget, 16 * 1024 * 1024);
  });

  for (final path in [
    null,
    '',
    'cover.png',
    '/storage/cover.png',
    'https://foreign.test/covers/a',
    '/covers/../private',
  ]) {
    test(
      'missing or non-server cover path gets placeholder before traffic: $path',
      () async {
        setup((_, _) => throw StateError('no traffic'));
        expect(
          await loader.load(path),
          placeholder(
            path == null || path.isEmpty
                ? CoverFailure.missing
                : CoverFailure.invalidPath,
          ),
        );
        expect(adapter.requests, isEmpty);
      },
    );
  }

  test('encoded overflow aborts chunk source and returns typed oversized placeholder', () async {
    var emitted = 0;
    var cancelled = false;
    Stream<Uint8List> source() async* {
      try {
        for (var i = 0; i < 20; i++) {
          emitted++;
          yield Uint8List(1024 * 1024);
        }
      } finally {
        cancelled = true;
      }
    }

    setup((_, _) => ResponseBody(source(), 200));
    expect(
      await loader.load('/covers/large'),
      placeholder(CoverFailure.oversized),
    );
    expect(emitted, lessThan(20));
    expect(cancelled, isTrue);
    expect(loader.encodedBytes, 0);
    expect(loader.decodedBytes, 0);
  });

  test('exact 8 MiB valid image is accepted', () async {
    final bytes = await png(paddedLength: CoverLoader.individualLimit);
    setup((_, _) => imageBody(bytes));
    final result = await loader.load('/covers/boundary');
    expect(result, isA<CoverLoaded>());
    expect(loader.encodedBytes, CoverLoader.individualLimit);
    release(result);
  });

  test('non-image response never enters either cache', () async {
    setup((_, _) => ResponseBody.fromString('<html>login</html>', 200));
    expect(
      await loader.load('/covers/html'),
      placeholder(CoverFailure.nonImage),
    );
    expect(loader.encodedCount, 0);
    expect(loader.decodedCount, 0);
    expect(loader.reservedBytes, 0);
  });

  for (final kind in ['network', 'http', 'tls']) {
    test('$kind failure is a typed placeholder and never cached', () async {
      setup(
        (options, _) => switch (kind) {
          'network' => throw DioException.connectionError(
            requestOptions: options,
            reason: 'offline',
          ),
          'tls' => throw DioException(
            requestOptions: options,
            type: DioExceptionType.badCertificate,
          ),
          _ => jsonBody('{}', 404),
        },
      );
      expect(
        await loader.load('/covers/failure'),
        placeholder(
          kind == 'network' ? CoverFailure.network : CoverFailure.unavailable,
        ),
      );
      expect(adapter.requests.length, 1);
      expect(loader.encodedBytes, 0);
      expect(loader.decodedBytes, 0);
    });
  }

  test('encoded LRU evicts least recently used path and reuses validated bytes after pixel eviction', () async {
    final bytes = await png();
    setup((_, _) => imageBody(bytes), encoded: bytes.length * 2, decoded: 4);
    for (final path in ['a', 'b', 'a', 'c', 'b']) {
      release(await loader.load('/covers/$path'));
      expect(loader.encodedBytes, lessThanOrEqualTo(bytes.length * 2));
      expect(loader.decodedBytes, lessThanOrEqualTo(4));
    }
    expect(adapter.requests.map((r) => r.uri.path.split('/').last), [
      'a',
      'b',
      'c',
      'b',
    ]);
    expect(loader.encodedCount, 2);
    expect(loader.decodedCount, 1);
  });

  test(
    'decoded LRU evicts oldest unpinned entry and never evicts live images',
    () async {
      final bytes = await png();
      setup((_, _) => imageBody(bytes), decoded: 8);
      final a = await loader.load('/covers/a');
      final b = await loader.load('/covers/b');
      expect(
        await loader.load('/covers/c'),
        placeholder(CoverFailure.cacheBusy),
      );
      expect(loader.decodedBytes, 8);
      expect(loader.reservedBytes, 0);
      release(a);
      final c = await loader.load('/covers/c');
      expect(c, isA<CoverLoaded>());
      expect(loader.decodedBytes, 8);
      release(b);
      release(c);
    },
  );

  test('oversized pixel dimensions downsample before codec decode within pixel budget', () async {
    final bytes = await png(width: 100, height: 50);
    setup((_, _) => imageBody(bytes), decoded: 200);
    final result = await loader.load('/covers/pixels') as CoverLoaded;
    expect(
      result.lease.image.width * result.lease.image.height * 4,
      lessThanOrEqualTo(200),
    );
    expect(result.lease.image.width, lessThan(100));
    expect(loader.reservedBytes, 0);
    release(result);
  });

  test(
    'maxWidth decodes display-sized pixels per width over shared encoded bytes',
    () async {
      final bytes = await png(width: 768, height: 1097);
      setup((_, _) => imageBody(bytes));
      Future<(int, int)> size(int width) async {
        final result =
            await loader.load('/covers/t.webp', maxWidth: width) as CoverLoaded;
        final image = result.lease.image;
        release(result);
        return (image.width, image.height);
      }

      expect(await size(144), (144, 206));
      expect(await size(360), (360, 514));
      expect(await size(1000), (768, 1097)); // Never upscales.
      expect(await size(144), (144, 206));
      expect(adapter.requests.length, 1);
      expect(loader.encodedCount, 1);
      expect(loader.decodedCount, 3);
      await expectLater(
        loader.load('/covers/t.webp', maxWidth: 0),
        throwsArgumentError,
      );
    },
  );

  test(
    'default budgets keep a whole folder of 768 px thumbnails visible',
    () async {
      // Device regression: undecoded-width 768 px covers fit only four at once.
      final bytes = await png(width: 768, height: 1097);
      adapter = FakeServerAdapter((_, _) => imageBody(bytes));
      final transport = SessionTransport(active, adapter: adapter);
      loader = CoverLoader(transport, guard);
      addTearDown(() {
        loader.dispose();
        transport.dispose();
      });
      expect(loader.decodedBudget, 128 * 1024 * 1024);
      expect(loader.encodedBudget, 16 * 1024 * 1024);
      expect(CoverLoader.individualDecodedLimit, 16 * 1024 * 1024);
      final results = await Future.wait([
        for (var i = 0; i < 30; i++)
          loader.load('/covers/b$i.webp', maxWidth: 144),
      ]);
      expect(results, everyElement(isA<CoverLoaded>()));
      expect(loader.decodedBytes, 30 * 144 * 206 * 4);
      results.forEach(release);
    },
  );

  test(
    'unbounded width still caps one cover at the individual decoded limit',
    () async {
      final bytes = await png(width: 2100, height: 2100);
      setup(
        (_, _) => imageBody(bytes),
        decoded: CoverLoader.defaultDecodedBudget,
      );
      final result = await loader.load('/covers/huge') as CoverLoaded;
      expect(
        result.lease.image.width * result.lease.image.height * 4,
        lessThanOrEqualTo(CoverLoader.individualDecodedLimit),
      );
      expect(result.lease.image.width, lessThan(2100));
      release(result);
    },
  );

  test('concurrent same-path requests coalesce and retirement clears all owned state', () async {
    final bytes = await png();
    setup((_, _) => imageBody(bytes));
    final results = await Future.wait([
      loader.load('/covers/a'),
      loader.load('/covers/a'),
    ]);
    expect(adapter.requests.length, 1);
    expect(loader.decodedBytes, 4);
    guard.retire();
    expect(loader.encodedBytes, 0);
    expect(loader.decodedBytes, 0);
    expect(loader.encodedCount, 0);
    expect(loader.decodedCount, 0);
    for (final result in results) {
      release(result);
    }
    expect(await loader.load('/covers/a'), placeholder(CoverFailure.cancelled));
  });
}
