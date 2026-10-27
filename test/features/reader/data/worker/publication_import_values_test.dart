import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/core/config/content_change.dart';
import 'package:shiori/core/config/content_identity.dart';
import 'package:shiori/core/config/server_endpoint.dart';
import 'package:shiori/core/config/server_key.dart';
import 'package:shiori/features/reader/data/canonical/canonical_text.dart';
import 'package:shiori/features/reader/data/worker/publication_worker.dart';
import 'package:shiori/features/reader/data/worker/publication_worker_exception.dart';

import 'import_test_support.dart';
import 'worker_test_support.dart';

void main() {
  test('content identity equality covers book, bytes and both interpretation versions', () {
    final digest = 'ab' * 32;
    final first = ContentIdentity(importBookKey, digest);
    final same = ContentIdentity(importBookKey, digest.toUpperCase());
    expect(first, same);
    expect(first.hashCode, same.hashCode);
    expect(first.isCurrent, isTrue);
    expect(publicationCanonicalVersion, canonicalTextVersion);
    expect(first, isNot(ContentIdentity(importBookKey, 'cd' * 32)));
    expect(
      first,
      isNot(ContentIdentity(BookKey(importBookKey.serverKey, 8), digest)),
    );
    expect(
      first,
      isNot(
        ContentIdentity(
          BookKey(
            ServerKey(
              ServerEndpoint.parse('https://other.invalid/library').endpoint!,
            ),
            7,
          ),
          digest,
        ),
      ),
    );
    expect(
      first,
      isNot(ContentIdentity(importBookKey, digest, parserVersion: 2)),
    );
    expect(
      first,
      isNot(ContentIdentity(importBookKey, digest, canonicalVersion: 2)),
    );
    expect(ContentChange(next: first).previous, isNull);
    final change = ContentChange(previous: first, next: same);
    expect(change, ContentChange(previous: first, next: same));
    expect(change.next, same);
    expect(
      () => ContentChange(
        previous: first,
        next: ContentIdentity(BookKey(importBookKey.serverKey, 8), digest),
      ),
      throwsArgumentError,
    );
    for (final invalid in ['', 'a' * 63, 'z' * 64, 'a' * 65]) {
      expect(
        () => ContentIdentity(importBookKey, invalid),
        throwsArgumentError,
      );
    }
    expect(
      () => ContentIdentity(importBookKey, digest, parserVersion: 0),
      throwsArgumentError,
    );
    expect(
      () => ContentIdentity(importBookKey, digest, canonicalVersion: -1),
      throwsArgumentError,
    );
  });

  test(
    'incompatible versions fail before replacing the current publication',
    () async {
      final worker = await PublicationWorker.spawn();
      addTearDown(worker.close);
      await worker.open(fixturePath, tagA);
      await expectLater(
        worker.prepare(
          'never-read',
          ContentIdentity(importBookKey, 'ab' * 32, parserVersion: 2),
        ),
        throwsA(workerFailure(PublicationWorkerFailure.incompatibleIdentity)),
      );
      expect((await worker.loadSection(0)).nodes, isNotEmpty);
    },
  );

  test('first linear source skips nonlinear entries and preserves original spine/CFI slots', () async {
    final directory = Directory.systemTemp.createTempSync(
      'shiori-import-linear-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = writeImport(
      directory,
      importEntries(
        sources: [
          sourcePage(),
          sourcePage(body: simpleFixedBody, head: viewportHead),
          sourcePage(),
        ],
        linear: [false, true, true],
        properties: [
          '',
          'rendition:layout-pre-paginated rendition:page-spread-center',
          '',
        ],
      ),
    );
    final worker = await PublicationWorker.spawn();
    addTearDown(worker.close);
    final result = await worker.prepare(file.path, identityFor(file));
    expect(result.firstSection.sectionIndex, 1);
    expect(result.firstSection.cfiBase, 'epubcfi(/6/4[ref1])');
    expect(result.layoutFacts.sections[0].style, isNull);
    expect(result.layoutFacts.sections[1].style, isNotNull);
    expect(result.layoutFacts.sections[1].rendition['pageSpread'], 'center');
    expect(result.layoutFacts.sections[2].style, isNull);
    expect(() => result.metadata.languages.clear(), throwsUnsupportedError);
    expect(() => result.snapshot.sections.clear(), throwsUnsupportedError);
    expect(
      () => result.snapshot.package.rendition.clear(),
      throwsUnsupportedError,
    );
    expect(() => result.layoutFacts.sections.clear(), throwsUnsupportedError);
    expect(
      () => result.layoutFacts.packageRendition.clear(),
      throwsUnsupportedError,
    );
    expect(
      () => result.layoutFacts.sections[1].rendition.clear(),
      throwsUnsupportedError,
    );
    expect(
      () => result.layoutFacts.sections[1].itemrefProperties.clear(),
      throwsUnsupportedError,
    );
    expect(
      () => result.layoutFacts.sections[1].style!.writingModes.clear(),
      throwsUnsupportedError,
    );
    expect(
      () => result.layoutFacts.sections[1].source!.viewports.clear(),
      throwsUnsupportedError,
    );
    expect(() => result.firstSection.resources.clear(), throwsUnsupportedError);
    await worker.close();
    file.deleteSync();
    expect(result.metadata.titles, ['Generated import']);
    expect(result.firstSection.canonicalLength, 0);
  });
}
