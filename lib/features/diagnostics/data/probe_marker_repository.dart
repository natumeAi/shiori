import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/core/storage/app_directories.dart';
import 'package:shiori/core/storage/directory_access.dart';
part 'probe_marker_repository.g.dart';

class ProbeMarkerRepository {
  ProbeMarkerRepository(this._directories);
  final AppDirectories _directories;
  final _log = Logger('ProbeMarkerRepository');
  Future<File> _file() async {
    final directory = await DirectoryAccess.resolve(
      _directories.applicationSupport,
    );
    await directory.create(recursive: true);
    return File('${directory.path}${Platform.pathSeparator}probe-marker.txt');
  }

  Future<String> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return '';
      final handle = await file.open();
      try {
        return utf8.decode(await handle.read(4096));
      } finally {
        await handle.close();
      }
    } on FileSystemException catch (e, stack) {
      _log.warning('Marker load failed', e, stack);
      throw ParseException(e);
    } on FormatException catch (e, stack) {
      _log.warning('Invalid marker encoding', e, stack);
      throw ParseException(e);
    }
  }

  Future<void> save(String marker) async {
    if (marker.length > 256) {
      throw ArgumentError.value(
        marker.length,
        'marker',
        'Maximum 256 characters',
      );
    }
    try {
      await (await _file()).writeAsString(marker, flush: true);
    } on FileSystemException catch (e, stack) {
      _log.warning('Marker save failed', e, stack);
      throw ParseException(e);
    }
  }
}

@Riverpod(keepAlive: true)
ProbeMarkerRepository probeMarkerRepository(Ref ref) =>
    ProbeMarkerRepository(ref.watch(appDirectoriesProvider));
