import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/core/network/request_cancelled.dart';
import 'package:shiori/features/library/data/publications/download_exception.dart';
import 'package:shiori/features/library/data/publications/download_result.dart';

import '../../../../core/network/fake_server_adapter.dart';
import '../library_test_support.dart';
import 'download_test_support.dart';

void main() {
  for (final name in [
    'file_200_chunked',
    'file_200_length',
    'file_200_no_validators',
  ]) {
    test(
      '$name stages exact bytes, hash, flush and opaque validators',
      () async {
        final h = await DownloadHarness.create(
          FakeServerAdapter((_, _) => fileFixture(name)),
        );
        final result = await h.service.download(h.key) as StagedDownload;
        final expected = name == 'file_200_length'
            ? List.filled(4096, 7)
            : epubBytes;
        expect(await File(result.path).readAsBytes(), expected);
        expect(result.byteLength, expected.length);
        expect(result.digest, sha256.convert(expected).toString());
        expect(
          result.path,
          matches(r'[/\\]shiori[/\\]v1[/\\]staging[/\\][0-9a-f]{32}\.part$'),
        );
        expect(
          result.etag,
          name == 'file_200_no_validators' ? null : 'W/"1000-19b76daa800"',
        );
        expect(
          result.lastModified,
          name == 'file_200_no_validators'
              ? null
              : 'Thu, 01 Jan 2026 00:00:00 GMT',
        );
        expect(h.writers.single.flushed, isTrue);
        expect(h.writers.single.closed, isTrue);
        final request = h.adapter.requests.single;
        expect(request.method, 'GET');
        expect(request.uri.path, '/Reader/api/books/7/file');
        expect(
          request.headers.keys.map((key) => key.toLowerCase()),
          isNot(
            anyElement(
              anyOf('range', 'if-range', 'if-none-match', 'if-modified-since'),
            ),
          ),
        );
        await result.file.discard();
      },
    );
  }

  test(
    'multiple chunks without length hash incrementally to the fixture digest',
    () async {
      Stream<Uint8List> chunks() async* {
        for (var start = 0; start < epubBytes.length; start += 13) {
          yield Uint8List.sublistView(
            epubBytes,
            start,
            (start + 13).clamp(0, epubBytes.length),
          );
        }
      }

      final h = await DownloadHarness.create(
        FakeServerAdapter((_, _) => fileBody(stream: chunks())),
        limit: epubBytes.length,
      );
      final result = await h.service.download(h.key) as StagedDownload;
      expect(result.digest, sha256.convert(epubBytes).toString());
      expect(result.byteLength, epubBytes.length);
      await result.file.discard();
    },
  );

  for (final declared in [1, 100]) {
    test(
      'lying Content-Length $declared fails and deletes its own file',
      () async {
        final h = await DownloadHarness.create(
          FakeServerAdapter(
            (_, _) => fileBody(
              bytes: List.filled(50, 1),
              headers: {
                'content-length': ['$declared'],
              },
            ),
          ),
        );
        await expectLater(
          h.service.download(h.key),
          throwsA(isA<ParseException>()),
        );
        expect(await h.parts(), isEmpty);
      },
    );
  }

  test(
    'declared length over the ceiling is rejected before creating/writing',
    () async {
      Stream<Uint8List> chunks() async* {
        yield Uint8List(100);
      }

      final h = await DownloadHarness.create(
        FakeServerAdapter(
          (_, _) => fileBody(
            stream: chunks(),
            headers: {
              'content-length': ['101'],
            },
          ),
        ),
        limit: 100,
      );
      await expectLater(
        h.service.download(h.key),
        throwsA(isA<ParseException>()),
      );
      expect(h.writers, isEmpty);
      expect(await h.parts(), isEmpty);
    },
  );

  test(
    'actual overflow stops upstream at the limit and removes .part',
    () async {
      var emitted = 0;
      Stream<Uint8List> chunks() async* {
        for (var index = 0; index < 10000; index++) {
          emitted += 16;
          yield Uint8List(16);
        }
      }

      final h = await DownloadHarness.create(
        FakeServerAdapter(
          (_, _) => fileBody(
            stream: chunks(),
            headers: {
              'content-length': ['1'],
            },
          ),
        ),
        limit: 64,
      );
      await expectLater(
        h.service.download(h.key),
        throwsA(isA<ParseException>()),
      );
      expect(h.writers.single.bytes, 64);
      expect(emitted, lessThanOrEqualTo(112));
      expect(h.adapter.requests.single.cancelToken!.isCancelled, isTrue);
      expect(await h.parts(), isEmpty);
    },
  );

  for (final type in [
    'text/html; charset=utf-8',
    'application/json',
    'text/plain',
    'application/problem+json',
  ]) {
    test('200 $type is rejected without creating or writing a file', () async {
      Stream<Uint8List> chunks() async* {
        yield Uint8List.fromList(
          fixture(type.contains('json') ? 'error_500.json' : 'proxy_login.html')
              .codeUnits,
        );
      }

      final h = await DownloadHarness.create(
        FakeServerAdapter(
          (_, _) => fileBody(
            stream: chunks(),
            headers: {
              'content-type': [type],
            },
          ),
        ),
      );
      await expectLater(
        h.service.download(h.key),
        throwsA(isA<ParseException>()),
      );
      expect(h.writers, isEmpty);
      expect(await h.parts(), isEmpty);
    });
  }

  for (final point in ['write', 'flush', 'close']) {
    test(
      'disk failure at $point closes and deletes only the attempt file',
      () async {
        final h = await DownloadHarness.create(
          FakeServerAdapter((_, _) => fileBody()),
          failAt: point,
        );
        final local = await h.local();
        await expectLater(
          h.service.download(h.key, local: local),
          throwsA(
            isA<DownloadException>().having(
              (e) => e.failure,
              'failure',
              DownloadFailure.storage,
            ),
          ),
        );
        expect(await h.parts(), isEmpty);
        expect(await File(local.path).readAsBytes(), epubBytes);
        expect(h.writers.single.closed, isTrue);
      },
    );
  }

  test(
    'per-call cancellation interrupts a stalled stream and deletes .part',
    () async {
      final held = HeldBody();
      final h = await DownloadHarness.create(
        FakeServerAdapter((_, _) => fileBody(stream: held.controller.stream)),
      );
      final cancel = CancelToken();
      final future = h.service.download(h.key, cancelToken: cancel);
      final assertion = expectLater(future, throwsA(isA<RequestCancelled>()));
      await held.started.future;
      held.controller.add(Uint8List(32));
      await h.firstWrite.future;
      cancel.cancel();
      await assertion;
      await held.cancelled.future;
      expect(await h.parts(), isEmpty);
      expect(h.writers.single.closed, isTrue);
    },
  );

  test(
    'receive failure removes only its own part and does not retry',
    () async {
      Stream<Uint8List> chunks() async* {
        yield Uint8List(16);
        throw const SocketException('injected disconnect');
      }

      final h = await DownloadHarness.create(
        FakeServerAdapter((_, _) => fileBody(stream: chunks())),
      );
      final sentinel = await File(
        '${(await h.staging.directory()).path}/other.part',
      ).writeAsString('keep');
      await expectLater(
        h.service.download(h.key),
        throwsA(isA<NetworkException>()),
      );
      expect(h.adapter.requests.length, 1);
      expect(await sentinel.readAsString(), 'keep');
      expect((await h.parts()).map((file) => file.absolute.uri), [
        sentinel.absolute.uri,
      ]);
      expect(h.writers.single.closed, isTrue);
    },
  );
}
