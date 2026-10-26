import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/core/storage/app_directories.dart';
import 'package:shiori/core/storage/directory_access.dart';
import 'package:shiori/features/diagnostics/data/book_digest.dart';

/// Private locator never enters recorder metadata, labels or serialization.
final class ProbeBook {
  const ProbeBook({required this.sha256, this.fixtureId, required this.read});
  final String sha256;
  final String? fixtureId;
  final Future<Uint8List> Function() read;
}

class ProbeBookRepository {
  ProbeBookRepository(this.directories, {AssetBundle? assets})
    : assets = assets ?? rootBundle;
  final AppDirectories directories;
  final AssetBundle assets;
  static final _log = Logger('ProbeBookRepository');

  Future<List<ProbeBook>> list() async {
    try {
      final manifest = jsonDecode(
        await assets.loadString('assets/reader_fixtures/manifest.json'),
      ) as Map<String, Object?>;
      final result = <ProbeBook>[];
      for (final item in manifest['fixtures'] as List<Object?>) {
        final entry = item as Map<String, Object?>;
        final path = 'assets/reader_fixtures/${entry['file']}';
        result.add(
          ProbeBook(
            sha256: entry['sha256'] as String,
            fixtureId: entry['id'] as String,
            read: () async => (await assets.load(path)).buffer.asUint8List(),
          ),
        );
      }
      final dir = await DirectoryAccess.resolve(directories.documents);
      if (await dir.exists()) {
        await for (final entity in dir.list(followLinks: false)) {
          if (entity is! File || !entity.path.toLowerCase().endsWith('.epub')) {
            continue;
          }
          final digest = sha256Hex(await entity.readAsBytes());
          result.add(ProbeBook(sha256: digest, read: () => _read(entity)));
        }
      }
      return result;
    } on FileSystemException {
      _log.warning('Book inventory I/O failure; details withheld');
      throw const ParseException();
    } on FormatException {
      _log.warning('Invalid fixture manifest');
      throw const ParseException();
    } on TypeError {
      _log.warning('Invalid fixture manifest shape');
      throw const ParseException();
    } on FlutterError {
      _log.warning('Bundled fixture unavailable');
      throw const ParseException();
    }
  }

  static Future<Uint8List> _read(File file) async {
    try {
      return await file.readAsBytes();
    } on FileSystemException {
      _log.warning('Book read I/O failure; details withheld');
      throw const ParseException();
    }
  }
}
