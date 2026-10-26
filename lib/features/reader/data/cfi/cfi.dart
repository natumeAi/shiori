import 'package:shiori/features/reader/data/cfi/cfi_compare.dart';
import 'package:shiori/features/reader/data/cfi/cfi_exporter.dart';
import 'package:shiori/features/reader/data/cfi/cfi_expression.dart';
import 'package:shiori/features/reader/data/cfi/cfi_parser.dart';
import 'package:shiori/features/reader/data/cfi/cfi_range.dart';
import 'package:shiori/features/reader/data/cfi/cfi_resolver.dart';
import 'package:shiori/features/reader/data/cfi/cfi_writer.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/source/source_position.dart';

export 'package:shiori/features/reader/data/cfi/cfi_exception.dart';
export 'package:shiori/features/reader/data/cfi/cfi_expression.dart';
export 'package:shiori/features/reader/data/cfi/cfi_range.dart';
export 'package:shiori/features/reader/data/cfi/cfi_step.dart';

/// EPUB CFI operations compatible with the pinned Foliate implementation
/// (commit 78914aef4466eb960965702401634c2cb348e9b1).
///
/// This is a compatibility boundary, not general CFI conformance: the
/// grammar is the reference's permissive state machine, unknown assertion
/// parameters are dropped (only `;s=` is kept) and failures carry the
/// reference's error class in [CfiException.referenceErrorName].
abstract final class Cfi {
  /// Parses [cfi], with or without the `epubcfi(...)` wrapper.
  static CfiExpression parse(String cfi) => parseCfi(cfi);

  /// Serializes [expression] as `epubcfi(...)`.
  static String serialize(CfiExpression expression) => serializeCfi(expression);

  /// Collapses a range CFI to its start (or end with [toEnd]); a path is
  /// returned re-serialized.
  static String collapse(String cfi, {bool toEnd = false}) =>
      serializeGroups(parseCfi(cfi).collapse(toEnd: toEnd));

  /// Orders two CFIs: negative, zero or positive. Ranges compare by their
  /// collapsed start, then their collapsed end.
  static int compare(String a, String b) =>
      compareCfi(parseCfi(a), parseCfi(b));

  /// Stable sort by [compare]; equal CFIs keep their input order.
  static List<String> sort(Iterable<String> cfis) => stableSort(cfis, compare);

  /// Joins indirection parts, e.g. a section base and a local CFI, with `!`.
  static String joinIndirection(List<String> cfis) =>
      'epubcfi(${cfis.map(unwrapCfi).join('!')})';

  /// Exports the CFI of [start], or of the range [start]..[end].
  ///
  /// Without [sectionBase] the result is the local (content document) CFI.
  /// [sectionBase] must be the section's real package CFI, e.g.
  /// `epubcfi(/8/4[ref-nonlinear])`; it is never derived from arithmetic.
  static String export(
    SourceDocument document,
    SourcePosition start, {
    SourcePosition? end,
    String? sectionBase,
  }) {
    final local = exportLocalCfi(document, start, end: end);
    return sectionBase == null ? local : joinIndirection([sectionBase, local]);
  }

  /// Resolves a full section CFI against that section's content [document].
  ///
  /// Like the reference's `resolveCFI`, the first indirection (the package
  /// path) is skipped and the next one is resolved. Range endpoints that the
  /// DOM would reverse collapse to the end. Boundaries outside the document
  /// element use node index -1.
  static CfiRange resolve(SourceDocument document, String cfi) =>
      resolveCfiRange(document, parseCfi(cfi), skipPackagePath: true);

  /// Resolves a local CFI (no package indirection) against [document].
  static CfiRange resolveLocal(SourceDocument document, String cfi) =>
      resolveCfiRange(document, parseCfi(cfi), skipPackagePath: false);

  /// Resolves the first (package) indirection of [cfi] to the node index of
  /// the OPF element it addresses, normally an `itemref`. The caller reads its
  /// `idref` attribute. Returns null when the path reaches no node.
  static int? resolvePackageNode(SourceDocument package, String cfi) =>
      resolvePackageNodeIndex(package, parseCfi(cfi));
}
