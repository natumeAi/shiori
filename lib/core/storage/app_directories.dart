import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'app_directories.g.dart';

/// Feature code decides file formats; this boundary only locates directories.
abstract interface class AppDirectories {
  Future<Directory> applicationSupport();
  Future<Directory> documents();
}

class _PlatformDirectories implements AppDirectories {
  @override
  Future<Directory> applicationSupport() => getApplicationSupportDirectory();
  @override
  Future<Directory> documents() => getApplicationDocumentsDirectory();
}

@Riverpod(keepAlive: true)
AppDirectories appDirectories(Ref ref) => _PlatformDirectories();
