/// A pinned-reference CFI failure, retaining its browser error classification.
///
/// [referenceErrorName] is the JavaScript error class the pinned Foliate
/// implementation raises for the same input (`TypeError`, `IndexSizeError`).
final class CfiException implements Exception {
  const CfiException(this.referenceErrorName);

  final String referenceErrorName;

  @override
  String toString() => 'CfiException($referenceErrorName)';
}
