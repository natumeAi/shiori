// Standalone synthetic host measurement, intentionally not a flutter test.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/worker/publication_tag.dart';
import 'package:shiori/features/reader/data/worker/publication_worker.dart';

Future<void> main() async {
  final worker = await PublicationWorker.spawn();
  final replies = ReceivePort();
  final messages = StreamIterator<Object?>(replies);
  final echo = await Isolate.spawn(_echoSource, replies.sendPort);
  try {
    await messages.moveNext();
    final requests = messages.current! as SendPort;
    for (final fixture in ['one-page', 'long-content']) {
      await worker.open(
        'assets/reader_fixtures/$fixture.epub',
        PublicationTag(fixture),
      );
      final document = await worker.loadSection(0);
      final sends = <int>[];
      final roundTrips = <int>[];
      for (var i = 0; i < 25; i++) {
        final watch = Stopwatch()..start();
        requests.send(document);
        final send = watch.elapsedMicroseconds;
        await messages.moveNext();
        if ((messages.current! as SourceDocument).nodes.length !=
            document.nodes.length) {
          throw StateError('Source transfer changed node count');
        }
        if (i >= 5) {
          // Five warm-ups, twenty measured graph round trips.
          sends.add(send);
          roundTrips.add(watch.elapsedMicroseconds);
        }
      }
      sends.sort();
      roundTrips.sort();
      stdout.writeln(
        jsonEncode({
          'fixture': fixture,
          'nodes': document.nodes.length,
          'attributes': document.nodes.fold<int>(
            0,
            (n, node) => n + node.attributes.length,
          ),
          'textUtf16Units': document.nodes.fold<int>(
            0,
            (n, node) => n + (node.text?.length ?? 0),
          ),
          // A diagnostic size proxy only: the wire sends SourceDocument directly.
          'projectionJsonUtf8Bytes': utf8
              .encode(jsonEncode(document.toProjectionJson()))
              .length,
          'samples': sends.length,
          'sendMicrosMinMedianMax': [
            sends.first,
            sends[sends.length ~/ 2],
            sends.last,
          ],
          'roundTripMicrosMinMedianMax': [
            roundTrips.first,
            roundTrips[roundTrips.length ~/ 2],
            roundTrips.last,
          ],
        }),
      );
    }
  } finally {
    await worker.close();
    echo.kill(priority: Isolate.immediate);
    await messages.cancel();
    replies.close();
  }
}

void _echoSource(SendPort replies) {
  final requests = ReceivePort();
  replies.send(requests.sendPort);
  requests.listen((message) => replies.send(message));
}
