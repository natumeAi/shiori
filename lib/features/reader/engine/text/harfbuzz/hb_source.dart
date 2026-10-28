part of 'harfbuzz.dart';

/// No implicit system-font or installed-library fallback. Host paths are opened
/// absolutely, after checking the three pinned DLL hashes before any preload.
final class HarfBuzzLibrarySource {
  HarfBuzzLibrarySource.windowsHost({String? directory})
    : directory = directory ?? windowsDirectory,
      prefix = '',
      _library = null,
      _process = false;
  HarfBuzzLibrarySource.process({this.prefix = 'shiori_'})
    : directory = null,
      _library = null,
      _process = true {
    if (prefix.isEmpty) throw ArgumentError('iOS requires a symbol prefix');
  }

  /// Explicit embedding/test source. iOS still refuses an empty prefix.
  HarfBuzzLibrarySource.library(DynamicLibrary library, {this.prefix = ''})
    : directory = null,
      _library = library,
      _process = false;

  static const windowsDirectory =
      'build/third_party/harfbuzz-14.6.0/extracted/harfbuzz-win64';
  static const windowsHashes = {
    'libintl-8.dll':
        '46e34a84cd32b644eaf35fd44532e5786ceb8e896fa11bbd842f6b607f50c570',
    'libglib-2.0-0.dll':
        '5a3e1404ca58a0a34cd4f4143d1cb0522a7666e838e808fdc95f7f81a3d8563b',
    'libharfbuzz-0.dll':
        '54f305d0e69f70a0ae285d45aa9bf6c73ef4d86b93480312c7cff142996d63c3',
  };
  final String? directory;
  final String prefix;
  final DynamicLibrary? _library;
  final bool _process;
  static final _modules = <String, DynamicLibrary>{};

  DynamicLibrary _open() {
    _control();
    if (Platform.isIOS && prefix.isEmpty) {
      throw const HarfBuzzException(HarfBuzzFailure.libraryUnavailable);
    }
    if (_library != null) return _library;
    if (_process) return DynamicLibrary.process();
    if (!Platform.isWindows) {
      throw const HarfBuzzException(HarfBuzzFailure.libraryUnavailable);
    }
    try {
      for (final entry in windowsHashes.entries) {
        final file = File('$directory/${entry.key}').absolute;
        if (sha256.convert(file.readAsBytesSync()).toString() != entry.value) {
          throw const HarfBuzzException(HarfBuzzFailure.binaryIdentity);
        }
      }
      DynamicLibrary? result;
      for (final name in windowsHashes.keys) {
        final path = File('$directory/$name').absolute.path;
        result = _modules.putIfAbsent(path, () => DynamicLibrary.open(path));
      }
      return result!;
    } on HarfBuzzException {
      rethrow;
    } catch (_) {
      throw const HarfBuzzException(HarfBuzzFailure.libraryUnavailable);
    }
  }
}
