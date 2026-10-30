import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:shiori/features/reader/data/epub/epub_archive.dart';
import 'package:shiori/features/reader/data/resources/archive_reader_resource_source.dart';
import 'package:shiori/features/reader/data/resources/reader_resource_source.dart';
import 'package:shiori/features/reader/data/resources/reader_resource_budget.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';
import 'package:shiori/features/reader/data/worker/publication_cancellation.dart';
import 'package:shiori/features/reader/engine/layout/font_format.dart';
import 'package:shiori/features/reader/engine/layout/font_mapping.dart';
import 'package:shiori/features/reader/engine/layout/process_font_budget.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/layout/woff_decoder.dart';
import 'package:shiori/features/reader/engine/layout/woff2_decoder.dart';
import 'package:shiori/features/reader/engine/style/style_resolver.dart';
import 'package:shiori/features/reader/engine/style/computed_style.dart';

/// One `@font-face` load attempt.
final class FontLoadRecord {
  const FontLoadRecord({
    required this.family,
    required this.alias,
    required this.archivePath,
    required this.loaded,
    this.weight = 400,
    this.style = StyleFontStyle.normal,
    this.failure,
  });

  final String family;
  final String alias;
  final String archivePath;
  final bool loaded;
  final int weight;
  final StyleFontStyle style;

  /// Failure class only, never resource content.
  final String? failure;
}

/// WOFF must be converted before crossing the native boundary.
bool _isSfnt(Uint8List bytes) {
  if (bytes.length < 12) return false;
  final tag = (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  return tag == 0x00010000 ||
      tag == 0x4f54544f || // OTTO
      tag == 0x74727565 || // true
      tag == 0x74746366; // ttcf
}

/// CSS mappings/diagnostics are local; registration identity and accounting
/// belong to the process owner. Native errors cannot certify no retention.
final class FontRegistry {
  FontRegistry({
    this.maxFontBytes = 32 * 1024 * 1024,
    ProcessFontBudget? processBudget,
    ReaderResourceBudget? conversionBudget,
    Future<void> Function(Uint8List, String)? register,
  }) : processBudget = processBudget ?? ProcessFontBudget.shared,
       conversionBudget = conversionBudget ?? ReaderResourceBudget.shared,
       _register = register ?? _registerNative;

  final int maxFontBytes;
  final ProcessFontBudget processBudget;
  final ReaderResourceBudget conversionBudget;
  final Future<void> Function(Uint8List, String) _register;
  final Map<String, FontLoadRecord> _records = {};
  final Set<Future<void>> _physical = {};

  /// A canceled waiter does not remove started or coalesced native work.
  Future<void> drainFonts() async {
    while (_physical.isNotEmpty) {
      await Future.wait(_physical.toList());
    }
  }

  String _key(String scope, StyleFontFace face) =>
      '$scope|${face.family.toLowerCase()}|${face.archivePath}|'
      '${face.weight}|${face.style.name}';

  ResolvedFontFamilies selectFace(
    List<String> families, {
    required String scope,
    required List<StyleFontFace> faces,
    required int weight,
    required StyleFontStyle style,
  }) {
    final admitted = <AdmittedFontFace>[];
    for (final face in faces) {
      final record = _records[_key(scope, face)];
      // Required fixed content cannot substitute a missing packaged face.
      if (record == null || !record.loaded) {
        throw const RequiredFontException(
          FontFormatException(FontFormatFailure.missing),
        );
      }
      admitted.add((face: face, alias: record.alias));
    }
    return resolveFontFaces(
      families,
      weight: weight,
      style: style,
      faces: admitted,
    );
  }

  /// Latest attempt for each scope/CSS family/path; not registration identity.
  Iterable<FontLoadRecord> get records => _records.values;

  /// Exact identity of a loaded face for consumers of the same admission.
  ({String alias, String descriptor, int faceIndex}) admittedIdentity(
    String scope,
    StyleFontFace face,
  ) {
    final record = _records[_key(scope, face)];
    if (record == null || !record.loaded) {
      throw const RequiredFontException(
        FontFormatException(FontFormatFailure.missing),
      );
    }
    return (
      alias: record.alias,
      descriptor: 'index=0;weight=${face.weight};style=${face.style.name}',
      faceIndex: 0,
    );
  }

  static Future<void> _registerNative(Uint8List bytes, String alias) =>
      ui.loadFontFromList(bytes, fontFamily: alias);

  /// Loads [faces]; returns lowercase CSS family to engine alias for the
  /// families that loaded. Ordinary reflow failures retain the family fallback
  /// chain. Required content sets [requiredFonts]; admission and cancellation
  /// always propagate, independently of that flag.
  Future<Map<String, String>> load(
    EpubArchive archive,
    List<StyleFontFace> faces, {
    required String scope,
    bool requiredFonts = false,
    PublicationCancellation? cancellation,
  }) => loadResources(
    ArchiveReaderResourceSource(archive),
    faces,
    scope: scope,
    requiredFonts: requiredFonts,
    cancellation: cancellation,
  );

  /// Same font validation/loading through encoded resources. The caller owns
  /// the source lease; the registry retains only font records/engine aliases.
  Future<Map<String, String>> loadResources(
    ReaderResourceSource resources,
    List<StyleFontFace> faces, {
    required String scope,
    bool requiredFonts = false,
    PublicationCancellation? cancellation,
  }) async {
    ReaderWorkGuard.check(ReaderWork.fontLoad);
    final aliases = <String, String>{};
    for (final face in faces) {
      if (cancellation?.isCanceled ?? false) {
        throw const ProcessFontLoadCanceled();
      }
      var alias = '';
      final key = _key(scope, face);
      FontLoadRecord record;
      try {
        if (resources.size(face.archivePath) > maxFontBytes) {
          throw const FontFormatException(FontFormatFailure.limitExceeded);
        }
        final bytes = resources.bytes(face.archivePath);
        if (bytes == null) {
          throw const FontFormatException(FontFormatFailure.missing);
        }
        if (bytes.length > maxFontBytes) {
          throw const FontFormatException(FontFormatFailure.limitExceeded);
        }
        final work = _loadFace(bytes, face);
        late final Future<void> physical;
        physical = work
            .then<void>((_) {}, onError: (Object _) {})
            .whenComplete(() => _physical.remove(physical));
        _physical.add(physical);
        alias = await _wait(work, cancellation);
        if (cancellation?.isCanceled ?? false) {
          throw const ProcessFontLoadCanceled();
        }
        record = FontLoadRecord(
          family: face.family,
          alias: alias,
          archivePath: face.archivePath,
          loaded: true,
          weight: face.weight,
          style: face.style,
        );
        aliases[face.family.toLowerCase()] = alias;
      } on Object catch (error) {
        if (error is SceneAdmissionException ||
            error is ReaderResourceException ||
            error is ProcessFontLoadCanceled) {
          rethrow;
        }
        if (requiredFonts) throw RequiredFontException(error);
        record = FontLoadRecord(
          family: face.family,
          alias: alias,
          archivePath: face.archivePath,
          loaded: false,
          weight: face.weight,
          style: face.style,
          failure: error.runtimeType.toString(),
        );
      }
      _records[key] = record;
    }
    return aliases;
  }

  Future<String> _loadFace(Uint8List bytes, StyleFontFace face) async {
    ConvertedFont? converted;
    try {
      final tag = bytes.length < 4
          ? 0
          : ByteData.sublistView(bytes).getUint32(0);
      if (tag == 0x774f4646) {
        converted = WoffDecoder(maxBytes: maxFontBytes)
            .decode(bytes, budget: conversionBudget);
        bytes = converted.bytes;
      } else if (tag == 0x774f4632) {
        converted = Woff2Decoder(maxBytes: maxFontBytes)
            .decode(bytes, budget: conversionBudget);
        bytes = converted.bytes;
      } else if (!_isSfnt(bytes)) {
        throw const FontFormatException(FontFormatFailure.unsupportedFormat);
      }
      return await processBudget.load(
        bytes,
        face: 'index=0;weight=${face.weight};style=${face.style.name}',
        register: _register,
      );
    } finally {
      // This future has no caller cancellation: keep the converted buffer
      // charged until shared registration succeeds/fails, even if all leave.
      converted?.dispose();
    }
  }

  Future<String> _wait(Future<String> work, PublicationCancellation? token) {
    if (token == null) return work;
    final done = Completer<String>();
    final unsubscribe = token.listen(() {
      if (!done.isCompleted) {
        done.completeError(const ProcessFontLoadCanceled());
      }
    });
    work.then(
      (alias) {
        unsubscribe();
        if (!done.isCompleted) done.complete(alias);
      },
      onError: (Object error, StackTrace stack) {
        unsubscribe();
        if (!done.isCompleted) done.completeError(error, stack);
      },
    );
    return done.future;
  }
}
