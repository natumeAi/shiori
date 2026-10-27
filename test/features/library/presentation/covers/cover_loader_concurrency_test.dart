import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/session_publication_guard.dart';
import 'package:shiori/core/network/session_transport.dart';
import 'package:shiori/features/library/presentation/covers/cover_failure.dart';
import 'package:shiori/features/library/presentation/covers/cover_load_result.dart';
import 'package:shiori/features/library/presentation/covers/cover_loader.dart';
import 'package:shiori/features/library/presentation/covers/session_cover_image.dart';

import '../../../../core/network/fake_server_adapter.dart';
import '../../data/library_test_support.dart';
import 'cover_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('different paths share reservations, evict in LRU order and respect pinned leases', () async {
    final active = session();
    final guard = SessionPublicationGuard()..select(active);
    final bytes = await png();
    final adapter = FakeServerAdapter((_, _) => imageBody(bytes));
    final transport = SessionTransport(active, adapter: adapter);
    final aGate = CoverDecodeGate();
    final bGate = CoverDecodeGate();
    var decodes = 0;
    final loader = CoverLoader(
      transport,
      guard,
      encodedBudget: bytes.length * 2,
      decodedBudget: 12,
      decodeFrame: (codec) => switch (decodes++) {
        1 => aGate.decode(codec),
        2 => bGate.decode(codec),
        _ => codec.getNextFrame(),
      },
    );
    addTearDown(() {
      aGate.complete();
      bGate.complete();
      loader.dispose();
      transport.dispose();
      guard.retire();
    });
    void bounded() {
      expect(loader.encodedBytes, lessThanOrEqualTo(bytes.length * 2));
      expect(loader.decodedBytes + loader.reservedBytes, lessThanOrEqualTo(12));
    }

    final pinned = await loader.load('/covers/p') as CoverLoaded;
    final aPending = loader.load('/covers/a');
    await aGate.entered.future;
    expect(loader.reservedBytes, 4);
    final bPending = loader.load('/covers/b');
    await bGate.entered.future;
    expect(loader.reservedBytes, 8);
    expect(loader.decodedBytes, 4);
    bounded();
    expect(await loader.load('/covers/c'), placeholder(CoverFailure.cacheBusy));
    expect(loader.reservedBytes, 8);
    expect(loader.encodedCount, 1);

    bGate.complete();
    final b = await bPending as CoverLoaded;
    expect(loader.reservedBytes, 4);
    bounded();
    aGate.complete();
    final a = await aPending as CoverLoaded;
    expect(loader.reservedBytes, 0);
    expect(loader.decodedBytes, 12);
    expect(loader.encodedBytes, bytes.length * 2);
    expect(loader.encodedCount, 2);
    bounded();
    expect(await loader.load('/covers/c'), placeholder(CoverFailure.cacheBusy));
    expect(pinned.lease.image.debugDisposed, isFalse);
    expect(b.lease.image.debugDisposed, isFalse);

    // The oldest two entries are pinned; only a can make room for c.
    release(a);
    final c = await loader.load('/covers/c') as CoverLoaded;
    expect(a.lease.image.debugDisposed, isTrue);
    expect(pinned.lease.image.debugDisposed, isFalse);
    expect(b.lease.image.debugDisposed, isFalse);
    bounded();
    final beforeHits = adapter.requests.length;
    final bHit = await loader.load('/covers/b') as CoverLoaded;
    expect(bHit.lease.image, same(b.lease.image));
    release(bHit);
    release(pinned);
    release(b);
    release(c);

    // a's encoded bytes survived c; p's bytes were evicted when a completed.
    release(await loader.load('/covers/a'));
    expect(adapter.requests, hasLength(beforeHits));
    expect(pinned.lease.image.debugDisposed, isTrue);
    expect(c.lease.image.debugDisposed, isFalse);
    release(await loader.load('/covers/p'));
    expect(adapter.requests.map((r) => r.uri.path.split('/').last), [
      'p',
      'a',
      'b',
      'c',
      'c',
      'c',
      'p',
    ]);
    expect(c.lease.image.debugDisposed, isTrue);
    expect(b.lease.image.debugDisposed, isFalse);
    expect(loader.reservedBytes, 0);
    bounded();
  });

  for (final retire in [true, false]) {
    test(
      '${retire ? 'retirement' : 'disposal'} during native decode drops late frames silently across 30 cycles',
      () async {
        final guard = SessionPublicationGuard();
        addTearDown(guard.retire);
        final bytes = await png();
        final endpoint = session().endpoint;
        final retiredLoaders = <CoverLoader>[];
        final nativeImages = <ui.Image>[];
        for (var cycle = 0; cycle < 30; cycle++) {
          final active = guard.createSession(endpoint);
          guard.select(active);
          final transport = SessionTransport(
            active,
            adapter: FakeServerAdapter((_, _) => imageBody(bytes)),
          );
          final gate = CoverDecodeGate();
          var decodes = 0;
          final loader = CoverLoader(
            transport,
            guard,
            decodedBudget: 8,
            encodedBudget: bytes.length,
            decodeFrame: (codec) =>
                decodes++ == 0 ? codec.getNextFrame() : gate.decode(codec),
          );
          addTearDown(() {
            gate.complete();
            loader.dispose();
            transport.dispose();
          });
          final held = await loader.load('/covers/pinned') as CoverLoaded;
          var images = 0;
          var errors = 0;
          final stream = SessionCoverImage(
            loader,
            '/covers/late',
          ).resolve(ImageConfiguration.empty);
          final listener = ImageStreamListener((info, _) {
            images++;
            info.dispose();
          }, onError: (_, _) => errors++);
          stream.addListener(listener);
          final waiting = loader.load('/covers/late');
          final nativeImage = await gate.entered.future;
          nativeImages.add(nativeImage);
          expect(loader.decodedBytes, 4);
          expect(loader.reservedBytes, 4);
          expect(nativeImage.debugDisposed, isFalse);

          if (retire) {
            guard.retire();
          } else {
            loader.dispose();
          }
          expect(await waiting, placeholder(CoverFailure.cancelled));
          expect(loader.decodedBytes, 0);
          expect(loader.encodedBytes, 0);
          expect(loader.decodedCount, 0);
          expect(loader.encodedCount, 0);
          expect(held.lease.image.debugDisposed, isTrue);
          held.lease.release();
          held.lease.release();
          guard.retire();

          // A later activation can admit the same path before the old frame returns.
          final successor = guard.createSession(endpoint);
          guard.select(successor);
          final nextTransport = SessionTransport(
            successor,
            adapter: FakeServerAdapter((_, _) => imageBody(bytes)),
          );
          final next = CoverLoader(nextTransport, guard, decodedBudget: 4);
          addTearDown(() {
            next.dispose();
            nextTransport.dispose();
          });
          final nextImage = await next.load('/covers/late') as CoverLoaded;
          gate.complete();
          await drainCoverDecode(() => loader.reservedBytes == 0);
          expect(nativeImage.debugDisposed, isTrue);
          expect(images, 0);
          expect(errors, 0);
          stream.removeListener(listener);
          expect(loader.decodedCount, 0);
          expect(loader.encodedCount, 0);
          expect(next.decodedBytes, 4);
          expect(nextImage.lease.image.debugDisposed, isFalse);
          release(nextImage);
          guard.retire();
          retiredLoaders.add(loader);
        }
        expect(retiredLoaders, hasLength(30));
        expect(
          retiredLoaders.every(
            (l) =>
                l.reservedBytes == 0 &&
                l.decodedBytes == 0 &&
                l.encodedBytes == 0,
          ),
          isTrue,
        );
        expect(nativeImages.every((image) => image.debugDisposed), isTrue);
      },
    );
  }
}
