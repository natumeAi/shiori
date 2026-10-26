import 'dart:io';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shiori/core/errors/app_exception.dart';

/// Normalize known plugin lookup failures before feature file I/O begins.
abstract final class DirectoryAccess {
  static final _log = Logger('DirectoryAccess');

  static Future<Directory> resolve(Future<Directory> Function() lookup) async {
    try {
      return await lookup();
    } on FileSystemException {
      // Preserve the filesystem type for repositories with their own mapping.
      _log.warning('directory_filesystem_unavailable');
      throw const FileSystemException('directory_filesystem_unavailable');
    } on MissingPlatformDirectoryException {
      _fail('directory_platform_unavailable');
    } on PlatformException {
      _fail('directory_platform_unavailable');
    } on MissingPluginException {
      _fail('directory_plugin_unavailable');
    }
  }

  static Never _fail(String classification) {
    _log.warning(classification);
    throw ParseException(FormatException(classification));
  }
}
