// Manual host evidence: dart run tool/reader/publication_memory_probe.dart
// Measures the whole process (including the worker), never an isolate heap.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:shiori/core/config/content_identity.dart';
import 'package:shiori/features/reader/data/resources/reader_resource_budget.dart';
import 'package:shiori/features/reader/data/worker/publication_worker.dart';

import '../../test/features/reader/data/worker/import_test_support.dart';
import 'publication_memory_fixture.dart';

Future<void> main(List<String> args) async {
  if (args.length == 3 && args.first == '--measure') {
    await _measure(args[1], args[2]);
    return;
  }
  final temp = Directory.systemTemp.createTempSync('shiori-worker-rss-');
  try {
    final file = File('${temp.path}/generated.epub');
    writePublicationMemoryFixture(file.path);
    final digest = await crypto.sha256.bind(file.openRead()).single;
    stdout.writeln(
      'Host ${Platform.operatingSystem}; Dart ${Platform.version.split(' ').first}',
    );
    final result = await Process.run(Platform.resolvedExecutable, [
      'run',
      Platform.script.toFilePath(),
      '--measure',
      file.path,
      digest.toString(),
    ]);
    stdout.write(result.stdout);
    if (result.exitCode != 0) {
      stderr.write(result.stderr);
      throw StateError('Worker RSS experiment failed: ${result.exitCode}');
    }
  } finally {
    temp.deleteSync(recursive: true);
    stdout.writeln('Temporary EPUB and directory deleted.');
  }
}

Future<void> _measure(String path, String digest) async {
  final worker = await PublicationWorker.spawn();
  final budget = ReaderResourceBudget();
  final baseline = ProcessInfo.currentRss;
  final baselineMax = ProcessInfo.maxRss;
  try {
    final publication = await worker.prepare(
      path,
      ContentIdentity(importBookKey, digest),
    );
    final prepared = ProcessInfo.currentRss;
    final preparedMax = ProcessInfo.maxRss;
    final loaded = await worker.preloadSection(
      publication.firstSection.sectionIndex,
      budget: budget,
    );
    final preloaded = ProcessInfo.currentRss;
    final preloadedMax = ProcessInfo.maxRss;
    final retained = budget.retainedBytes;
    var sampled = 0;
    for (final path in loaded.plan.lengths.keys) {
      sampled += loaded.resources.bytes(path)!.length;
    }
    loaded.dispose();
    await worker.close();
    stdout.writeln(
      jsonEncode({
        'archiveBytes': File(path).lengthSync(),
        'storedImageEntries': 200,
        'preloadedEntries': loaded.plan.lengths.length,
        'sampledBytes': sampled,
        'baselineRss': baseline,
        'baselineMaxRss': baselineMax,
        'prepareRss': prepared,
        'prepareDelta': prepared - baseline,
        'prepareMaxRss': preparedMax,
        'preloadRss': preloaded,
        'preloadDelta': preloaded - baseline,
        'preloadMaxRss': preloadedMax,
        'retainedBytes': retained,
        'afterRetirementAccountedBytes': budget.accountedBytes,
        'afterCloseRss': ProcessInfo.currentRss,
        'processMaxRss': ProcessInfo.maxRss,
      }),
    );
  } finally {
    await worker.close();
  }
}
