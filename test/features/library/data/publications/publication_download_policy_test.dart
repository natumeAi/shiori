import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/features/library/data/publications/download_exception.dart';
import 'package:shiori/features/library/data/publications/download_result.dart';

import '../../../../core/network/fake_server_adapter.dart';
import 'download_test_support.dart';

void main() {
  for (final useEtag in [true, false]) {
    test(
      '304 reuses verified local with exact ${useEtag ? 'ETag' : 'Last-Modified'}',
      () async {
        final h = await DownloadHarness.create(
          FakeServerAdapter((_, _) => fileFixture('file_304')),
        );
        final local = await h.local(etag: useEtag ? 'W/"opaque exact"' : null);
        final result = await h.service.download(
          h.key,
          local: local,
        ) as DownloadNotModified;
        expect(result.local, same(local));
        final headers = h.adapter.requests.single.headers;
        expect(headers['If-None-Match'], useEtag ? local.etag : null);
        expect(
          headers['If-Modified-Since'],
          useEtag ? null : local.lastModified,
        );
        expect(await h.parts(), isEmpty);
        expect(h.writers, isEmpty);
      },
    );
  }

  for (final invalidation in ['missing', 'length', 'digest']) {
    test('$invalidation before request prevents conditional reuse', () async {
      final h = await DownloadHarness.create(
        FakeServerAdapter((_, _) => fileBody()),
      );
      final local = await h.local();
      if (invalidation == 'missing') {
        await File(local.path).delete();
      } else {
        await File(local.path).writeAsBytes(
          List.filled(invalidation == 'length' ? 1 : local.byteLength, 0),
        );
      }
      final result =
          await h.service.download(h.key, local: local) as StagedDownload;
      expect(h.adapter.requests.single.headers['If-None-Match'], isNull);
      expect(h.adapter.requests.single.headers['If-Modified-Since'], isNull);
      await result.file.discard();
    });

    test(
      '$invalidation during 304 causes exactly one unconditional request',
      () async {
        late String path;
        final h = await DownloadHarness.create(
          FakeServerAdapter((_, index) async {
            if (index == 0) {
              if (invalidation == 'missing') {
                await File(path).delete();
              } else {
                final length = await File(path).length();
                await File(path).writeAsBytes(
                  List.filled(invalidation == 'length' ? 1 : length, 0),
                );
              }
              return fileFixture('file_304');
            }
            return fileBody();
          }),
        );
        final local = await h.local();
        path = local.path;
        final result =
            await h.service.download(h.key, local: local) as StagedDownload;
        expect(h.adapter.requests.length, 2);
        expect(h.adapter.requests.first.headers['If-None-Match'], local.etag);
        expect(h.adapter.requests.last.headers['If-None-Match'], isNull);
        expect(h.adapter.requests.last.headers['If-Modified-Since'], isNull);
        await result.file.discard();
      },
    );
  }

  for (final status in [206, 412, 416, 304]) {
    for (final recover in [true, false]) {
      test(
        '$status allows one unconditional recovery, success=$recover',
        () async {
          final h = await DownloadHarness.create(
            FakeServerAdapter(
              (_, index) => index == 0 || !recover
                  ? fileFixture('file_$status')
                  : fileBody(),
            ),
          );
          // No generation makes an unsolicited 304 a transport failure.
          final future = h.service.download(h.key);
          if (recover) {
            final result = await future as StagedDownload;
            await result.file.discard();
          } else {
            await expectLater(
              future,
              throwsA(
                isA<ServerException>().having(
                  (e) => e.statusCode,
                  'status',
                  status,
                ),
              ),
            );
            expect(await h.parts(), isEmpty);
          }
          expect(h.adapter.requests.length, 2);
          for (final request in h.adapter.requests) {
            expect(request.headers['If-None-Match'], isNull);
            expect(request.headers['If-Modified-Since'], isNull);
            expect(request.headers['Range'], isNull);
            expect(request.headers['If-Range'], isNull);
          }
        },
      );
    }
  }

  test('conditional 206 recovers without either validator', () async {
    final h = await DownloadHarness.create(
      FakeServerAdapter(
        (_, index) => index == 0 ? fileFixture('file_206') : fileBody(),
      ),
    );
    final local = await h.local();
    final result =
        await h.service.download(h.key, local: local) as StagedDownload;
    expect(h.adapter.requests.first.headers['If-None-Match'], local.etag);
    expect(h.adapter.requests.last.headers['If-None-Match'], isNull);
    expect(h.adapter.requests.last.headers['If-Modified-Since'], isNull);
    await result.file.discard();
  });

  test(
    'unusable conditional 304 then unsolicited 304 fails after two requests',
    () async {
      late String path;
      final h = await DownloadHarness.create(
        FakeServerAdapter((_, _) async {
          if (await File(path).exists()) await File(path).delete();
          return fileFixture('file_304');
        }),
      );
      final local = await h.local();
      path = local.path;
      await expectLater(
        h.service.download(h.key, local: local),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'status', 304),
        ),
      );
      expect(h.adapter.requests.length, 2);
    },
  );

  test('explicit refresh bypasses both local validators', () async {
    final h = await DownloadHarness.create(
      FakeServerAdapter((_, _) => fileBody()),
    );
    final local = await h.local();
    final result = await h.service.download(
      h.key,
      local: local,
      refresh: true,
    ) as StagedDownload;
    expect(h.adapter.requests.single.headers['If-None-Match'], isNull);
    expect(h.adapter.requests.single.headers['If-Modified-Since'], isNull);
    await result.file.discard();
  });

  for (final status in [401, 403, 404, 500]) {
    test('$status is typed and never enters protocol recovery', () async {
      final h = await DownloadHarness.create(
        FakeServerAdapter(
          (_, _) => jsonBody('{"error":{"code":"opaque"}}', status),
        ),
      );
      await expectLater(
        h.service.download(h.key),
        throwsA(
          status == 401 || status == 403
              ? isA<UnauthorizedException>()
              : isA<ServerException>()
                    .having((e) => e.statusCode, 'status', status)
                    .having((e) => e.code, 'code', 'opaque'),
        ),
      );
      expect(h.adapter.requests.length, 1);
      expect(await h.parts(), isEmpty);
    });
  }

  test('ambiguous validators cannot escape as a staged generation', () async {
    final h = await DownloadHarness.create(
      FakeServerAdapter(
        (_, _) => fileBody(
          headers: {
            'etag': ['"a"', '"b"'],
          },
        ),
      ),
    );
    await expectLater(
      h.service.download(h.key),
      throwsA(
        isA<DownloadException>().having(
          (e) => e.failure,
          'failure',
          DownloadFailure.invalidValidators,
        ),
      ),
    );
    expect(await h.parts(), isEmpty);
  });
}
