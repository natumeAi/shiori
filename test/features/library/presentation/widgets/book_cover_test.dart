import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/session_publication_guard.dart';
import 'package:shiori/core/network/session_transport.dart';
import 'package:shiori/features/library/data/models/snapshot_book.dart';
import 'package:shiori/features/library/presentation/covers/cover_loader.dart';
import 'package:shiori/features/library/presentation/covers/session_cover_image.dart';
import 'package:shiori/features/library/presentation/widgets/book_cover.dart';

import '../../../../core/network/fake_server_adapter.dart';
import '../../../../helpers/pump_app.dart';
import '../../data/library_test_support.dart';

void main() {
  final active = session();

  SnapshotBook book({bool small = true}) => SnapshotBook.fromJson(
    records(payload(), 'books').first
      ..['coverUrl'] = '/covers/full.jpg'
      ..['coverThumbnailUrl'] = small ? '/covers/thumbnails/b-384.webp' : null
      ..['coverThumbnail2xUrl'] = '/covers/thumbnails/b-768.webp',
  );

  Future<SessionCoverImage> pumpCover(
    WidgetTester tester,
    SnapshotBook book, {
    required double width,
  }) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);
    final guard = SessionPublicationGuard()..select(active);
    // Only the provider's request is inspected; a 404 settles the load.
    final transport = SessionTransport(
      active,
      adapter: FakeServerAdapter((_, _) => jsonBody('{}', 404)),
    );
    final loader = CoverLoader(transport, guard);
    addTearDown(() {
      guard.retire();
      transport.dispose();
    });
    await tester.pumpApp(
      BookCover(session: active, book: book, width: width),
      overrides: [coverLoaderProvider.overrideWith((ref, _) => loader)],
    );
    await tester.pump(Duration.zero); // Flush Dio's zero-duration dispatch.
    return tester.widget<Image>(find.byType(Image)).image as SessionCoverImage;
  }

  testWidgets('list cover uses the 384 px thumbnail at display width', (
    tester,
  ) async {
    final image = await pumpCover(tester, book(), width: 48);
    expect(image.serverCoverPath, '/covers/thumbnails/b-384.webp');
    expect(image.maxWidth, 144);
  });

  testWidgets('detail cover stays on 384 px while it covers the pixels', (
    tester,
  ) async {
    final image = await pumpCover(tester, book(), width: 120);
    expect(image.serverCoverPath, '/covers/thumbnails/b-384.webp');
    expect(image.maxWidth, 360);
  });

  testWidgets('wider covers use the 768 px thumbnail', (tester) async {
    final image = await pumpCover(tester, book(), width: 200);
    expect(image.serverCoverPath, '/covers/thumbnails/b-768.webp');
    expect(image.maxWidth, 600);
  });

  testWidgets('missing small thumbnail falls back to the 768 px one', (
    tester,
  ) async {
    final image = await pumpCover(tester, book(small: false), width: 48);
    expect(image.serverCoverPath, '/covers/thumbnails/b-768.webp');
    expect(image.maxWidth, 144);
  });
}
