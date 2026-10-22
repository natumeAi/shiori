/// Package-relative URL helpers matching the reference `resolveURL`,
/// `decodeURI` and `isExternal` (foliate-js `epub.js`).
library;

final _scheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+\-.]*:');
final _externalPattern = RegExp(r'^(?!blob)\w+:', caseSensitive: false);
final _controlsToStrip = RegExp(r'[\t\n\r]');

/// `isExternal(uri)`: a scheme other than `blob:`.
bool isExternalUrl(String? uri) => _externalPattern.hasMatch(uri ?? 'null');

/// `resolveURL(url, relativeTo)` for a package-relative base path: resolve
/// against the base directory, drop the query, keep the fragment, then
/// `decodeURI`. On failure the reference returns [url] unchanged.
String resolveUrl(String? url, String relativeTo) {
  final input = url ?? 'null';
  try {
    if (relativeTo.contains(':')) return input;
    var text = input
        .replaceAll(_controlsToStrip, '')
        .replaceAll(RegExp(r'^[\x00-\x20]+|[\x00-\x20]+$'), '');
    if (_scheme.hasMatch(text) || text.startsWith('//')) {
      return decodeUri(text);
    }
    String? fragment;
    final hash = text.indexOf('#');
    if (hash >= 0) {
      fragment = text.substring(hash + 1);
      text = text.substring(0, hash);
    }
    final question = text.indexOf('?');
    if (question >= 0) text = text.substring(0, question);
    text = text.replaceAll(r'\', '/');
    final baseDirectory = relativeTo.contains('/')
        ? relativeTo.substring(0, relativeTo.lastIndexOf('/') + 1)
        : '';
    final String path;
    if (text.startsWith('/')) {
      path = text;
    } else if (text.isEmpty) {
      path = '/${relativeTo.replaceAll(r'\', '/')}';
    } else {
      path = '/${baseDirectory.replaceAll(r'\', '/')}$text';
    }
    final segments = <String>[];
    final parts = path.split('/');
    for (var index = 1; index < parts.length; index++) {
      final part = parts[index];
      final lower = part.toLowerCase();
      final isLast = index == parts.length - 1;
      if (lower == '.' || lower == '%2e') {
        if (isLast) segments.add('');
      } else if (lower == '..' ||
          lower == '.%2e' ||
          lower == '%2e.' ||
          lower == '%2e%2e') {
        if (segments.isNotEmpty) segments.removeLast();
        if (isLast) segments.add('');
      } else {
        segments.add(part);
      }
    }
    final resolved = segments.join('/');
    return decodeUri(fragment == null ? resolved : '$resolved#$fragment');
  } on FormatException {
    return input;
  }
}

const _reserved = ';/?:@&=+\$,#';

final _hexPair = RegExp(r'^[0-9a-fA-F]{2}$');

int _hex(String value, int at) {
  if (at + 3 > value.length || value.codeUnitAt(at) != 0x25) {
    throw const FormatException('URI malformed');
  }
  final pair = value.substring(at + 1, at + 3);
  if (!_hexPair.hasMatch(pair)) throw const FormatException('URI malformed');
  return int.parse(pair, radix: 16);
}

/// JavaScript `decodeURI`; throws [FormatException] where it throws URIError.
String decodeUri(String value) {
  if (!value.contains('%')) return value;
  final out = StringBuffer();
  var k = 0;
  while (k < value.length) {
    final c = value[k];
    if (c != '%') {
      out.write(c);
      k++;
      continue;
    }
    final first = _hex(value, k);
    if (first < 0x80) {
      final decoded = String.fromCharCode(first);
      out.write(
        _reserved.contains(decoded) ? value.substring(k, k + 3) : decoded,
      );
      k += 3;
      continue;
    }
    final int count;
    int codePoint;
    if (first & 0xe0 == 0xc0) {
      count = 2;
      codePoint = first & 0x1f;
    } else if (first & 0xf0 == 0xe0) {
      count = 3;
      codePoint = first & 0x0f;
    } else if (first & 0xf8 == 0xf0) {
      count = 4;
      codePoint = first & 0x07;
    } else {
      throw const FormatException('URI malformed');
    }
    var cursor = k + 3;
    for (var n = 1; n < count; n++) {
      final next = _hex(value, cursor);
      if (next & 0xc0 != 0x80) throw const FormatException('URI malformed');
      codePoint = (codePoint << 6) | (next & 0x3f);
      cursor += 3;
    }
    const minimum = [0, 0, 0x80, 0x800, 0x10000];
    if (codePoint < minimum[count] ||
        codePoint > 0x10ffff ||
        (codePoint >= 0xd800 && codePoint <= 0xdfff)) {
      throw const FormatException('URI malformed');
    }
    out.writeCharCode(codePoint);
    k = cursor;
  }
  return out.toString();
}
