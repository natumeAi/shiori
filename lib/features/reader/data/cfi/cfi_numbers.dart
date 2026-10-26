/// JavaScript number semantics needed by the pinned CFI grammar.
library;

/// `parseInt` of a string that holds only ASCII digits (possibly empty).
num jsParseDigits(String digits) {
  if (digits.isEmpty) return double.nan;
  final value = int.tryParse(digits);
  if (value != null && value <= _maxSafeInteger) return value;
  return double.parse(digits);
}

/// `parseFloat` of a string made of ASCII digits and dots: the longest
/// valid decimal prefix, or NaN when there is none.
num jsParseFloat(String text) {
  final match = _decimalPrefix.matchAsPrefix(text);
  if (match == null) return double.nan;
  final value = double.parse(match.group(0)!);
  if (value == value.truncateToDouble() && value.abs() <= _maxSafeInteger) {
    return value.toInt();
  }
  return value;
}

/// `String(number)` as JavaScript prints it.
String jsNumberToString(num value) {
  if (value is int) return value.toString();
  final d = value.toDouble();
  if (d.isNaN) return 'NaN';
  if (d.isInfinite) return d < 0 ? '-Infinity' : 'Infinity';
  if (d == 0) return '0';
  final sign = d < 0 ? '-' : '';
  final text = d.abs().toString();
  final exponentAt = text.indexOf('e');
  final mantissa = exponentAt < 0 ? text : text.substring(0, exponentAt);
  final exponent = exponentAt < 0
      ? 0
      : int.parse(text.substring(exponentAt + 1));
  final dot = mantissa.indexOf('.');
  var digits = mantissa.replaceAll('.', '');
  var pointPosition = (dot < 0 ? mantissa.length : dot) + exponent;
  while (digits.startsWith('0')) {
    digits = digits.substring(1);
    pointPosition -= 1;
  }
  while (digits.endsWith('0')) {
    digits = digits.substring(0, digits.length - 1);
  }
  final count = digits.length;
  final n = pointPosition;
  final String body;
  if (count <= n && n <= 21) {
    body = digits + '0' * (n - count);
  } else if (0 < n && n <= 21) {
    body = '${digits.substring(0, n)}.${digits.substring(n)}';
  } else if (-6 < n && n <= 0) {
    body = '0.${'0' * -n}$digits';
  } else {
    final e = n - 1;
    final tail = '${e < 0 ? '-' : '+'}${e.abs()}';
    body = count == 1
        ? '${digits}e$tail'
        : '${digits[0]}.${digits.substring(1)}e$tail';
  }
  return '$sign$body';
}

/// JavaScript truthiness of an optional number.
bool jsTruthy(num? value) => value != null && value != 0 && !value.isNaN;

/// WebIDL `unsigned long` conversion used by `Range.setStart`.
int jsToUint32(num? value) {
  if (value == null || value.isNaN || value.isInfinite) return 0;
  final truncated = value.truncateToDouble();
  const modulus = 4294967296.0;
  return (truncated % modulus).toInt();
}

const _maxSafeInteger = 9007199254740991;
final _decimalPrefix = RegExp(r'\d+(\.\d*)?|\.\d+');
