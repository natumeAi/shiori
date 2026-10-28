import 'dart:convert';
import 'dart:io';

import 'package:json_annotation/json_annotation.dart';
import 'package:logging/logging.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/core/storage/app_directories.dart';
import 'package:shiori/core/storage/directory_access.dart';
import 'package:shiori/features/diagnostics/data/reader_feasibility_record.dart';

class ReaderExportRepository {
  ReaderExportRepository(this.directories);
  final AppDirectories directories;
  static final _log = Logger('ReaderExportRepository');
  static String _safe(String value) => value
      .replaceAll(RegExp('[^a-zA-Z0-9._-]'), '_')
      .substring(0, value.length.clamp(0, 100));
  static String fileName(ReaderFeasibilityRecord record) =>
      'shiori-reader-${_safe(record.engine.buildId)}-'
      '${_safe(record.engine.runId)}.json';

  Future<String> export(ReaderFeasibilityRecord record) async {
    try {
      final dir = await DirectoryAccess.resolve(directories.documents);
      await dir.create(recursive: true);
      final file = File(
        '${dir.path}${Platform.pathSeparator}${fileName(record)}',
      );
      await file.writeAsString(jsonEncode(record.toJson()), flush: true);
      return file.path;
    } on FileSystemException {
      // Never log paths or exception messages: Documents can contain real books.
      _log.warning('Reader export I/O failure');
      throw const ParseException();
    }
  }

  static ReaderFeasibilityRecord decode(String value) {
    try {
      final json = jsonDecode(value) as Map<String, Object?>;
      if (json['kind'] != 'reader_feasibility' ||
          json['schemaVersion'] != 1 ||
          json['schemaVersion'] is! int) {
        throw const FormatException('Unsupported reader export schema');
      }
      if (json['engine'] case final Map<String, Object?> engine
          when engine['schemaVersion'] != 1 ||
              engine['schemaVersion'] is! int) {
        throw const FormatException('Unsupported engine schema');
      }
      final engine = json['engine'] as Map<String, Object?>;
      if (engine['metadata'] case final Map<String, Object?> metadata) {
        if (metadata['readerCaptureBudget'] case final budget?) {
          if (budget is! Map<String, Object?> ||
              budget['version'] is! int ||
              budget['version'] != 1 ||
              budget['storage'] != 'packed_numeric_rows' ||
              budget['repeatPolicy'] != 'stop_export_reset') {
            throw const FormatException('Unsupported reader capture budget');
          }
        }
      }
      return ReaderFeasibilityRecord.fromJson(json);
    } on FormatException {
      throw const ParseException();
    } on TypeError {
      throw const ParseException();
    } on CheckedFromJsonException {
      throw const ParseException();
    }
  }

  /// Same 4000-byte UTF-8 ceiling as S1, never truncates a code point.
  static String clipboard(ReaderFeasibilityRecord record) {
    final value =
        'reader_feasibility v1\n'
        '${record.scenarioId} ${record.repeatIndex}/${record.repeatCount} '
        '${record.input}\n${fileName(record)}\n'
        'book SHA-256: ${record.bookSha256}\n'
        'engine frames: ${record.engine.frames.length}; '
        'events: ${record.readerEvents.length}\n'
        'presentation: ${record.presentation['evidence']}\n'
        'physical presentation / touch-to-photon: unverified';
    final out = StringBuffer();
    var bytes = 0;
    for (final rune in value.runes) {
      final part = String.fromCharCode(rune);
      bytes += utf8.encode(part).length;
      if (bytes > 4000) break;
      out.write(part);
    }
    return out.toString();
  }
}
