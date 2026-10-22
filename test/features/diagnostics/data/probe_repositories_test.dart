import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shiori/core/diagnostics/diagnostic_record.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/features/diagnostics/data/diagnostic_export_repository.dart';
import 'package:shiori/features/diagnostics/data/probe_marker_repository.dart';

import '../../../helpers/probe_storage_fixtures.dart';

void main() {
  late Directory root;
  late TestDirectories directories;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('shiori-probe-test-');
    directories = TestDirectories(root);
  });
  tearDown(() async {
    final parent = Directory.systemTemp.absolute.path;
    if (!root.absolute.path.startsWith('$parent${Platform.pathSeparator}')) {
      throw StateError('Unexpected temporary root');
    }
    await root.delete(recursive: true);
  });
  test('marker saves Unicode, reloads from new repository and stays out of Documents', () async {
    final repository = ProbeMarkerRepository(directories);
    expect(await repository.load(), '');
    await repository.save('更新与刷新保留 ✓');
    expect(await ProbeMarkerRepository(directories).load(), '更新与刷新保留 ✓');
    expect(await (await directories.documents()).exists(), isFalse);
    await repository.save('edited marker');
    expect(await repository.load(), 'edited marker');
    await expectLater(repository.save('x' * 257), throwsArgumentError);
  });
  test(
    'marker maps directory and invalid encoding failures to AppException',
    () async {
      final mock = MockDirectories();
      when(mock.applicationSupport)
          .thenThrow(const FileSystemException('unavailable'));
      final failed = ProbeMarkerRepository(mock);
      await expectLater(failed.load(), throwsA(isA<ParseException>()));
      await expectLater(failed.save('marker'), throwsA(isA<ParseException>()));
      final support = await directories.applicationSupport();
      await support.create();
      await File('${support.path}/probe-marker.txt').writeAsBytes([255]);
      await expectLater(
        ProbeMarkerRepository(directories).load(),
        throwsA(isA<ParseException>()),
      );
    },
  );
  test('export writes identity filename/raw JSON and reloadable private last record', () async {
    final repository = DiagnosticExportRepository(directories);
    expect(await repository.loadLast(), isNull);
    final record = storageRecord();
    final path = await repository.export(record);
    expect(path, endsWith('shiori-diag-commit-gh-42-run-fixture.json'));
    final decoded =
        jsonDecode(await File(path).readAsString()) as Map<String, Object?>;
    expect(DiagnosticRecord.fromJson(decoded), record);
    expect(await DiagnosticExportRepository(directories).loadLast(), record);
    expect((await (await directories.documents()).list().toList()).length, 1);
    final unsafe = record.copyWith(
      buildId: '../../bad',
      runId: 'run/with:slash',
    );
    expect(
      DiagnosticExportRepository.fileName(unsafe),
      equals('shiori-diag-.._.._bad-run_with_slash.json'),
    );
    final another = record.copyWith(runId: 'next-run');
    await repository.export(another);
    expect((await (await directories.documents()).list().toList()).length, 2);
    expect(await repository.loadLast(), another);
  });
  test('export maps filesystem failures and malformed saved records', () async {
    final mock = MockDirectories();
    when(mock.documents).thenThrow(const FileSystemException('unavailable'));
    when(mock.applicationSupport)
        .thenThrow(const FileSystemException('unavailable'));
    final failed = DiagnosticExportRepository(mock);
    await expectLater(
      failed.export(storageRecord()),
      throwsA(isA<ParseException>()),
    );
    await expectLater(failed.loadLast(), throwsA(isA<ParseException>()));
    final support = await directories.applicationSupport();
    await support.create();
    final file = File('${support.path}/last-diagnostic.json');
    final repository = DiagnosticExportRepository(directories);
    for (final content in ['not json', '[]', '{}']) {
      await file.writeAsString(content);
      await expectLater(repository.loadLast(), throwsA(isA<ParseException>()));
    }
  });
  test('persisted records require explicit supported schema version', () async {
    final support = await directories.applicationSupport();
    await support.create();
    final file = File('${support.path}/last-diagnostic.json');
    final repository = DiagnosticExportRepository(directories);
    for (final version in [null, 0, 2, 1.5, '1']) {
      final json = storageRecord().toJson()..['schemaVersion'] = version;
      if (version == null) json.remove('schemaVersion');
      await file.writeAsString(jsonEncode(json));
      await expectLater(repository.loadLast(), throwsA(isA<ParseException>()));
    }
  });
  test(
    'known directory plugin failures stay typed across every file operation',
    () async {
      for (final error in [
        MissingPlatformDirectoryException('unavailable'),
        PlatformException(code: 'unavailable'),
        MissingPluginException('unavailable'),
      ]) {
        final mock = MockDirectories();
        when(mock.documents).thenThrow(error);
        when(mock.applicationSupport).thenThrow(error);
        final marker = ProbeMarkerRepository(mock);
        final exports = DiagnosticExportRepository(mock);
        await expectLater(marker.load(), throwsA(isA<ParseException>()));
        await expectLater(
          marker.save('marker'),
          throwsA(isA<ParseException>()),
        );
        await expectLater(
          exports.export(storageRecord()),
          throwsA(isA<ParseException>()),
        );
        await expectLater(exports.loadLast(), throwsA(isA<ParseException>()));
      }
    },
  );
}
