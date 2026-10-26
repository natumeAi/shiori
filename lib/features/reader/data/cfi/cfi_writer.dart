import 'package:shiori/features/reader/data/cfi/cfi_exception.dart';
import 'package:shiori/features/reader/data/cfi/cfi_expression.dart';
import 'package:shiori/features/reader/data/cfi/cfi_numbers.dart';
import 'package:shiori/features/reader/data/cfi/cfi_parser.dart';
import 'package:shiori/features/reader/data/cfi/cfi_step.dart';

/// The reference's `toString`: serializes [expression] as `epubcfi(...)`.
String serializeCfi(CfiExpression expression) {
  if (!expression.isRange) return serializeGroups(expression.groups);
  final end = expression.end;
  if (end == null) throw const CfiException('TypeError');
  return wrapCfi(
    [expression.parent!, expression.start!, end].map(_groupsToString).join(','),
  );
}

/// Serializes a path of indirection [groups].
String serializeGroups(CfiGroups groups) => wrapCfi(_groupsToString(groups));

String _groupsToString(CfiGroups groups) =>
    groups.map((parts) => parts.map(_stepToString).join()).join('!');

String _stepToString(CfiStep step) {
  final side = step.side;
  final hasSide = side != null && side.isNotEmpty;
  final id = step.id;
  final hasId = id != null && id.isNotEmpty;
  final param = hasSide ? ';s=$side' : '';
  final buffer = StringBuffer('/${jsNumberToString(step.index)}');
  if (hasId) buffer.write('[${_escape(id)}$param]');
  final index = step.index;
  if (step.offset != null && index.isFinite && index.remainder(2) != 0) {
    buffer.write(':${jsNumberToString(step.offset!)}');
  }
  if (jsTruthy(step.temporal)) {
    buffer.write('~${jsNumberToString(step.temporal!)}');
  }
  if (step.spatial case final spatial?) {
    buffer.write('@${spatial.map(jsNumberToString).join(':')}');
  }
  final text = step.text;
  if (text != null || (!hasId && hasSide)) {
    buffer.write('[${text?.map(_escape).join(',') ?? ''}$param]');
  }
  return buffer.toString();
}

String _escape(String text) =>
    text.replaceAllMapped(_special, (match) => '^${match.group(0)}');

final _special = RegExp(r'[\^\[\](),;=]');
