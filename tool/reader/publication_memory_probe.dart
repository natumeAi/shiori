// Manual host evidence: dart run tool/reader/publication_memory_probe.dart
// Measures the whole process (including the worker), never an isolate heap.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:shiori/core/config/content_identity.dart';
import 'package:shiori/features/reader/data/epub/epub_archive.dart';
import 'package:shiori/features/reader/data/resources/reader_resource_budget.dart';
import 'package:shiori/features/reader/data/worker/publication_worker.dart';

import '../../test/features/reader/data/worker/import_test_support.dart';
import 'publication_memory_fixture.dart';

const _mib = 1024 * 1024;
const _runs = 3;

Future<void> main(List<String> args) async {
  if (args.length == 3 && args.first == '--measure') {
    await _measure(args[1], args[2]);
    return;
  }
  final temp = Directory.systemTemp.createTempSync('shiori-worker-rss-');
  try {
    stdout.writeln(
      'Host ${Platform.operatingSystem}; Dart ${Platform.version.split(' ').first}',
    );
    final fixtures = <int, (File, String)>{};
    final measurements = <int, List<Map<String, Object?>>>{};
    for (final targetPayloadBytes in [20 * _mib, 200 * _mib]) {
      final unreadImageBytes =
          (targetPayloadBytes -
              publicationMemoryPreloadedEntries *
                  publicationMemoryPreloadedImageBytes) ~/
          (publicationMemoryImageEntries - publicationMemoryPreloadedEntries);
      final file = File('${temp.path}/generated-$targetPayloadBytes.epub');
      writePublicationMemoryFixture(
        file.path,
        unreadImageBytes: unreadImageBytes,
      );
      final digest = await crypto.sha256.bind(file.openRead()).single;
      fixtures[targetPayloadBytes] = (file, digest.toString());
      measurements[targetPayloadBytes] = [];
    }
    _verifyFixtures(fixtures.values.map((fixture) => fixture.$1).toList());
    // Alternate sizes to avoid confounding size with a run-order trend. Fixture
    // generation and hashing stay outside each fresh measured child process.
    for (var run = 1; run <= _runs; run++) {
      for (final entry in fixtures.entries) {
        final (file, digest) = entry.value;
        final result = await Process.run(Platform.resolvedExecutable, [
          'run',
          Platform.script.toFilePath(),
          '--measure',
          file.path,
          digest,
        ]);
        if (result.exitCode != 0) {
          stderr.write(result.stderr);
          throw StateError('Worker RSS experiment failed: ${result.exitCode}');
        }
        final measurement = {
          'run': run,
          'targetPayloadBytes': entry.key,
          ...jsonDecode(result.stdout as String) as Map<String, Object?>,
        };
        const expectedRetained =
            publicationMemoryPreloadedEntries *
            publicationMemoryPreloadedImageBytes;
        if (measurement['preloadedEntries'] !=
                publicationMemoryPreloadedEntries ||
            measurement['sampledBytes'] != expectedRetained ||
            measurement['retainedBytes'] != expectedRetained ||
            jsonEncode(measurement['preloadedPaths']) !=
                jsonEncode([
                  for (var i = 0; i < publicationMemoryPreloadedEntries; i++)
                    'EPUB/image-$i.png',
                ]) ||
            measurement['reservedBytes'] != 0 ||
            measurement['afterRetirementAccountedBytes'] != 0) {
          throw StateError(
            'Unexpected preload/resource accounting: $measurement',
          );
        }
        measurements[entry.key]!.add(measurement);
        stdout.writeln(jsonEncode(measurement));
      }
    }
    for (final entry in measurements.entries) {
      stdout.writeln(
        jsonEncode({
          'summaryTargetPayloadBytes': entry.key,
          'runs': _runs,
          for (final metric in [
            'baselineRss',
            'baselineMaxRss',
            'prepareRss',
            'prepareDelta',
            'prepareMaxRss',
            'preloadRss',
            'preloadDelta',
            'preloadMaxRss',
            'peakDelta',
            'peakGrowth',
            'afterCloseRss',
            'processMaxRss',
            'sampledBytes',
            'retainedBytes',
            'reservedBytes',
            'afterRetirementAccountedBytes',
          ])
            metric: _summary(entry.value, metric),
        }),
      );
    }
  } finally {
    temp.deleteSync(recursive: true);
    stdout.writeln('Temporary EPUB and directory deleted.');
  }
}

void _verifyFixtures(List<File> files) {
  final small = EpubArchive.openFile(files.first.path);
  try {
    final large = EpubArchive.openFile(files.last.path);
    try {
      final names = small.names.toList();
      if (jsonEncode(names) != jsonEncode(large.names.toList())) {
        throw StateError('Fixture entry names/count differ');
      }
      final unreadNames = {
        for (
          var i = publicationMemoryPreloadedEntries;
          i < publicationMemoryImageEntries;
          i++
        )
          'EPUB/image-$i.png',
      };
      final sharedDigests = <String, String>{};
      for (final name in names) {
        if (unreadNames.contains(name)) continue;
        final left = small.bytes(name)!;
        final right = large.bytes(name)!;
        if (left.length != right.length ||
            Iterable<int>.generate(left.length)
                .any((index) => left[index] != right[index])) {
          throw StateError('Shared fixture entry differs: $name');
        }
        sharedDigests[name] = crypto.sha256.convert(left).toString();
      }
      stdout.writeln(
        jsonEncode({
          'fixtureEntries': names.length,
          'byteIdenticalEntries': sharedDigests,
          'unreadImageEntries': unreadNames.length,
          'unreadImageBytes': [
            small.size(unreadNames.first),
            large.size(unreadNames.first),
          ],
        }),
      );
    } finally {
      large.close();
    }
  } finally {
    small.close();
  }
}

Map<String, int> _summary(List<Map<String, Object?>> runs, String metric) {
  final values = [for (final run in runs) run[metric] as int]..sort();
  return {
    'median': values[values.length ~/ 2],
    'min': values.first,
    'max': values.last,
  };
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
    final reserved = budget.reservedBytes;
    var sampled = 0;
    for (final path in loaded.plan.lengths.keys) {
      sampled += loaded.resources.bytes(path)!.length;
    }
    loaded.dispose();
    await worker.close();
    stdout.writeln(
      jsonEncode({
        'archiveBytes': File(path).lengthSync(),
        'storedImageEntries': publicationMemoryImageEntries,
        'preloadedEntries': loaded.plan.lengths.length,
        'preloadedPaths': loaded.plan.lengths.keys.toList()..sort(),
        'sampledBytes': sampled,
        'baselineRss': baseline,
        'baselineMaxRss': baselineMax,
        'prepareRss': prepared,
        'prepareDelta': prepared - baseline,
        'prepareMaxRss': preparedMax,
        'preloadRss': preloaded,
        'preloadDelta': preloaded - baseline,
        'preloadMaxRss': preloadedMax,
        // Peak delta uses current baseline conservatively; peakGrowth excludes
        // the process high-water mark already reached before measurement.
        'peakDelta': preloadedMax - baseline,
        'peakGrowth': preloadedMax - baselineMax,
        'retainedBytes': retained,
        'reservedBytes': reserved,
        'afterRetirementAccountedBytes': budget.accountedBytes,
        'afterCloseRss': ProcessInfo.currentRss,
        'processMaxRss': ProcessInfo.maxRss,
      }),
    );
  } finally {
    await worker.close();
  }
}
