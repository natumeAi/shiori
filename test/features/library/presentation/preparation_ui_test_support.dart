import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/book_key.dart';
import 'package:shiori/core/config/content_identity.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/core/storage/stored_publication.dart';
import 'package:shiori/features/library/data/publications/local_publication.dart';
import 'package:shiori/features/library/data/publications/preparation_controller.dart';
import 'package:shiori/features/library/data/publications/preparation_state.dart';
import 'package:shiori/features/library/data/publications/prepare_book_exception.dart';
import 'package:shiori/features/library/data/publications/prepared_book.dart';
import 'package:shiori/features/library/data/publications/publication_lease.dart';
import 'package:shiori/features/reader/data/epub/epub_package.dart';
import 'package:shiori/features/reader/data/worker/prepared_publication.dart';
import 'package:shiori/features/reader/data/worker/publication_layout_facts.dart';
import 'package:shiori/features/reader/data/worker/publication_snapshot.dart';
import 'package:shiori/features/servers/data/server_activation_dependencies.dart';

import '../../../app/product_ui_test_support.dart';

export '../../../app/product_ui_test_support.dart';

class PreparationUiHarness {
  PreparationUiHarness() {
    app = ProductUiHarness(
      overrides: [
        preparationControllerProvider.overrideWith2((_) {
          final controller = FakePreparationController();
          controllers.add(controller);
          return controller;
        }),
      ],
    );
  }

  late final ProductUiHarness app;
  final controllers = <FakePreparationController>[];
  FakePreparationController get controller => controllers.last;

  Future<void> open(WidgetTester tester, {double scale = 1}) async {
    await app.seed();
    await app.pump(tester, scale: scale);
    await tester.tap(find.text('Fixture Book 7'));
    await tester.pumpAndSettle();
  }
}

/// Controllable states at the D5 seam; production retention and routing run.
class FakePreparationController extends PreparationController {
  final refreshes = <bool>[];
  int cancellations = 0;
  bool disposed = false;
  PreparedBook? owned;
  bool attached = true;
  late BookKey capturedKey;
  late ServerSession capturedSession;

  @override
  PreparationState build(ServerSession session, BookKey key) {
    capturedKey = key;
    capturedSession = session;
    ref.onDispose(() {
      disposed = true;
      owned?.release();
    });
    return const PreparationState.idle();
  }

  @override
  Future<void> prepare({bool refresh = false}) async {
    refreshes.add(refresh);
    owned?.release();
    owned = null;
    state = const PreparationState.preparing();
  }

  void progress(int received, int? total) {
    state = PreparationState.preparing(
      receivedBytes: received,
      totalBytes: total,
    );
  }

  void fail(PrepareBookFailure failure) {
    state = PreparationState.failed(PrepareBookException(failure));
  }

  PreparedBook complete() {
    final book = preparedBook(capturedKey);
    if (ref.mounted &&
        ref.read(sessionPublicationGuardProvider).isCurrent(capturedSession)) {
      owned = book;
      if (attached) {
        state = PreparationState.ready(book);
      } else {
        book.release();
        owned = null;
        state = PreparationState.detached(book.publication);
      }
    } else {
      book.release();
    }
    return book;
  }

  @override
  void detachRoute() {
    attached = false;
    if (state case PreparationReady(:final book)) {
      book.release();
      owned = null;
      state = PreparationState.detached(book.publication);
    }
  }

  @override
  Future<void> attachRoute() async {
    attached = true;
    if (state is PreparationDetached) complete();
  }

  @override
  void cancel() {
    cancellations++;
    owned?.release();
    owned = null;
    state = const PreparationState.idle();
  }
}

PreparedBook preparedBook(BookKey key) {
  final identity = ContentIdentity(key, 'a' * 64);
  return PreparedBook(
    PreparedPublication(
      identity: identity,
      snapshot: PublicationSnapshot(
        EpubPackage(
          opfPath: 'package.opf',
          manifest: const [],
          spine: const [],
          toc: null,
          direction: null,
          rendition: const {},
          navPath: null,
          ncxPath: null,
        ),
      ),
      metadata: PublicationMetadata(
        titles: ['Synthetic'],
        creators: [],
        languages: [],
        identifiers: [],
      ),
      layoutFacts: PublicationLayoutFacts(
        pageProgressionDirection: 'rtl',
        primaryLanguage: 'ja',
        packageRendition: {'layout': 'pre-paginated'},
        sections: [],
      ),
      firstSection: FirstSectionReadiness(
        sectionIndex: 0,
        href: 'section.xhtml',
        cfiBase: 'epubcfi(/6/2)',
        parserUsed: 'xml',
        parserErrorClass: null,
        canonicalVersion: 1,
        canonicalLength: 1,
        canonicalSignature: 'synthetic',
        resources: [],
      ),
    ),
    PublicationLease(
      StoredPublication(
        key: key,
        sha256: identity.sha256,
        byteLength: 1,
        parserVersion: 1,
        canonicalVersion: 1,
        accessedAt: DateTime.utc(2026),
      ),
      LocalPublication(
        key: key,
        path: 'synthetic-not-opened',
        byteLength: 1,
        digest: identity.sha256,
      ),
      () {},
    ),
    () {},
  );
}
