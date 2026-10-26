import 'dart:convert';
import 'dart:io';

import 'package:json_annotation/json_annotation.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shiori/core/diagnostics/diagnostic_record.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/core/storage/app_directories.dart';
import 'package:shiori/core/storage/directory_access.dart';
import 'package:shiori/features/diagnostics/data/probe_sqlite_result.dart';
part 'diagnostic_export_repository.g.dart';

class DiagnosticExportRepository {
  DiagnosticExportRepository(this._directories);
  final AppDirectories _directories;
  final _log = Logger('DiagnosticExportRepository');
  static String _safe(String value) => value
      .replaceAll(RegExp('[^a-zA-Z0-9._-]'), '_')
      .substring(0, value.length.clamp(0, 100));
  static String fileName(DiagnosticRecord record) =>
      'shiori-diag-${_safe(record.buildId)}-${_safe(record.runId)}.json';
  Future<String> export(DiagnosticRecord record) async {
    try {
      final directory = await DirectoryAccess.resolve(_directories.documents);
      await directory.create(recursive: true);
      final file = File(
        '${directory.path}${Platform.pathSeparator}${fileName(record)}',
      );
      final json = const JsonEncoder.withIndent('  ').convert(record.toJson());
      await file.writeAsString(json, flush: true);
      final support = await DirectoryAccess.resolve(
        _directories.applicationSupport,
      );
      await support.create(recursive: true);
      await File('${support.path}${Platform.pathSeparator}last-diagnostic.json')
          .writeAsString(json, flush: true);
      return file.path;
    } on FileSystemException catch (e, stack) {
      _log.warning('Diagnostic export failed', e, stack);
      throw ParseException(e);
    }
  }

  Future<DiagnosticRecord?> loadLast() async {
    try {
      final support = await DirectoryAccess.resolve(
        _directories.applicationSupport,
      );
      final file = File(
        '${support.path}${Platform.pathSeparator}last-diagnostic.json',
      );
      if (!await file.exists()) return null;
      final json =
          jsonDecode(await file.readAsString()) as Map<String, Object?>;
      // No persisted diagnostic format predates schema 1. Never reinterpret a
      // missing or future version through generated field defaults.
      if (json['schemaVersion'] is! int || json['schemaVersion'] != 1) {
        throw const FormatException('Unsupported diagnostic schema version');
      }
      final record = DiagnosticRecord.fromJson(json);
      ProbeSqliteResult.fromMetadata(record.metadata);
      return record;
    } on FileSystemException catch (e, stack) {
      _log.warning('Last diagnostic load failed', e, stack);
      throw ParseException(e);
    } on FormatException catch (e, stack) {
      _log.warning('Invalid diagnostic JSON', e, stack);
      throw ParseException(e);
    } on CheckedFromJsonException catch (e, stack) {
      _log.warning('Invalid diagnostic record', e, stack);
      throw ParseException(e);
    } on TypeError catch (e, stack) {
      _log.warning('Invalid diagnostic shape', e, stack);
      throw ParseException(e);
    }
  }
}

@Riverpod(keepAlive: true)
DiagnosticExportRepository diagnosticExportRepository(Ref ref) =>
    DiagnosticExportRepository(ref.watch(appDirectoriesProvider));
