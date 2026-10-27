import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/library/presentation/covers/cover_failure.dart';
import 'package:shiori/features/library/presentation/covers/cover_load_result.dart';

Future<Uint8List> png({
  int width = 1,
  int height = 1,
  int? paddedLength,
}) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(const ui.Color(0xffffffff), ui.BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  try {
    final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    if (paddedLength == null) return bytes;
    return Uint8List(paddedLength)..setAll(0, bytes);
  } finally {
    image.dispose();
    picture.dispose();
  }
}

ResponseBody imageBody(Uint8List bytes) => ResponseBody.fromBytes(
  bytes,
  200,
  headers: {
    'content-type': ['image/png'],
  },
);

Matcher placeholder(CoverFailure reason) =>
    isA<CoverPlaceholder>().having((result) => result.reason, 'reason', reason);

void release(CoverLoadResult result) => (result as CoverLoaded).lease.release();

/// Holds a real native frame before handing it back to the loader.
final class CoverDecodeGate {
  final entered = Completer<ui.Image>();
  final resume = Completer<void>();

  Future<ui.FrameInfo> decode(ui.Codec codec) async {
    final frame = await codec.getNextFrame();
    entered.complete(frame.image);
    await resume.future;
    return frame;
  }

  void complete() {
    if (!resume.isCompleted) resume.complete();
  }
}

Future<void> drainCoverDecode(bool Function() finished) async {
  for (var i = 0; i < 100 && !finished(); i++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(finished(), isTrue, reason: 'Native decode cleanup must complete');
}
