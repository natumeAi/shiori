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
    } on MissingPlatformDirectoryException catch (error, stack) {
      _fail(error, stack);
    } on PlatformException catch (error, stack) {
      _fail(error, stack);
    } on MissingPluginException catch (error, stack) {
      _fail(error, stack);
    }
  }

  static Never _fail(Object error, StackTrace stack) {
    _log.warning('App directory lookup failed', error, stack);
    throw ParseException(error);
  }
}
