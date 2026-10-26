import 'dart:io';
import 'dart:isolate';

import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/core/storage/app_directories.dart';
import 'package:shiori/core/storage/directory_access.dart';
import 'package:shiori/features/diagnostics/data/probe_sqlite_result.dart';
import 'package:shiori/features/diagnostics/data/probe_sqlite_runner.dart';

part 'probe_sqlite_repository.g.dart';

class ProbeSqliteRepository {
  ProbeSqliteRepository(this._directories);

  final AppDirectories _directories;
  final _log = Logger('ProbeSqliteRepository');

  Future<ProbeSqliteResult> run() async {
    try {
      final support = await DirectoryAccess.resolve(
        _directories.applicationSupport,
      );
      // Capture only sendable values, never this repository or plugin objects.
      final path = support.path;
      final rootPort = Isolate.current.controlPort;
      return await Isolate.run(() => runProbeSqliteCheck(path, rootPort));
    } on IsolateSpawnException {
      _log.warning('sqlite_isolate_unavailable');
      throw const ParseException(FormatException('sqlite_isolate_unavailable'));
    } on FileSystemException {
      _log.warning('sqlite_directory_unavailable');
      throw const ParseException(
        FormatException('sqlite_directory_unavailable'),
      );
    }
  }
}

@Riverpod(keepAlive: true)
ProbeSqliteRepository probeSqliteRepository(Ref ref) =>
    ProbeSqliteRepository(ref.watch(appDirectoriesProvider));
