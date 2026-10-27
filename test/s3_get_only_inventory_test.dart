import 'dart:async';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/core/config/session_publication_guard.dart';
import 'package:shiori/core/network/server_route.dart';
import 'package:shiori/core/network/session_transport.dart';
import 'package:shiori/features/library/data/book_repository.dart';
import 'package:shiori/features/library/data/library_snapshot_repository.dart';
import 'package:shiori/features/library/data/library_snapshot_validator.dart';
import 'package:shiori/features/library/data/publications/download_result.dart';
import 'package:shiori/features/library/data/publications/publication_download_service.dart';
import 'package:shiori/features/library/data/publications/publication_staging.dart';
import 'package:shiori/features/library/presentation/covers/cover_loader.dart';
import 'package:shiori/features/library/presentation/covers/session_cover_image.dart';
import 'package:shiori/features/servers/data/health_repository.dart';
import 'package:shiori/features/servers/data/server_activation_dependencies.dart';

import 'core/network/fake_server_adapter.dart';
import 'features/library/data/library_test_support.dart';
import 'features/library/data/snapshot_cache_test_support.dart';
import 'features/library/data/publications/download_test_support.dart';
import 'features/library/presentation/covers/cover_test_support.dart';

const readTemplates = {
  'api/health',
  'api/library/snapshot',
  'api/books/{id}',
  'api/books/{id}/file',
  'covers/{resource}',
};

List<String> forbiddenWrites(String source) {
  if (!source.contains('package:dio/dio.dart')) return [];
  final calls = RegExp(
    r'\.\s*(?:post|put|patch|delete|head|options|request|download)(?:Uri)?\s*(?:<[^;()]*>)?\s*\(',
  );
  final methods = RegExp(r'\bmethod\s*[:=]\s*([^,\n;)]+)');
  return [
    for (final match in calls.allMatches(source)) match.group(0)!,
    for (final match in methods.allMatches(source))
      if (!const {"'GET'", '"GET"'}.contains(match.group(1)!.trim()))
        match.group(0)!,
  ];
}

bool constructsDio(String source) => RegExp(r'\bDio\s*\(').hasMatch(source);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('transport route allowlist is exactly the five S3 reads', () {
    expect(
      ServerRoute.values
          .where((r) => r != ServerRoute.unknown)
          .map((r) => r.template)
          .toSet(),
      readTemplates,
    );
    final routes = {
      ['api', 'health']: ServerRoute.health,
      ['api', 'library', 'snapshot']: ServerRoute.snapshot,
      ['api', 'books', '7']: ServerRoute.book,
      ['api', 'books', '7', 'file']: ServerRoute.file,
    };
    for (final entry in routes.entries) {
      expect(ServerRoute.api(entry.key), entry.value);
    }
    for (final segments in [
      ['api', 'books'],
      ['api', 'books', 'catalog'],
      ['api', 'folders'],
      ['api', 'reading'],
      ['api', 'goals'],
      ['api', 'statistics'],
      ['api', 'books', '7', 'position'],
      ['api', 'books', '7', 'activity'],
      ['api', 'books', '7', 'delete'],
      ['api', 'shelf', 'reorder'],
    ]) {
      expect(() => ServerRoute.api(segments), throwsArgumentError);
    }
  });

  test('all repositories, detail provider and image loader issue only the S3 GET set', () async {
    final bytes = await png();
    final active = session();
    final guard = SessionPublicationGuard()..select(active);
    final adapter = FakeServerAdapter((options, _) {
      final path = options.uri.path.substring('/Reader/'.length);
      if (path == 'api/health') return jsonBody(fixture('health_ok.json'));
      if (path == 'api/library/snapshot') {
        return responseFixture('snapshot_200');
      }
      if (path == 'api/books/7') return jsonBody(fixture('book_detail.json'));
      if (path == 'api/books/7/file') return fileFixture('file_200_chunked');
      if (path.startsWith('covers/')) return imageBody(bytes);
      throw StateError('Uninventoried request');
    });
    final transport = SessionTransport(active, adapter: adapter);
    addTearDown(transport.dispose);
    final cache = MemorySnapshotCache();
    final stagingRoot = await Directory.systemTemp.createTemp(
      'shiori-inventory-',
    );
    addTearDown(() => stagingRoot.delete(recursive: true));
    final repository = LibrarySnapshotRepository(transport, cache, guard);
    addTearDown(repository.dispose);
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        sessionPublicationGuardProvider.overrideWithValue(guard),
        sessionTransportProvider(active).overrideWithValue(transport),
        publicationStagingProvider.overrideWithValue(
          PublicationStaging(TestDirectories(stagingRoot)),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(guard.retire);
    await HealthRepository(transport).validate();
    await const LibrarySnapshotValidator().validate(transport);
    await repository.load();
    final key = BookKey(active.serverKey, 7);
    await container.read(bookRepositoryProvider(active)).fetchBook(key);
    final detail = bookDetailProvider(active, key);
    container.listen(detail, (_, _) {});
    await container.read(detail.future);
    final downloaded =
        await container
                .read(publicationDownloadServiceProvider(active))
                .download(key)
            as StagedDownload;
    await downloaded.file.discard();
    final loader = container.read(coverLoaderProvider(active));
    release(await loader.load('/covers/direct.png'));
    final stream = SessionCoverImage(
      loader,
      '/covers/provider.png',
    ).resolve(ImageConfiguration.empty);
    final ready = Completer<ImageInfo>();
    final listener = ImageStreamListener(
      (info, _) => ready.complete(info),
      onError: ready.completeError,
    );
    stream.addListener(listener);
    (await ready.future).dispose();
    stream.removeListener(listener);
    final observed = <String>{};
    for (final request in adapter.requests) {
      expect(request.method, 'GET');
      final path = request.uri.path.substring('/Reader/'.length);
      expect(path, isNot(anyOf('api/books', 'api/books/catalog')));
      expect(
        RegExp(r'^api/(folders|reading|goals|statistics)(/|$)').hasMatch(path),
        isFalse,
      );
      if (path.startsWith('covers/')) {
        observed.add('covers/{resource}');
      } else {
        observed.add(ServerRoute.api(path.split('/')).template);
      }
    }
    expect(observed, readTemplates);
    expect(adapter.requests.length, 8);
  });

  test('lib contains no Dio writes or non-GET request options; all call owners are driven above', () {
    final owners = <String>{};
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))) {
      final source = file.readAsStringSync();
      final path = file.path.replaceAll(r'\', '/');
      if (path != 'lib/core/network/session_transport.dart') {
        expect(constructsDio(source), isFalse, reason: file.path);
      }
      expect(forbiddenWrites(source), isEmpty, reason: file.path);
      expect(
        RegExp(r'Image\.network\s*\(').hasMatch(source),
        isFalse,
        reason: file.path,
      );
      if (source.contains(
            'package:shiori/core/network/session_transport.dart',
          ) &&
          RegExp(r'\.get(?:Json|Bytes|File)(?:<[^;()]*>)?\s*\(')
              .hasMatch(source)) {
        owners.add(file.path.replaceAll(r'\', '/'));
      }
    }
    expect(owners, {
      'lib/features/servers/data/health_repository.dart',
      'lib/features/library/data/library_snapshot_validator.dart',
      'lib/features/library/data/library_snapshot_repository.dart',
      'lib/features/library/data/book_repository.dart',
      'lib/features/library/data/publications/publication_download_service.dart',
      'lib/features/library/presentation/covers/cover_loader.dart',
    });
  });

  test('static inventory detects writes, aliases, generic requests and dynamic options', () {
    for (final constructor in [
      'Dio()',
      'net.Dio(BaseOptions())',
      'new Dio ()',
    ]) {
      expect(constructsDio(constructor), isTrue);
    }
    for (final call in [
      'client.post("x")',
      'client.putUri<void>(uri)',
      'client.patch("x")',
      'client.delete("x")',
      'client.head("x")',
      'client.options("x")',
      'client.request("x")',
      'Options(method: "POST")',
      'Options(method: verb)',
      'client.options.method = "DELETE";',
    ]) {
      expect(
        forbiddenWrites("import 'package:dio/dio.dart' as net; $call"),
        isNotEmpty,
      );
    }
    expect(
      forbiddenWrites("import 'package:dio/dio.dart'; Options(method: 'GET')"),
      isEmpty,
    );
  });
}
