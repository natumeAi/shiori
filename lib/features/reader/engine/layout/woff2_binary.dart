part of 'woff2_decoder.dart';

const _malformed = FontFormatException(FontFormatFailure.malformed);
const _limit = FontFormatException(FontFormatFailure.limitExceeded);

/// All slices are views of an already admitted, fixed-size buffer.
final class _Reader {
  _Reader(this.bytes) : data = ByteData.sublistView(bytes);
  final Uint8List bytes;
  final ByteData data;
  int pos = 0;
  int get remaining => bytes.length - pos;
  int u8() {
    if (remaining < 1) throw _malformed;
    return bytes[pos++];
  }

  int u16() {
    if (remaining < 2) throw _malformed;
    final v = data.getUint16(pos);
    pos += 2;
    return v;
  }

  int i16() {
    final v = u16();
    return v >= 32768 ? v - 65536 : v;
  }

  int u32() {
    if (remaining < 4) throw _malformed;
    final v = data.getUint32(pos);
    pos += 4;
    return v;
  }

  Uint8List take(int size) {
    if (size < 0 || size > remaining) throw _malformed;
    final start = pos;
    pos += size;
    return Uint8List.sublistView(bytes, start, pos);
  }

  int base128() {
    var v = 0;
    for (var i = 0; i < 5; i++) {
      final b = u8();
      if ((i == 0 && b == 0x80) || (v & 0xfe000000) != 0) {
        throw _malformed;
      }
      v = (v << 7) | (b & 127);
      if (b < 128) return v;
    }
    throw _malformed;
  }

  int uint255() {
    final code = u8();
    return switch (code) {
      253 => u16(),
      254 => 506 + u8(),
      255 => 253 + u8(),
      _ => code,
    };
  }

  void done() {
    if (remaining != 0) throw _malformed;
  }
}

/// A size pass and an emission pass use the same checked writer.
final class _Writer {
  _Writer(this.limit, [Uint8List? bytes])
    : data = bytes == null ? null : ByteData.sublistView(bytes);
  final int limit;
  final ByteData? data;
  int pos = 0;
  void _room(int count) {
    if (count < 0 || count > limit - pos) throw _limit;
  }

  void u8(int v) {
    _room(1);
    data?.setUint8(pos, v);
    pos++;
  }

  void u16(int v) {
    _room(2);
    data?.setUint16(pos, v & 65535);
    pos += 2;
  }

  void u32(int v) {
    _room(4);
    data?.setUint32(pos, v);
    pos += 4;
  }

  void add(Uint8List bytes) {
    _room(bytes.length);
    if (data case final d?) {
      d.buffer
          .asUint8List(d.offsetInBytes, d.lengthInBytes)
          .setRange(pos, pos + bytes.length, bytes);
    }
    pos += bytes.length;
  }

  void pad(int alignment) {
    while (pos % alignment != 0) {
      u8(0);
    }
  }
}

int _tag(String s) => s.codeUnits.fold(0, (v, c) => (v << 8) | c);
final _knownTags = <String>[
  'cmap',
  'head',
  'hhea',
  'hmtx',
  'maxp',
  'name',
  'OS/2',
  'post',
  'cvt ',
  'fpgm',
  'glyf',
  'loca',
  'prep',
  'CFF ',
  'VORG',
  'EBDT',
  'EBLC',
  'gasp',
  'hdmx',
  'kern',
  'LTSH',
  'PCLT',
  'VDMX',
  'vhea',
  'vmtx',
  'BASE',
  'GDEF',
  'GPOS',
  'GSUB',
  'EBSC',
  'JSTF',
  'MATH',
  'CBDT',
  'CBLC',
  'COLR',
  'CPAL',
  'SVG ',
  'sbix',
  'acnt',
  'avar',
  'bdat',
  'bloc',
  'bsln',
  'cvar',
  'fdsc',
  'feat',
  'fmtx',
  'fvar',
  'gvar',
  'hsty',
  'just',
  'lcar',
  'mort',
  'morx',
  'opbd',
  'prop',
  'trak',
  'Zapf',
  'Silf',
  'Glat',
  'Gloc',
  'Feat',
  'Sill',
].map(_tag).toList(growable: false);

final class _Table {
  _Table(this.tag, this.original, this.transformed, this.size, this.start);
  final int tag, original, size, start;
  final bool transformed;
  int outputSize = 0;
  int offset = 0;
  Uint8List view(Uint8List stream) =>
      Uint8List.sublistView(stream, start, start + size);
}
