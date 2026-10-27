import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/core/network/session_transport.dart';
import 'package:shiori/features/library/data/publications/preparation_controller.dart';
import 'package:shiori/features/library/data/publications/preparation_state.dart';
import 'package:shiori/features/library/data/publications/prepare_book_exception.dart';
import 'package:shiori/features/library/data/publications/prepare_book_queue.dart';
import 'package:shiori/features/library/data/publications/prepare_book_service.dart';
import 'package:shiori/features/library/data/publications/publication_cache.dart';
import 'package:shiori/features/library/data/publications/publication_cache_hooks.dart';
import 'package:shiori/features/library/data/publications/publication_download_service.dart';
import 'package:shiori/features/library/data/publications/publication_staging.dart';
import 'package:shiori/features/library/data/publications/session_publication_worker.dart';
import 'package:shiori/features/reader/data/epub/epub_archive.dart';
import 'package:shiori/features/reader/data/worker/publication_worker.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_test_hooks.dart';
import 'package:shiori/features/servers/data/server_activation_dependencies.dart';

import '../../../../core/network/fake_server_adapter.dart';
import '../../../reader/data/worker/import_test_support.dart';
import '../library_test_support.dart' show fixture;
import 'cache_test_support.dart';

export '../../../../core/network/fake_server_adapter.dart';
export '../../../reader/data/worker/import_test_support.dart';
export 'cache_test_support.dart' show serverA, serverB;
export 'download_test_support.dart' show fileBody, HeldBody;

TypeMatcher<PrepareBookException> prepareFailure(PrepareBookFailure failure) =>
    isA<PrepareBookException>().having((e) => e.failure, 'failure', failure);

final class PrepareHarness {
  PrepareHarness._(this.f);
  final CacheFixture f;
  late ProviderContainer container;
  late FakeServerAdapter adapter;
  Uint8List bytes = importZip(importEntries());
  String etag = 'W/"first"';
  int detailStatus = 200;
  int fileStatus = 200;
  int downloaded = 0;
  FutureOr<ResponseBody> Function(RequestOptions)? respondFile;
  final transports = <SessionTransport>[];
  final workers = <SessionPublicationWorker>[];

  ServerSession get session => f.session;
  BookKey get key => BookKey(session.serverKey, 7);
  PrepareBookService get service =>
      container.read(prepareBookServiceProvider(session));
  PreparationController get controller =>
      container.read(preparationControllerProvider(session, key).notifier);
  PreparationState get state =>
      container.read(preparationControllerProvider(session, key));

  static Future<PrepareHarness> create({
    int limit = 512 * 1024 * 1024,
    int downloadLimit = 256 * 1024 * 1024,
    PublicationCacheHooks? hooks,
    PublicationWorkerTestHooks? workerHooks,
  }) async {
    final h = PrepareHarness._(
      await CacheFixture.create(limit: limit, hooks: hooks),
    );
    h.adapter = FakeServerAdapter((options, _) async {
      if (!options.uri.path.endsWith('/file')) {
        return jsonBody(fixture('book_detail.json'), h.detailStatus);
      }
      if (h.respondFile != null) return h.respondFile!(options);
      if (h.fileStatus == 304 || options.headers['If-None-Match'] == h.etag) {
        return ResponseBody.fromBytes([], 304);
      }
      h.downloaded += h.bytes.length;
      return ResponseBody(
        Stream.value(h.bytes),
        h.fileStatus,
        headers: {
          'content-type': ['application/epub+zip'],
          'etag': [h.etag],
          'content-length': ['${h.bytes.length}'],
        },
      );
    });
    h.container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        sessionPublicationGuardProvider.overrideWithValue(h.f.guard),
        publicationCacheProvider.overrideWith((ref) async => h.f.cache),
        publicationStagingProvider.overrideWithValue(h.f.staging),
        sessionTransportProvider.overrideWith((ref, session) {
          final transport = SessionTransport(session, adapter: h.adapter);
          h.transports.add(transport);
          ref.onDispose(transport.dispose);
          return transport;
        }),
        sessionPublicationWorkerProvider.overrideWith((ref, session) {
          final owner = workerHooks == null
              ? sessionPublicationWorker(ref, session)
              : SessionPublicationWorker(
                  session,
                  h.f.guard,
                  spawn: () => PublicationWorker.spawn(testHooks: workerHooks),
                );
          h.workers.add(owner);
          ref.onDispose(owner.dispose);
          return owner;
        }),
        publicationDownloadServiceProvider.overrideWith((ref, session) {
          final service = PublicationDownloadService(
            ref.watch(sessionTransportProvider(session)),
            h.f.staging,
            h.f.guard,
            limits: EpubLimits(maxArchiveBytes: downloadLimit),
          );
          ref.onDispose(service.dispose);
          return service;
        }),
      ],
    );
    addTearDown(h.dispose);
    return h;
  }

  void listen() =>
      container.listen(preparationControllerProvider(session, key), (_, _) {});

  Future<void> idle() =>
      container.read(prepareBookQueueProvider).run(() async {});

  Future<void> clean() async {
    await idle();
    expect((await f.staging.directory()).listSync(), isEmpty);
    final stage = await f.staging.create();
    await stage.discard();
  }

  Future<void> dispose() async {
    f.guard.retire();
    await idle();
    container.dispose();
    for (final worker in workers) {
      await worker.closed;
    }
    for (final transport in transports) {
      transport.dispose();
    }
    await f.dispose();
  }
}
