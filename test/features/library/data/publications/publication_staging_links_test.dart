import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/storage/app_directories.dart';
import 'package:shiori/features/library/data/publications/download_exception.dart';
import 'package:shiori/features/library/data/publications/publication_staging.dart';

void main() {
  final storage = throwsA(
    isA<DownloadException>().having(
      (e) => e.failure,
      'failure',
      DownloadFailure.storage,
    ),
  );
  for (final ancestor in ['shiori', 'shiori/v1', 'shiori/v1/staging']) {
    test(
      'refuses linked staging ancestor $ancestor without outside changes',
      () async {
        final root = await Directory.systemTemp.createTemp('staging-link-');
        final caches = await Directory('${root.path}/caches').create();
        final outside = await Directory('${root.path}/outside').create();
        final sentinel = await File('${outside.path}/sentinel.part')
            .writeAsString('keep');
        final link = Link('${caches.path}/$ancestor');
        await link.parent.create(recursive: true);
        await link.create(outside.path);
        addTearDown(() async {
          await link.delete();
          await root.delete(recursive: true);
        });
        final staging = PublicationStaging(_Directories(caches));
        await expectLater(staging.directory(), storage);
        await expectLater(staging.create(), storage);
        await expectLater(staging.cleanupAbandoned(), storage);
        expect(await sentinel.readAsString(), 'keep');
        expect((await outside.list().toList()).length, 1);
      },
    );
  }

  test('open and discard recheck staging ancestors after creation', () async {
    final root = await Directory.systemTemp.createTemp('staging-owned-link-');
    final staging = PublicationStaging(_Directories(root));
    final owned = await staging.create();
    final dir = await staging.directory();
    final saved = await dir.rename('${root.path}/saved');
    final outside = await Directory('${root.path}/outside').create();
    final name = File(owned.path).uri.pathSegments.last;
    final sentinel = await File('${outside.path}/$name').writeAsString('keep');
    final link = await Link(dir.path).create(outside.path);
    addTearDown(() async {
      await link.delete();
      await saved.rename(dir.path);
      await owned.discard();
      await root.delete(recursive: true);
    });
    await expectLater(owned.open(), storage);
    await expectLater(owned.discard(), storage);
    expect(staging.owns(owned), isTrue);
    expect(await sentinel.readAsString(), 'keep');
  });
}

final class _Directories implements AppDirectories {
  _Directories(this.root);
  final Directory root;
  @override
  Future<Directory> caches() async => root;
  @override
  Future<Directory> applicationSupport() => throw StateError('Not cache');
  @override
  Future<Directory> documents() => throw StateError('Not cache');
}
