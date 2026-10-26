/// FNV-1a 64-bit over UTF-8 bytes with 16-bit limbs, so no step relies on
/// 64-bit integer overflow (ported from the reference `Fnv1a64`).
final class Fnv1a64 {
  int _h0 = 0x2325;
  int _h1 = 0x8422;
  int _h2 = 0x9ce4;
  int _h3 = 0xcbf2;

  void byte(int value) {
    _h0 ^= value & 0xff;
    // h * 0x100000001b3 mod 2^64 = h * 0x1b3 + (h << 40).
    final t0 = _h0 * 0x1b3;
    var t1 = _h1 * 0x1b3;
    var t2 = _h2 * 0x1b3 + (_h0 << 8);
    var t3 = _h3 * 0x1b3 + (_h1 << 8);
    t1 += t0 >>> 16;
    t2 += t1 >>> 16;
    t3 += t2 >>> 16;
    _h0 = t0 & 0xffff;
    _h1 = t1 & 0xffff;
    _h2 = t2 & 0xffff;
    _h3 = t3 & 0xffff;
  }

  /// Feeds one Unicode scalar value as its UTF-8 encoding.
  void codePoint(int codePoint) {
    if (codePoint < 0x80) {
      byte(codePoint);
    } else if (codePoint < 0x800) {
      byte(0xc0 | (codePoint >> 6));
      byte(0x80 | (codePoint & 0x3f));
    } else if (codePoint < 0x10000) {
      byte(0xe0 | (codePoint >> 12));
      byte(0x80 | ((codePoint >> 6) & 0x3f));
      byte(0x80 | (codePoint & 0x3f));
    } else {
      byte(0xf0 | (codePoint >> 18));
      byte(0x80 | ((codePoint >> 12) & 0x3f));
      byte(0x80 | ((codePoint >> 6) & 0x3f));
      byte(0x80 | (codePoint & 0x3f));
    }
  }

  /// Sixteen lowercase hex digits.
  String hex() => [
    _h3,
    _h2,
    _h1,
    _h0,
  ].map((limb) => limb.toRadixString(16).padLeft(4, '0')).join();
}

/// Digest of a string's code points; unpaired surrogates hash as themselves.
String fnv1a64Hex(String text) {
  final hash = Fnv1a64();
  for (final rune in text.runes) {
    hash.codePoint(rune);
  }
  return hash.hex();
}
