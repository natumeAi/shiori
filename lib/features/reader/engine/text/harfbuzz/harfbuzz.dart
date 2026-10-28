/// Prepared HarfBuzz outlines. Call admission, shaping, placement and disposal
/// only in reader control tasks; motion paints already prepared Paths.
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:shiori/features/reader/data/geometry/cluster_geometry.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';
import 'package:shiori/features/reader/data/worker/publication_cancellation.dart';
import 'package:shiori/features/reader/engine/layout/process_font_budget.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';

part 'hb_abi.dart';
part 'hb_bindings.dart';
part 'hb_source.dart';
part 'hb_resources.dart';
part 'hb_font.dart';
part 'hb_drawing.dart';
part 'hb_shape.dart';
part 'hb_run.dart';
part 'hb_placement.dart';
part 'hb_path.dart';

enum HarfBuzzFailure {
  libraryUnavailable,
  binaryIdentity,
  missingSymbol,
  incompatibleVersion,
  allocation,
  invalidFont,
  missingGlyph,
  invalidShaping,
  unsupportedRun,
  canceled,
  disposed,
  pathOverflow,
}

final class HarfBuzzException implements Exception {
  const HarfBuzzException(this.failure, {this.symbol});
  final HarfBuzzFailure failure;
  final String? symbol;
  @override
  String toString() => 'HarfBuzzException(${failure.name}, $symbol)';
}

void _control() => ReaderWorkGuard.check(ReaderWork.paragraphLayout);
void _checkCancellation(PublicationCancellation? token) {
  if (token?.isCanceled ?? false) {
    throw const HarfBuzzException(HarfBuzzFailure.canceled);
  }
}

/// OpenType tag encoded as four ASCII bytes, in big-endian order.
int harfBuzzTag(String value) {
  if (value.length != 4 || value.codeUnits.any((c) => c > 127)) {
    throw ArgumentError('An OpenType tag requires four ASCII characters');
  }
  return value.codeUnits.fold(0, (a, b) => (a << 8) | b);
}

enum HarfBuzzDirection { ltr, rtl, ttb, btt }

enum HarfBuzzLengthAdjust { spacing, spacingAndGlyphs }

final class HarfBuzzFeature {
  HarfBuzzFeature(
    String tag,
    this.value, {
    this.start = 0,
    this.end = 0xffffffff,
  }) : tag = harfBuzzTag(tag) {
    if (value < 0 ||
        value > 0xffffffff ||
        start < 0 ||
        end < start ||
        end > 0xffffffff) {
      throw ArgumentError('Invalid HarfBuzz feature range/value');
    }
  }
  final int tag, value, start, end;
}
