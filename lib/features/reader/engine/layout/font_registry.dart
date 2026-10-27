import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:shiori/features/reader/data/epub/epub_archive.dart';
import 'package:shiori/features/reader/data/resources/archive_reader_resource_source.dart';
import 'package:shiori/features/reader/data/resources/reader_resource_source.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';
import 'package:shiori/features/reader/engine/style/style_resolver.dart';

/// One `@font-face` load attempt.
final class FontLoadRecord {
  const FontLoadRecord({
    required this.family,
    required this.alias,
    required this.archivePath,
    required this.loaded,
    this.failure,
  });

  final String family;
  final String alias;
  final String archivePath;
  final bool loaded;

  /// Failure class only, never resource content.
  final String? failure;
}

/// TrueType/OpenType/TrueType-collection magic. WOFF and WOFF2 are not loaded
/// by the engine on iOS, so they are reported instead of silently ignored.
bool _isSfnt(Uint8List bytes) {
  if (bytes.length < 12) return false;
  final tag = (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  return tag == 0x00010000 ||
      tag == 0x4f54544f || // OTTO
      tag == 0x74727565 || // true
      tag == 0x74746366; // ttcf
}

/// Loads `@font-face` fonts from the archive with [ui.loadFontFromList] under
/// a scope-prefixed alias, once per (alias, path). The engine cannot unload a
/// font, so the registry keeps the loaded set for the process lifetime.
final class FontRegistry {
  FontRegistry({this.maxFontBytes = 32 * 1024 * 1024});

  final int maxFontBytes;
  final Set<String> _loaded = {};
  final Map<String, FontLoadRecord> _records = {};

  /// Every load attempt so far, keyed by `alias|path`.
  Iterable<FontLoadRecord> get records => _records.values;

  static String aliasFor(String scope, String family) =>
      'shiori-$scope-${family.toLowerCase()}';

  /// Loads [faces]; returns lowercase CSS family to engine alias for the
  /// families that loaded. A face that fails is recorded and skipped, and
  /// its family falls back through the normal family chain.
  Future<Map<String, String>> load(
    EpubArchive archive,
    List<StyleFontFace> faces, {
    required String scope,
  }) =>
      loadResources(ArchiveReaderResourceSource(archive), faces, scope: scope);

  /// Same font validation/loading through encoded resources. The caller owns
  /// the source lease; the registry retains only font records/engine aliases.
  Future<Map<String, String>> loadResources(
    ReaderResourceSource resources,
    List<StyleFontFace> faces, {
    required String scope,
  }) async {
    ReaderWorkGuard.check(ReaderWork.fontLoad);
    final aliases = <String, String>{};
    for (final face in faces) {
      final alias = aliasFor(scope, face.family);
      final key = '$alias|${face.archivePath}';
      final existing = _records[key];
      if (existing != null) {
        if (existing.loaded) aliases[face.family.toLowerCase()] = alias;
        continue;
      }
      FontLoadRecord record;
      try {
        if (resources.size(face.archivePath) > maxFontBytes) {
          throw const FormatException('font too large');
        }
        final bytes = resources.bytes(face.archivePath);
        if (bytes == null) throw const FormatException('font missing');
        if (!_isSfnt(bytes)) throw const FormatException('font format');
        if (_loaded.add(key)) {
          await ui.loadFontFromList(bytes, fontFamily: alias);
        }
        record = FontLoadRecord(
          family: face.family,
          alias: alias,
          archivePath: face.archivePath,
          loaded: true,
        );
        aliases[face.family.toLowerCase()] = alias;
      } on Object catch (error) {
        record = FontLoadRecord(
          family: face.family,
          alias: alias,
          archivePath: face.archivePath,
          loaded: false,
          failure: error.runtimeType.toString(),
        );
      }
      _records[key] = record;
    }
    return aliases;
  }
}
