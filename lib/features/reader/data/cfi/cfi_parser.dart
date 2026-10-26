import 'package:shiori/features/reader/data/cfi/cfi_exception.dart';
import 'package:shiori/features/reader/data/cfi/cfi_expression.dart';
import 'package:shiori/features/reader/data/cfi/cfi_numbers.dart';
import 'package:shiori/features/reader/data/cfi/cfi_step.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';

// Port of Foliate's permissive CFI tokenizer and parser. This is a state
// machine, not a strict grammar: malformed input is accepted or fails
// exactly as the pinned reference does.

final _wrapper = RegExp(r'^epubcfi\((.*)\)$');

/// The reference's `x.match(isCFI)?.[1] ?? x`.
String unwrapCfi(String text) => _wrapper.firstMatch(text)?.group(1) ?? text;

/// The reference's `wrap`.
String wrapCfi(String text) =>
    _wrapper.hasMatch(text) ? text : 'epubcfi($text)';

/// Parses [cfi]; unknown assertion parameters are discarded as in the pin.
CfiExpression parseCfi(String cfi) {
  ReaderWorkGuard.check(ReaderWork.parsing);
  final tokens = _tokenize(unwrapCfi(cfi));
  final commas = _indicesOf(tokens, ',');
  if (commas.isEmpty) return CfiExpression.path(_parseIndirections(tokens));
  final pieces = _splitAt(tokens, commas).map(_parseIndirections).toList();
  return CfiExpression.range(
    parent: pieces[0],
    start: pieces[1],
    end: pieces.length > 2 ? pieces[2] : null,
  );
}

typedef _Token = (String, Object?);

List<_Token> _tokenize(String source) {
  final tokens = <_Token>[];
  String? state;
  var escape = false;
  var value = '';

  void push(_Token token) {
    tokens.add(token);
    state = null;
    value = '';
  }

  void cat(String char) {
    value += char;
    escape = false;
  }

  final characters = [
    for (final rune in _jsTrim(source).runes) String.fromCharCode(rune),
    '',
  ];
  for (final char in characters) {
    if (char == '^' && !escape) {
      escape = true;
      continue;
    }
    final current = state;
    if (current == '!') {
      push(('!', null));
    } else if (current == ',') {
      push((',', null));
    } else if (current == '/' || current == ':') {
      if (_isDigit(char)) {
        cat(char);
        continue;
      }
      push((current!, jsParseDigits(value)));
    } else if (current == '~') {
      if (_isDigit(char) || char == '.') {
        cat(char);
        continue;
      }
      push(('~', jsParseFloat(value)));
    } else if (current == '@') {
      if (char == ':') {
        push(('@', jsParseFloat(value)));
        state = '@';
        continue;
      }
      if (_isDigit(char) || char == '.') {
        cat(char);
        continue;
      }
      push(('@', jsParseFloat(value)));
    } else if (current == '[') {
      if (char == ';' && !escape) {
        push(('[', value));
        state = ';';
      } else if (char == ',' && !escape) {
        push(('[', value));
        state = '[';
      } else if (char == ']' && !escape) {
        push(('[', value));
      } else {
        cat(char);
      }
      continue;
    } else if (current != null && current.startsWith(';')) {
      if (char == '=' && !escape) {
        state = ';$value';
        value = '';
      } else if (char == ';' && !escape) {
        push((current, value));
        state = ';';
      } else if (char == ']' && !escape) {
        push((current, value));
      } else {
        cat(char);
      }
      continue;
    }
    if (const {'/', ':', '~', '@', '[', '!', ','}.contains(char)) {
      state = char;
    }
  }
  return tokens;
}

bool _isDigit(String char) =>
    char.length == 1 &&
    char.codeUnitAt(0) >= 0x30 &&
    char.codeUnitAt(0) <= 0x39;

List<int> _indicesOf(List<_Token> tokens, String type) => [
  for (var i = 0; i < tokens.length; i++)
    if (tokens[i].$1 == type) i,
];

List<List<_Token>> _splitAt(List<_Token> tokens, List<int> indices) {
  final result = <List<_Token>>[];
  var previous = -1;
  for (final index in [...indices, tokens.length]) {
    result.add(tokens.sublist(previous + 1, index));
    previous = index;
  }
  return result;
}

CfiGroups _parseIndirections(List<_Token> tokens) =>
    _splitAt(tokens, _indicesOf(tokens, '!')).map(_parseSteps).toList();

List<CfiStep> _parseSteps(List<_Token> tokens) {
  final parts = <_StepBuilder>[];
  String? state;
  _StepBuilder last() {
    if (parts.isEmpty) throw const CfiException('TypeError');
    return parts.last;
  }

  for (final (type, value) in tokens) {
    if (type == '/') {
      parts.add(_StepBuilder(value! as num));
    } else if (type == ':') {
      last().offset = value! as num;
    } else if (type == '~') {
      last().temporal = value! as num;
    } else if (type == '@') {
      (last().spatial ??= []).add(value! as num);
    } else if (type == ';s') {
      last().side = value! as String;
    } else if (type == '[') {
      final text = value! as String;
      if (state == '/' && text.isNotEmpty) {
        last().id = text;
      } else {
        (last().text ??= []).add(text);
        // The reference skips the state update on this branch.
        continue;
      }
    }
    state = type;
  }
  return [for (final part in parts) part.build()];
}

final class _StepBuilder {
  _StepBuilder(this.index);

  final num index;
  String? id;
  num? offset;
  num? temporal;
  List<num>? spatial;
  List<String>? text;
  String? side;

  CfiStep build() => CfiStep(
    index: index,
    id: id,
    offset: offset,
    temporal: temporal,
    spatial: spatial,
    text: text,
    side: side,
  );
}

/// `String.prototype.trim`: ECMAScript WhiteSpace and LineTerminator only.
String _jsTrim(String text) {
  var start = 0;
  var end = text.length;
  while (start < end && _isJsSpace(text.codeUnitAt(start))) {
    start++;
  }
  while (end > start && _isJsSpace(text.codeUnitAt(end - 1))) {
    end--;
  }
  return text.substring(start, end);
}

bool _isJsSpace(int unit) =>
    (unit >= 0x09 && unit <= 0x0d) ||
    unit == 0x20 ||
    unit == 0xa0 ||
    unit == 0x1680 ||
    (unit >= 0x2000 && unit <= 0x200a) ||
    unit == 0x2028 ||
    unit == 0x2029 ||
    unit == 0x202f ||
    unit == 0x205f ||
    unit == 0x3000 ||
    unit == 0xfeff;
