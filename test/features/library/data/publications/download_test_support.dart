import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/core/config/session_publication_guard.dart';
import 'package:shiori/core/network/session_transport.dart';
import 'package:shiori/core/storage/app_directories.dart';
import 'package:shiori/features/library/data/publications/local_publication.dart';
import 'package:shiori/features/library/data/publications/publication_download_service.dart';
import 'package:shiori/features/library/data/publications/publication_staging.dart';
import 'package:shiori/features/reader/data/epub/epub_archive.dart';

import '../../../../core/network/fake_server_adapter.dart';
import '../library_test_support.dart';

final epubBytes = File('assets/reader_fixtures/one-page.epub')
    .readAsBytesSync();

ResponseBody fileBody({
  int status = 200,
  List<int>? bytes,
  Map<String, List<String>> headers = const {},
  Stream<Uint8List>? stream,
}) => ResponseBody(
  stream ?? Stream.value(Uint8List.fromList(bytes ?? epubBytes)),
  status,
  headers: {
    'content-type': ['application/epub+zip'],
    ...headers,
  },
);

ResponseBody fileFixture(String name, {Stream<Uint8List>? stream}) {
  final manifest = jsonDecode(fixture('manifest.json')) as Map<String, Object?>;
  final entry = (manifest['responses']! as List<Object?>)
      .cast<Map<String, Object?>>()
      .singleWhere((entry) => entry['name'] == name);
  final headers = (entry['headers']! as Map<String, Object?>).map(
    (key, value) => MapEntry(key.toLowerCase(), [value! as String]),
  );
  return fileBody(
    status: entry['status']! as int,
    headers: headers,
    bytes: name == 'file_200_length' ? List.filled(4096, 7) : epubBytes,
    stream: stream,
  );
}

final class TestDirectories implements AppDirectories {
  TestDirectories(this.root);
  final Directory root;
  @override
  Future<Directory> caches() async => root;
  @override
  Future<Directory> applicationSupport() => throw StateError('Caches only');
  @override
  Future<Directory> documents() => throw StateError('Caches only');
}

final class DownloadHarness {
  DownloadHarness._(
    this.root,
    this.adapter, {
    int limit = 1024 * 1024,
    String? failAt,
  }) {
    guard.select(active);
    transport = SessionTransport(active, adapter: adapter);
    staging = PublicationStaging(
      TestDirectories(root),
      openWriter: (file) async {
        final writer = TestWriter(
          await file.open(mode: FileMode.write),
          firstWrite: firstWrite,
          failAt: failAt,
        );
        writers.add(writer);
        return writer;
      },
    );
    service = PublicationDownloadService(
      transport,
      staging,
      guard,
      limits: EpubLimits(maxArchiveBytes: limit),
    );
  }
  static Future<DownloadHarness> create(
    FakeServerAdapter adapter, {
    int limit = 1024 * 1024,
    String? failAt,
  }) async {
    final harness = DownloadHarness._(
      await Directory.systemTemp.createTemp('shiori-download-'),
      adapter,
      limit: limit,
      failAt: failAt,
    );
    addTearDown(() async {
      harness.service.dispose();
      harness.transport.dispose();
      await harness.root.delete(recursive: true);
    });
    return harness;
  }

  final Directory root;
  final FakeServerAdapter adapter;
  final active = session();
  final guard = SessionPublicationGuard();
  final firstWrite = Completer<void>();
  final writers = <TestWriter>[];
  late final SessionTransport transport;
  late final PublicationStaging staging;
  late final PublicationDownloadService service;
  BookKey get key => BookKey(active.serverKey, 7);

  Future<List<FileSystemEntity>> parts() async =>
      (await staging.directory()).list().toList();

  Future<LocalPublication> local({
    String? etag = 'W/"opaque exact"',
    String? modified = 'Thu, 01 Jan 2026 00:00:00 GMT',
  }) async {
    final file = await File('${root.path}/verified.epub')
        .writeAsBytes(epubBytes);
    return LocalPublication(
      key: key,
      path: file.path,
      byteLength: epubBytes.length,
      digest: sha256.convert(epubBytes).toString(),
      etag: etag,
      lastModified: modified,
    );
  }
}

final class TestWriter implements StagingWriter {
  TestWriter(this.file, {required this.firstWrite, this.failAt});
  final RandomAccessFile file;
  final Completer<void> firstWrite;
  final String? failAt;
  int bytes = 0;
  bool flushed = false;
  bool closed = false;
  void fail(String point) {
    if (failAt == point) throw const FileSystemException('injected disk full');
  }

  @override
  Future<void> write(List<int> chunk) async {
    fail('write');
    await file.writeFrom(chunk);
    bytes += chunk.length;
    if (!firstWrite.isCompleted) firstWrite.complete();
  }

  @override
  Future<void> flush() async {
    fail('flush');
    await file.flush();
    flushed = true;
  }

  @override
  Future<void> close() async {
    await file.close();
    closed = true;
    fail('close');
  }
}

final class HeldBody {
  HeldBody() {
    controller = StreamController<Uint8List>(
      onListen: started.complete,
      onCancel: cancelled.complete,
    );
  }
  final started = Completer<void>();
  final cancelled = Completer<void>();
  late final StreamController<Uint8List> controller;
}
