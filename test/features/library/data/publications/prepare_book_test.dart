import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/content_change.dart';
import 'package:shiori/features/library/data/publications/preparation_state.dart';
import 'package:shiori/features/library/data/publications/prepare_book_exception.dart';
import 'package:shiori/features/library/data/publications/publication_cache_hooks.dart';
import 'package:shiori/features/reader/data/worker/publication_layout_facts.dart';

import 'prepare_test_support.dart';

void main() {
  test(
    '200 reaches ready; 304 retains identity without downloading bytes',
    () async {
      final h = await PrepareHarness.create();
      h.listen();
      expect(h.state, isA<PreparationIdle>());
      await h.controller.prepare();
      final first = (h.state as PreparationReady).book;
      final downloaded = h.downloaded;
      expect(first.publication.firstSection.canonicalLength, greaterThan(0));
      await h.controller.prepare();
      final second = (h.state as PreparationReady).book;
      expect(second.identity, first.identity);
      expect(first.isReleased, isTrue);
      expect(h.downloaded, downloaded);
      final files = h.adapter.requests
          .where((r) => r.uri.path.endsWith('/file'))
          .toList();
      expect(files.length, 2);
      expect(files.last.headers['If-None-Match'], 'W/"first"');
      expect(h.adapter.requests.every((r) => r.method == 'GET'), isTrue);
      await h.clean();
      final allowed = [
        Directory('${h.f.root.path}/support').absolute.uri,
        Directory('${h.f.root.path}/caches').absolute.uri,
      ];
      for (final file in h.f.root.listSync(recursive: true).whereType<File>()) {
        expect(
          allowed.any(
            (root) => file.absolute.uri.toString().startsWith(root.toString()),
          ),
          isTrue,
        );
      }
    },
  );

  test('changed bytes emit identities; old lease stays readable', () async {
    final h = await PrepareHarness.create();
    final changes = <ContentChange>[];
    final sub = h.service.contentChanges.listen(changes.add);
    addTearDown(sub.cancel);
    final old = await h.service.prepare(h.key);
    final oldBytes = await File(old.lease.local.path).readAsBytes();
    h.bytes = importZip(
      importEntries(sources: [sourcePage(body: '<p>Changed</p>')]),
    );
    h.etag = 'W/"changed"';
    final next = await h.service.prepare(h.key);
    expect(next.identity, isNot(old.identity));
    expect(changes.length, 2);
    expect(changes.last.previous, old.identity);
    expect(changes.last.next, next.identity);
    expect(await File(old.lease.local.path).readAsBytes(), oldBytes);
    expect(
      (await h.f.store.readPublicationHead(h.key))!.sha256,
      next.identity.sha256,
    );
    old.release();
    old.release();
    next.release();
    await h.clean();
  });

  test('corrupt EPUB fails typed and preserves previous head', () async {
    final h = await PrepareHarness.create();
    final old = await h.service.prepare(h.key);
    h.bytes = Uint8List.fromList([1, 2, 3, 4]);
    h.etag = 'corrupt';
    await expectLater(
      h.service.prepare(h.key),
      throwsA(prepareFailure(PrepareBookFailure.invalidStructure)),
    );
    expect(
      (await h.f.store.readPublicationHead(h.key))!.sha256,
      old.identity.sha256,
    );
    expect(await File(old.lease.local.path).exists(), isTrue);
    await h.clean();
  });

  test('404 is unavailable without a file GET; retry reaches ready', () async {
    final h = await PrepareHarness.create();
    h.listen();
    h.detailStatus = 404;
    await h.controller.prepare();
    expect(
      (h.state as PreparationFailed).error.failure,
      PrepareBookFailure.unavailable,
    );
    expect(h.adapter.requests.length, 1);
    expect(await h.f.store.readPublicationHead(h.key), isNull);
    h.detailStatus = 200;
    await h.controller.prepare();
    expect(h.state, isA<PreparationReady>());
  });

  test('full cache reports busy while previous head is pinned', () async {
    final size = importZip(importEntries()).length;
    final h = await PrepareHarness.create(limit: size);
    final old = await h.service.prepare(h.key);
    old.release(); // Only the attempt's fallback pin now prevents eviction.
    h.bytes = importZip(
      importEntries(sources: [sourcePage(body: '<p>Replacement</p>')]),
    );
    h.etag = 'replacement';
    await expectLater(
      h.service.prepare(h.key),
      throwsA(prepareFailure(PrepareBookFailure.cacheBusy)),
    );
    expect(
      (await h.f.store.readPublicationHead(h.key))!.sha256,
      old.identity.sha256,
    );
    await h.clean();
    final reservation = await h.f.cache.reserveBytes(size);
    reservation.release(); // Failed attempt released its fallback pin.
    expect(await h.f.store.readPublicationHead(h.key), isNull);
  });

  for (final fixed in [true, false]) {
    test(
      '${fixed ? 'fixed' : 'RTL'} book reaches ready with layout facts',
      () async {
        final h = await PrepareHarness.create();
        h.bytes = importZip(
          importEntries(
            layout: fixed ? 'pre-paginated' : 'reflowable',
            language: fixed ? 'en' : 'ar',
            progression: fixed ? 'ltr' : 'rtl',
            sources: [
              sourcePage(
                body: fixed ? complexFixedBody : '<p dir="rtl">Text</p>',
                head: viewportHead,
              ),
              sourcePage(),
            ],
          ),
        );
        h.listen();
        await h.controller.prepare();
        final facts = (h.state as PreparationReady).book.layoutFacts;
        expect(
          facts.sections.first.mode,
          fixed
              ? PublicationLayoutMode.fixed
              : PublicationLayoutMode.reflowable,
        );
        expect(facts.primaryLanguage, fixed ? 'en' : 'ar');
        expect(facts.pageProgressionDirection, fixed ? 'ltr' : 'rtl');
        expect(facts.sections.last.inspection, SectionInspection.notInspected);
      },
    );
  }

  test('oversized download is typed before staging or publication', () async {
    final h = await PrepareHarness.create(downloadLimit: 16);
    await expectLater(
      h.service.prepare(h.key),
      throwsA(prepareFailure(PrepareBookFailure.tooLarge)),
    );
    expect(await h.f.store.readPublicationHead(h.key), isNull);
    await h.clean();
  });

  test('rename storage failure retains old head and removes staging', () async {
    var fail = false;
    final h = await PrepareHarness.create(
      hooks: PublicationCacheHooks(
        rename: (file, path) async {
          if (fail) throw const FileSystemException('injected');
          await file.rename(path);
        },
      ),
    );
    final old = await h.service.prepare(h.key);
    fail = true;
    h.bytes = importZip(
      importEntries(sources: [sourcePage(body: '<p>New</p>')]),
    );
    await expectLater(
      h.service.prepare(h.key, refresh: true),
      throwsA(prepareFailure(PrepareBookFailure.storage)),
    );
    expect(
      (await h.f.store.readPublicationHead(h.key))!.sha256,
      old.identity.sha256,
    );
    await h.clean();
  });
}
