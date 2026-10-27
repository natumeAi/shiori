import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/core/config/server_endpoint.dart';
import 'package:shiori/core/config/server_key.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/core/network/request_cancelled.dart';
import 'package:shiori/core/network/session_transport.dart';
import 'package:shiori/features/library/data/publications/download_exception.dart';
import 'package:shiori/features/library/data/publications/download_result.dart';
import 'package:shiori/features/library/data/publications/publication_download_service.dart';
import 'package:shiori/features/library/data/publications/publication_staging.dart';
import 'package:shiori/features/servers/data/server_activation_dependencies.dart';

import '../../../../core/network/fake_server_adapter.dart';
import 'download_test_support.dart';

void main() {
  test(
    'ordinary duplicate work coalesces onto one attempt and result',
    () async {
      final held = HeldBody();
      final h = await DownloadHarness.create(
        FakeServerAdapter((_, _) => fileBody(stream: held.controller.stream)),
      );
      final first = h.service.download(h.key);
      await held.started.future;
      final second = h.service.download(BookKey(h.key.serverKey, 7));
      expect(second, same(first));
      held.controller.add(epubBytes);
      await held.controller.close();
      final result = await first as StagedDownload;
      expect(await second, same(result));
      expect(h.adapter.requests.length, 1);
      expect((await h.parts()).length, 1);
      await result.file.discard();
    },
  );

  test('refresh cancels an older transfer, waits for cleanup and owns the new result', () async {
    final held = HeldBody();
    final h = await DownloadHarness.create(
      FakeServerAdapter(
        (_, index) =>
            index == 0 ? fileBody(stream: held.controller.stream) : fileBody(),
      ),
    );
    final local = await h.local();
    final old = h.service.download(h.key, local: local);
    final rejected = expectLater(old, throwsA(isA<RequestCancelled>()));
    await held.started.future;
    held.controller.add(Uint8List(32));
    await h.firstWrite.future;
    final oldPath = (await h.parts()).single.path;
    final fresh = h.service.download(h.key, local: local, refresh: true);
    expect(h.service.download(h.key), same(fresh));
    final result = await fresh as StagedDownload;
    await rejected;
    await held.cancelled.future;
    expect(await File(oldPath).exists(), isFalse);
    expect((await h.parts()).length, 1);
    expect(h.adapter.requests.length, 2);
    expect(h.adapter.requests.last.headers['If-None-Match'], isNull);
    expect(h.adapter.requests.last.headers['If-Modified-Since'], isNull);
    expect(await File(local.path).readAsBytes(), epubBytes);
    await result.file.discard();
  });

  for (final retire in [true, false]) {
    test(
      '${retire ? 'session retirement' : 'transport disposal'} mid-body cancels and deletes staging',
      () async {
        final held = HeldBody();
        final h = await DownloadHarness.create(
          FakeServerAdapter((_, _) => fileBody(stream: held.controller.stream)),
        );
        final future = h.service.download(h.key);
        final rejected = expectLater(future, throwsA(isA<RequestCancelled>()));
        await held.started.future;
        held.controller.add(Uint8List(32));
        await h.firstWrite.future;
        if (retire) {
          h.guard.retire();
        } else {
          h.transport.dispose();
        }
        await rejected;
        await held.cancelled.future;
        expect(await h.parts(), isEmpty);
      },
    );
  }

  test(
    'retirement before headers rejects promptly and cancels a late raw source',
    () async {
      final response = Completer<ResponseBody>();
      final requested = Completer<void>();
      final sourceCancelled = Completer<void>();
      final source = StreamController<Uint8List>(
        onCancel: sourceCancelled.complete,
      );
      final h = await DownloadHarness.create(
        FakeServerAdapter((_, _) {
          requested.complete();
          return response.future;
        }),
      );
      final rejected = expectLater(
        h.service.download(h.key),
        throwsA(isA<RequestCancelled>()),
      );
      await requested.future;
      h.guard.retire();
      await rejected;
      response.complete(fileBody(stream: source.stream));
      await sourceCancelled.future;
      expect(await h.parts(), isEmpty);
    },
  );

  test('different books serialize; a retained staged result reserves the only slot', () async {
    final held = HeldBody();
    final h = await DownloadHarness.create(
      FakeServerAdapter(
        (_, index) =>
            index == 0 ? fileBody(stream: held.controller.stream) : fileBody(),
      ),
    );
    final first = h.service.download(h.key);
    await held.started.future;
    final other = BookKey(h.key.serverKey, 8);
    final queued = h.service.download(other);
    final rejected = expectLater(
      queued,
      throwsA(
        isA<DownloadException>().having(
          (e) => e.failure,
          'failure',
          DownloadFailure.stagingBusy,
        ),
      ),
    );
    expect(h.adapter.requests.length, 1);
    held.controller.add(epubBytes);
    await held.controller.close();
    final result = await first as StagedDownload;
    await rejected;
    expect((await h.parts()).length, 1);
    await result.file.discard();
    final next = await h.service.download(other) as StagedDownload;
    await next.file.discard();
  });

  test('server/book mismatch rejects before making a request', () async {
    final h = await DownloadHarness.create(
      FakeServerAdapter((_, _) => fileBody()),
    );
    final foreign = BookKey(
      ServerKey(ServerEndpoint.parse('https://other.test/').endpoint!),
      7,
    );
    expect(() => h.service.download(foreign), throwsArgumentError);
    final local = await h.local();
    expect(
      () => h.service.download(BookKey(h.key.serverKey, 8), local: local),
      throwsArgumentError,
    );
    expect(h.adapter.requests, isEmpty);
  });

  test(
    'generated session provider shares staging and cancels on disposal',
    () async {
      final held = HeldBody();
      final h = await DownloadHarness.create(
        FakeServerAdapter((_, _) => fileBody(stream: held.controller.stream)),
      );
      final container = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [
          sessionTransportProvider(h.active).overrideWithValue(h.transport),
          publicationStagingProvider.overrideWithValue(h.staging),
          sessionPublicationGuardProvider.overrideWithValue(h.guard),
        ],
      );
      final service = container.read(
        publicationDownloadServiceProvider(h.active),
      );
      expect(service.staging, same(h.staging));
      final rejected = expectLater(
        service.download(h.key),
        throwsA(isA<RequestCancelled>()),
      );
      await held.started.future;
      held.controller.add(Uint8List(32));
      await h.firstWrite.future;
      container.dispose();
      await rejected;
      expect(await h.parts(), isEmpty);
    },
  );

  test(
    'startup cleanup touches only abandoned regular .part files in staging',
    () async {
      final h = await DownloadHarness.create(
        FakeServerAdapter((_, _) => fileBody()),
      );
      final dir = await h.staging.directory();
      final abandoned = await File('${dir.path}/abandoned.part')
          .writeAsString('partial');
      final retained = await File('${dir.path}/keep.epub')
          .writeAsString('keep');
      final external = await File('${h.root.path}/outside.part')
          .writeAsString('keep');
      final nested = await Directory('${dir.path}/nested.part').create();
      final nestedFile = await File('${nested.path}/inside.part')
          .writeAsString('keep');
      final result = await h.service.download(h.key) as StagedDownload;
      await h.staging.cleanupAbandoned();
      expect(await abandoned.exists(), isFalse);
      expect(await retained.readAsString(), 'keep');
      expect(await external.readAsString(), 'keep');
      expect(await nestedFile.readAsString(), 'keep');
      expect(await File(result.path).readAsBytes(), epubBytes);
      await result.file.discard();
      // A fresh owner treats a previous process's staged .part as abandoned.
      final restarted = PublicationStaging(TestDirectories(h.root));
      final orphan = await File('${dir.path}/restart.part')
          .writeAsString('partial');
      await restarted.cleanupAbandoned();
      expect(await orphan.exists(), isFalse);
      expect(await retained.exists(), isTrue);
    },
  );
  test('reactivated A waits for retired A close/cleanup and rejects its late result', () async {
    final h = await DownloadHarness.create(
      FakeServerAdapter((_, _) => fileBody()),
    );
    final closing = Completer<void>();
    final release = Completer<void>();
    final staging = PublicationStaging(
      TestDirectories(h.root),
      openWriter: (file) async => CloseGateWriter(
        await file.open(mode: FileMode.write),
        closing,
        release,
      ),
    );
    final old = PublicationDownloadService(h.transport, staging, h.guard);
    addTearDown(old.dispose);
    final rejected = expectLater(
      old.download(h.key),
      throwsA(isA<RequestCancelled>()),
    );
    await closing.future;
    final oldPath = (await h.parts()).single.path;
    h.guard.retire();
    final active = ServerSession(endpoint: h.active.endpoint, generation: 2);
    h.guard.select(active);
    final adapter = FakeServerAdapter((_, _) => fileBody());
    final transport = SessionTransport(active, adapter: adapter);
    addTearDown(transport.dispose);
    final next = PublicationDownloadService(transport, staging, h.guard);
    addTearDown(next.dispose);
    final fresh = next.download(h.key);
    expect(adapter.requests, isEmpty);
    release.complete();
    await rejected;
    final result = await fresh as StagedDownload;
    expect(await File(oldPath).exists(), isFalse);
    expect((await h.parts()).length, 1);
    await result.file.discard();
  });
}

final class CloseGateWriter implements StagingWriter {
  CloseGateWriter(this.file, this.closing, this.release);
  final RandomAccessFile file;
  final Completer<void> closing;
  final Completer<void> release;
  @override
  Future<void> write(List<int> bytes) async {
    await file.writeFrom(bytes);
  }

  @override
  Future<void> flush() async {
    await file.flush();
  }

  @override
  Future<void> close() async {
    if (!closing.isCompleted) closing.complete();
    await release.future;
    await file.close();
  }
}
