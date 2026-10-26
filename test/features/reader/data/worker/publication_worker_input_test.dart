import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/features/reader/data/epub/epub_archive.dart';
import 'package:shiori/features/reader/data/worker/publication_worker.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_exception.dart';

import '../epub/raw_zip_test_support.dart';
import 'worker_test_support.dart';

void main() {
  late Directory directory;
  setUp(() {
    directory = Directory.systemTemp.createTempSync('shiori-worker-input-');
    addTearDown(() => directory.deleteSync(recursive: true));
  });

  test('corrupt section and resource fail as ParseException without killing worker', () async {
    final original = EpubArchive.open(File(fixturePath).readAsBytesSync());
    final file = File('${directory.path}/bad-section.epub');
    file.writeAsBytesSync(
      rawZip([
        for (final name in original.names)
          RawZipEntry(
            name,
            original.bytes(name)!,
            method: 8,
            crc: name == fixtureSectionPath ? 0 : null,
          ),
      ]),
    );
    final worker = await PublicationWorker.spawn();
    addTearDown(worker.close);
    await worker.open(file.path, tagA);
    await expectLater(worker.loadSection(0), throwsA(isA<ParseException>()));
    await expectLater(
      worker.readResource(fixtureSectionPath),
      throwsA(isA<ParseException>()),
    );
    expect(worker.isClosed, isFalse);
    await worker.open(fixturePath, tagB);
    file.deleteSync();
    expect((await worker.loadSection(0)).nodes, isNotEmpty);
  });

  test(
    'structurally invalid ZIP package fails and releases partial open',
    () async {
      final file = File('${directory.path}/no-package.epub');
      file.writeAsBytesSync(
        rawZip([
          RawZipEntry('mimetype', [1]),
        ]),
      );
      final worker = await PublicationWorker.spawn();
      addTearDown(worker.close);
      await expectLater(
        worker.open(file.path, tagA),
        throwsA(isA<ParseException>()),
      );
      file.deleteSync();
      await expectLater(
        worker.loadSection(0),
        throwsA(workerFailure(PublicationWorkerFailure.notOpen)),
      );
      await worker.open(fixturePath, tagB);
      expect((await worker.loadSection(0)).nodes, isNotEmpty);
    },
  );

  test(
    'present empty resource remains distinct from missing at zero-byte bound',
    () async {
      final original = EpubArchive.open(File(fixturePath).readAsBytesSync());
      final file = File('${directory.path}/empty-resource.epub');
      file.writeAsBytesSync(
        rawZip([
          for (final name in original.names)
            RawZipEntry(name, original.bytes(name)!),
          RawZipEntry('empty', []),
        ]),
      );
      final worker = await PublicationWorker.spawn(maxResourceBytes: 0);
      addTearDown(worker.close);
      await worker.open(file.path, tagA);
      expect(await worker.readResource('empty'), isEmpty);
      expect(await worker.readResource('missing'), isNull);
    },
  );

  test('injected archive limits apply inside the worker', () async {
    final worker = await PublicationWorker.spawn(
      limits: const EpubLimits(maxEntries: 1),
    );
    addTearDown(worker.close);
    await expectLater(
      worker.open(fixturePath, tagA),
      throwsA(isA<ParseException>()),
    );
    expect(worker.isClosed, isFalse);
  });

  test(
    'no publication and invalid section index have typed failures',
    () async {
      final worker = await PublicationWorker.spawn();
      addTearDown(worker.close);
      await expectLater(
        worker.loadSection(0),
        throwsA(workerFailure(PublicationWorkerFailure.notOpen)),
      );
      await expectLater(
        worker.readResource('absent'),
        throwsA(workerFailure(PublicationWorkerFailure.notOpen)),
      );
      await worker.open(fixturePath, tagA);
      await expectLater(worker.loadSection(-1), throwsA(isA<ParseException>()));
      expect((await worker.loadSection(0)).nodes, isNotEmpty);
    },
  );
}
