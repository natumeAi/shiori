import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:shiori/features/reader/engine/layout/brotli_dictionary_data.dart';
import 'package:shiori/features/reader/engine/layout/font_format.dart';

part 'brotli_dictionary.dart';
part 'brotli_huffman.dart';

const _malformed = FontFormatException(FontFormatFailure.malformed);
const _limit = FontFormatException(FontFormatFailure.limitExceeded);

/// RFC 7932 decode-only Brotli with fixed admitted output storage.
final class BrotliDecoder {
  const BrotliDecoder({
    this.maxOutputBytes = 32 * 1024 * 1024,
    this.maxInputBytes = 32 * 1024 * 1024,
  });
  final int maxOutputBytes, maxInputBytes;

  Uint8List decode(Uint8List input, {int? exactOutputBytes}) {
    final size = exactOutputBytes ?? maxOutputBytes;
    if (size < 0 || size > maxOutputBytes || input.length > maxInputBytes) {
      throw _limit;
    }
    final out = Uint8List(size);
    final state = _BrotliState(input, out, exact: exactOutputBytes != null);
    state.run();
    return exactOutputBytes == null
        ? Uint8List.sublistView(out, 0, state.pos)
        : out;
  }
}

final class _BrotliState {
  _BrotliState(this.input, this.out, {required this.exact});
  final Uint8List input;
  final Uint8List out;
  final bool exact;
  int bitPos = 0;
  int pos = 0;
  int windowBits = 16;
  int p1 = 0, p2 = 0;
  final List<int> distances = [4, 11, 15, 16];

  int _bit() {
    if (bitPos >= input.length * 8) throw _malformed;
    final v = (input[bitPos >> 3] >> (bitPos & 7)) & 1;
    bitPos++;
    return v;
  }

  int bits(int n) {
    if (n < 0 || n > 32 || bitPos + n > input.length * 8) throw _malformed;
    var v = 0;
    for (var i = 0; i < n; i++) {
      v |= _bit() << i;
    }
    return v;
  }

  void align() {
    final pad = (8 - (bitPos & 7)) & 7;
    if (pad != 0 && bits(pad) != 0) throw _malformed;
  }

  void emit(int b) {
    if (pos >= out.length) throw _limit;
    out[pos++] = b;
    p2 = p1;
    p1 = b;
  }

  void run() {
    if (input.isEmpty) throw _malformed;
    if (_bit() == 0) {
      windowBits = 16;
    } else {
      final n = bits(3);
      if (n != 0) {
        windowBits = 17 + n;
      } else {
        final m = bits(3);
        if (m == 0) {
          windowBits = 17;
        } else if (m == 1) {
          throw _malformed;
        } else {
          windowBits = 8 + m;
        }
      }
    }
    if (windowBits < 10 || windowBits > 24) throw _malformed;
    var last = false;
    while (!last) {
      last = _bit() == 1;
      if (last) {
        if (_bit() == 1) break;
      }
      final mnibbles = bits(2);
      if (mnibbles == 3) {
        if (bits(1) != 0) throw _malformed;
        final skipBytes = bits(2);
        var skip = 0;
        if (skipBytes != 0) {
          skip = bits(skipBytes * 8) + 1;
          if (skipBytes > 1 && ((skip - 1) >> (8 * (skipBytes - 1))) == 0) {
            throw _malformed;
          }
        }
        align();
        if (bitPos + skip * 8 > input.length * 8) throw _malformed;
        bitPos += skip * 8;
        continue;
      }
      final nibbles = mnibbles + 4;
      final mlen = bits(nibbles * 4) + 1;
      if (nibbles > 4 && ((mlen - 1) >> (4 * (nibbles - 1))) == 0) {
        throw _malformed;
      }
      if (!last && _bit() == 1) {
        align();
        if (mlen > out.length - pos) throw _limit;
        if (bitPos + mlen * 8 > input.length * 8) throw _malformed;
        for (var i = 0; i < mlen; i++) {
          emit((input[bitPos >> 3] >> (bitPos & 7)) & 0xff);
          bitPos += 8;
        }
        continue;
      }
      if (mlen > out.length - pos) throw _limit;
      _metaBlock(mlen);
    }
    final rem = input.length * 8 - bitPos;
    if (rem > 7) throw _malformed;
    if (rem > 0 && bits(rem) != 0) throw _malformed;
    if (exact && pos != out.length) throw _malformed;
  }

  void _metaBlock(int mlen) {
    final end = pos + mlen;
    final nbl = [1, 1, 1];
    final btype = [0, 0, 0];
    final bprev = [1, 1, 1];
    final blen = [0, 0, 0];
    final btrees = <_Huffman?>[null, null, null];
    final bltrees = <_Huffman?>[null, null, null];
    for (var i = 0; i < 3; i++) {
      nbl[i] = _nbltypes();
      if (nbl[i] >= 2) {
        btrees[i] = _readHuffman(nbl[i] + 2);
        bltrees[i] = _readHuffman(26);
        blen[i] = _readBlockLength(bltrees[i]!);
      } else {
        blen[i] = 1 << 24;
      }
    }
    final npostfix = bits(2);
    final ndirect = bits(4) << npostfix;
    final distAlphabet = 16 + ndirect + (48 << npostfix);
    final modes = [for (var i = 0; i < nbl[0]; i++) bits(2)];
    final ntreesL = _nbltypes();
    final cmapL = <int>[];
    if (ntreesL >= 2) {
      cmapL.addAll(_contextMap(64 * nbl[0], ntreesL));
    } else {
      cmapL.addAll(List.filled(64 * nbl[0], 0));
    }
    final ntreesD = _nbltypes();
    final cmapD = <int>[];
    if (ntreesD >= 2) {
      cmapD.addAll(_contextMap(4 * nbl[2], ntreesD));
    } else {
      cmapD.addAll(List.filled(4 * nbl[2], 0));
    }
    final lit = [for (var i = 0; i < ntreesL; i++) _readHuffman(256)];
    final cmd = [for (var i = 0; i < nbl[1]; i++) _readHuffman(704)];
    final dst = [for (var i = 0; i < ntreesD; i++) _readHuffman(distAlphabet)];
    while (pos < end) {
      if (blen[1] == 0) {
        _nextBlock(1, nbl[1], btrees[1]!, bltrees[1]!, btype, bprev, blen);
      }
      blen[1]--;
      final cmdCode = cmd[btype[1]].decode(this);
      final insCopy = _command(cmdCode);
      final ilen = insCopy.insertBase + bits(insCopy.insertExtra);
      final clen = insCopy.copyBase + bits(insCopy.copyExtra);
      for (var i = 0; i < ilen; i++) {
        if (pos >= end) throw _malformed;
        if (blen[0] == 0) {
          _nextBlock(0, nbl[0], btrees[0]!, bltrees[0]!, btype, bprev, blen);
        }
        blen[0]--;
        final cid = _literalContext(modes[btype[0]]);
        final tree = lit[cmapL[64 * btype[0] + cid]];
        emit(tree.decode(this));
      }
      if (pos == end) break;
      var distance = 0;
      var dcode = 0;
      if (!insCopy.implicitDistance) {
        if (blen[2] == 0) {
          _nextBlock(2, nbl[2], btrees[2]!, bltrees[2]!, btype, bprev, blen);
        }
        blen[2]--;
        final dcid = clen > 4 ? 3 : clen - 2;
        final treeIndex = cmapD[4 * btype[2] + dcid];
        dcode = dst[treeIndex].decode(this);
        distance = _distance(dcode, npostfix, ndirect);
      } else {
        distance = distances[0];
      }
      final maxBack = (1 << windowBits) - 16;
      final maxAllowed = pos < maxBack ? pos : maxBack;
      if (distance > maxAllowed) {
        final wordId = distance - maxAllowed - 1;
        final word = _dictionaryWord(wordId, clen);
        if (word.length > end - pos) throw _malformed;
        for (final b in word) {
          emit(b);
        }
      } else {
        if (dcode != 0) {
          distances
            ..removeLast()
            ..insert(0, distance);
        }
        if (clen > end - pos) throw _malformed;
        final from = pos - distance;
        if (from < 0) throw _malformed;
        for (var i = 0; i < clen; i++) {
          emit(out[from + i]);
        }
      }
    }
    if (pos != end) throw _malformed;
  }

  void _nextBlock(
    int cat,
    int n,
    _Huffman bt,
    _Huffman bl,
    List<int> btype,
    List<int> bprev,
    List<int> blen,
  ) {
    final sym = bt.decode(this);
    final old = btype[cat];
    final next = sym == 0
        ? bprev[cat]
        : sym == 1
        ? (old + 1) % n
        : sym - 2;
    if (next < 0 || next >= n) throw _malformed;
    bprev[cat] = old;
    btype[cat] = next;
    blen[cat] = _readBlockLength(bl);
  }

  int _readBlockLength(_Huffman tree) {
    final code = tree.decode(this);
    if (code < 0 || code > 25) throw _malformed;
    return _blockLengthBase[code] + bits(_blockLengthExtra[code]);
  }

  int _nbltypes() {
    if (_bit() == 0) return 1;
    final n = bits(3);
    if (n == 0) return 2;
    final v = bits(n) + (1 << n);
    if (v > 255) throw _malformed;
    return v + 1;
  }

  int _literalContext(int mode) {
    switch (mode) {
      case 0:
        return p1 & 0x3f;
      case 1:
        return p1 >> 2;
      case 2:
        return _lut0[p1] | _lut1[p2];
      case 3:
        return (_lut2[p1] << 3) | _lut2[p2];
      default:
        throw _malformed;
    }
  }

  List<int> _contextMap(int size, int ntrees) {
    var rleMax = 0;
    if (_bit() == 1) {
      rleMax = bits(4) + 1;
    }
    final alphabet = ntrees + rleMax;
    final tree = _readHuffman(alphabet);
    final map = <int>[];
    while (map.length < size) {
      final sym = tree.decode(this);
      if (sym == 0) {
        map.add(0);
      } else if (sym <= rleMax) {
        final run = (1 << sym) + bits(sym);
        if (map.length + run > size) throw _malformed;
        map.addAll(List.filled(run, 0));
      } else {
        final value = sym - rleMax;
        if (value >= ntrees) throw _malformed;
        map.add(value);
      }
    }
    if (bits(1) == 1) {
      final mtf = List<int>.generate(256, (i) => i);
      for (var i = 0; i < map.length; i++) {
        final index = map[i];
        final value = mtf[index];
        map[i] = value;
        for (var k = index; k > 0; k--) {
          mtf[k] = mtf[k - 1];
        }
        mtf[0] = value;
      }
    }
    return map;
  }

  _Command _command(int code) {
    late int insCode, copyCode;
    var implicit = false;
    if (code < 0 || code > 703) throw _malformed;
    if (code < 128) {
      insCode = (code >> 3) & 7;
      copyCode = ((code >> 6) << 3) | (code & 7);
      implicit = true;
    } else {
      final c = code - 128;
      final cell = c >> 6;
      final j = c & 63;
      insCode = _insertRange[cell] + (j >> 3);
      copyCode = _copyRange[cell] + (j & 7);
    }
    return _Command(
      _insertBase[insCode],
      _insertExtra[insCode],
      _copyBase[copyCode],
      _copyExtra[copyCode],
      implicit,
    );
  }

  int _distance(int code, int npostfix, int ndirect) {
    if (code < 16) {
      const index = [0, 1, 2, 3, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1];
      const offset = [0, 0, 0, 0, -1, 1, -2, 2, -3, 3, -1, 1, -2, 2, -3, 3];
      final d = distances[index[code]] + offset[code];
      if (d <= 0) throw _malformed;
      return d;
    }
    if (code < 16 + ndirect) return code - 15;
    final c = code - ndirect - 16;
    final nbits = 1 + (c >> (npostfix + 1));
    final hcode = c >> npostfix;
    final lcode = c & ((1 << npostfix) - 1);
    final extra = bits(nbits);
    final offset = ((2 + (hcode & 1)) << nbits) - 4;
    return ((offset + extra) << npostfix) + lcode + ndirect + 1;
  }
}

final class _Command {
  const _Command(
    this.insertBase,
    this.insertExtra,
    this.copyBase,
    this.copyExtra,
    this.implicitDistance,
  );
  final int insertBase, insertExtra, copyBase, copyExtra;
  final bool implicitDistance;
}

const _insertBase = [
  0,
  1,
  2,
  3,
  4,
  5,
  6,
  8,
  10,
  14,
  18,
  26,
  34,
  50,
  66,
  98,
  130,
  194,
  322,
  578,
  1090,
  2114,
  6210,
  22594,
];
const _insertExtra = [
  0,
  0,
  0,
  0,
  0,
  0,
  1,
  1,
  2,
  2,
  3,
  3,
  4,
  4,
  5,
  5,
  6,
  7,
  8,
  9,
  10,
  12,
  14,
  24,
];
const _copyBase = [
  2,
  3,
  4,
  5,
  6,
  7,
  8,
  9,
  10,
  12,
  14,
  18,
  22,
  30,
  38,
  54,
  70,
  102,
  134,
  198,
  326,
  582,
  1094,
  2118,
];
const _copyExtra = [
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  1,
  1,
  2,
  2,
  3,
  3,
  4,
  4,
  5,
  5,
  6,
  7,
  8,
  9,
  10,
  24,
];
const _insertRange = [0, 0, 8, 8, 0, 16, 8, 16, 16];
const _copyRange = [0, 8, 0, 8, 16, 0, 16, 8, 16];
const _blockLengthBase = [
  1,
  5,
  9,
  13,
  17,
  25,
  33,
  41,
  49,
  65,
  81,
  97,
  113,
  145,
  177,
  209,
  241,
  305,
  369,
  497,
  753,
  1265,
  2289,
  4337,
  8433,
  16625,
];
const _blockLengthExtra = [
  2,
  2,
  2,
  2,
  3,
  3,
  3,
  3,
  4,
  4,
  4,
  4,
  5,
  5,
  5,
  5,
  6,
  6,
  7,
  8,
  9,
  10,
  11,
  12,
  13,
  24,
];
const _lut0 = [
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  4,
  4,
  0,
  0,
  4,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  8,
  12,
  16,
  12,
  12,
  20,
  12,
  16,
  24,
  28,
  12,
  12,
  32,
  12,
  36,
  12,
  44,
  44,
  44,
  44,
  44,
  44,
  44,
  44,
  44,
  44,
  32,
  32,
  24,
  40,
  28,
  12,
  12,
  48,
  52,
  52,
  52,
  48,
  52,
  52,
  52,
  48,
  52,
  52,
  52,
  52,
  52,
  48,
  52,
  52,
  52,
  52,
  52,
  48,
  52,
  52,
  52,
  52,
  52,
  24,
  12,
  28,
  12,
  12,
  12,
  56,
  60,
  60,
  60,
  56,
  60,
  60,
  60,
  56,
  60,
  60,
  60,
  60,
  60,
  56,
  60,
  60,
  60,
  60,
  60,
  56,
  60,
  60,
  60,
  60,
  60,
  24,
  12,
  28,
  12,
  0,
  0,
  1,
  0,
  1,
  0,
  1,
  0,
  1,
  0,
  1,
  0,
  1,
  0,
  1,
  0,
  1,
  0,
  1,
  0,
  1,
  0,
  1,
  0,
  1,
  0,
  1,
  0,
  1,
  0,
  1,
  0,
  1,
  0,
  1,
  0,
  1,
  0,
  1,
  0,
  1,
  0,
  1,
  0,
  1,
  0,
  1,
  0,
  1,
  0,
  1,
  0,
  1,
  0,
  1,
  0,
  1,
  0,
  1,
  0,
  1,
  0,
  1,
  0,
  1,
  2,
  3,
  2,
  3,
  2,
  3,
  2,
  3,
  2,
  3,
  2,
  3,
  2,
  3,
  2,
  3,
  2,
  3,
  2,
  3,
  2,
  3,
  2,
  3,
  2,
  3,
  2,
  3,
  2,
  3,
  2,
  3,
  2,
  3,
  2,
  3,
  2,
  3,
  2,
  3,
  2,
  3,
  2,
  3,
  2,
  3,
  2,
  3,
  2,
  3,
  2,
  3,
  2,
  3,
  2,
  3,
  2,
  3,
  2,
  3,
  2,
  3,
  2,
  3,
];
const _lut1 = [
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  1,
  1,
  1,
  1,
  1,
  1,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  1,
  1,
  1,
  1,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
];
const _lut2 = [
  0,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  6,
  6,
  6,
  6,
  6,
  6,
  6,
  6,
  6,
  6,
  6,
  6,
  6,
  6,
  6,
  7,
];
