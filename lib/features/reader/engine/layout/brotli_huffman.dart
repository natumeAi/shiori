part of 'brotli_decoder.dart';

extension _PrefixCodes on _BrotliState {
  _Huffman _readHuffman(int alphabet) {
    final sel = bits(2);
    if (sel == 1) return _simpleHuffman(alphabet);
    final hskip = sel;
    final clLengths = List<int>.filled(18, 0);
    var space = 32;
    var nonzero = 0;
    for (var i = hskip; i < 18; i++) {
      if (space == 0) break;
      final v = _fixedCodeLength();
      clLengths[_codeLengthOrder[i]] = v;
      if (v != 0) {
        space -= 32 >> v;
        if (space < 0) throw _malformed;
        nonzero++;
      }
    }
    if (nonzero == 0) throw _malformed;
    if (nonzero > 1 && space != 0) throw _malformed;
    final clTree = nonzero == 1
        ? _Huffman.single(clLengths.indexWhere((v) => v != 0))
        : _Huffman(clLengths);
    return _actualHuffman(clTree, alphabet);
  }

  _Huffman _actualHuffman(_Huffman clTree, int alphabet) {
    final lengths = List<int>.filled(alphabet, 0);
    var index = 0;
    var kraft = 32768;
    var repeatCount = 0;
    var repeatLength = 0;
    var lastNonZero = 8;
    while (index < alphabet && kraft > 0) {
      final sym = clTree.decode(this);
      if (sym < 16) {
        repeatCount = 0;
        lengths[index++] = sym;
        if (sym != 0) {
          lastNonZero = sym;
          kraft -= 32768 >> sym;
        }
      } else {
        final value = sym == 16 ? lastNonZero : 0;
        final extra = sym == 16 ? 2 : 3;
        if (repeatLength != value) repeatCount = 0;
        repeatLength = value;
        final old = repeatCount;
        if (repeatCount > 0) repeatCount = (repeatCount - 2) << extra;
        repeatCount += bits(extra) + 3;
        final delta = repeatCount - old;
        if (index + delta > alphabet) throw _malformed;
        lengths.fillRange(index, index + delta, value);
        index += delta;
        if (value != 0) kraft -= (32768 >> value) * delta;
      }
      if (kraft < 0) throw _malformed;
    }
    if (kraft != 0) throw _malformed;
    if (lengths.where((v) => v != 0).length == 1) {
      return _Huffman.single(lengths.indexWhere((v) => v != 0));
    }
    return _Huffman(lengths);
  }

  int _fixedCodeLength() {
    // Decode only the required bits, including at the end of a short stream.
    final prefix = bits(2);
    if (prefix == 0) return 0;
    if (prefix == 1) return 4;
    if (prefix == 2) return 3;
    if (bits(1) == 0) return 2;
    return bits(1) == 0 ? 1 : 5;
  }

  _Huffman _simpleHuffman(int alphabet) {
    final nsym = bits(2) + 1;
    final symBits = alphabet <= 1 ? 1 : (alphabet - 1).bitLength;
    final symbols = <int>[];
    for (var i = 0; i < nsym; i++) {
      final s = bits(symBits);
      if (s >= alphabet || symbols.contains(s)) throw _malformed;
      symbols.add(s);
    }
    if (nsym == 1) return _Huffman.single(symbols[0]);
    final lengths = List<int>.filled(alphabet, 0);
    if (nsym == 2) {
      lengths[symbols[0]] = 1;
      lengths[symbols[1]] = 1;
    } else if (nsym == 3) {
      lengths[symbols[0]] = 1;
      lengths[symbols[1]] = 2;
      lengths[symbols[2]] = 2;
    } else {
      final treeSelect = bits(1);
      if (treeSelect == 0) {
        for (final s in symbols) {
          lengths[s] = 2;
        }
      } else {
        lengths[symbols[0]] = 1;
        lengths[symbols[1]] = 2;
        lengths[symbols[2]] = 3;
        lengths[symbols[3]] = 3;
      }
    }
    return _Huffman(lengths);
  }
}

final class _Huffman {
  _Huffman(List<int> lengths)
    : _count = List<int>.filled(16, 0),
      _firstCode = List<int>.filled(16, 0),
      _firstSymbol = List<int>.filled(16, 0),
      _symbols = <int>[],
      _single = -1 {
    var maxLen = 0;
    for (final l in lengths) {
      if (l < 0 || l > 15) throw _malformed;
      if (l != 0) {
        _count[l]++;
        if (l > maxLen) maxLen = l;
      }
    }
    if (maxLen == 0) throw _malformed;
    var code = 0;
    var index = 0;
    for (var len = 1; len <= 15; len++) {
      code = (code + _count[len - 1]) << 1;
      _firstCode[len] = code;
      _firstSymbol[len] = index;
      index += _count[len];
    }
    for (var len = 1; len <= 15; len++) {
      for (var s = 0; s < lengths.length; s++) {
        if (lengths[s] == len) _symbols.add(s);
      }
    }
    _maxLen = maxLen;
  }

  _Huffman.single(this._single)
    : _count = List<int>.filled(16, 0),
      _firstCode = List<int>.filled(16, 0),
      _firstSymbol = List<int>.filled(16, 0),
      _symbols = const [],
      _maxLen = 0;

  final List<int> _count, _firstCode, _firstSymbol, _symbols;
  final int _single;
  int _maxLen = 0;

  int decode(_BrotliState s) {
    if (_single >= 0) return _single;
    var code = 0;
    for (var len = 1; len <= _maxLen; len++) {
      if (s.bitPos >= s.input.length * 8) throw _malformed;
      code = (code << 1) | ((s.input[s.bitPos >> 3] >> (s.bitPos & 7)) & 1);
      s.bitPos++;
      final idx = code - _firstCode[len];
      if (idx >= 0 && idx < _count[len]) {
        return _symbols[_firstSymbol[len] + idx];
      }
    }
    throw _malformed;
  }
}

const _codeLengthOrder = [
  1,
  2,
  3,
  4,
  0,
  5,
  17,
  6,
  16,
  7,
  8,
  9,
  10,
  11,
  12,
  13,
  14,
  15,
];
