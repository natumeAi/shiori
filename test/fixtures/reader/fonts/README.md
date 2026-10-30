# Offline Brotli / WOFF2 vectors

These are decoder test inputs. Tests use committed bytes and the Dart SDK;
they never execute a compressor, fetch a font or load a Brotli native library.

Generator prerequisites: Python 3 stdlib and Git for Windows' MIT Brotli 1.2.0
`brotli.exe` on PATH (on the generating host:
`D:/DevTools/git/mingw64/bin/brotli.exe`). From the repository root:

```powershell
python test/fixtures/reader/fonts/generate_brotli_vectors.py
python test/fixtures/reader/fonts/generate_dictionary_vectors.py
python test/fixtures/reader/fonts/generate_woff2.py
```

`generate_brotli_vectors.py` writes 39 compressed vectors. It invokes
`brotli.exe -f -q Q -w W -o OUTPUT INPUT`: qualities 0/1/4/6/9/11 at windows
10/16/18/20/22/24, plus quality 5 at every window from 10 through 24. Inputs
are ASCII dictionary prose, repeated byte values, multilingual UTF-8 and
8,192 pseudorandom bytes from Python `random.Random(7932).randbytes(8192)`.
The input byte counts and SHA-256s are in `brotli-vectors.json`. Tests rebuild
the text/repetition inputs and read `random.bin`. Incompressible vectors
exercise stored blocks; the window-10 repetition also crosses window limits.

`brotli-structure.json` contains independently framed bit-level regressions:
HSKIP=3 with code-length-code space reaching zero after two symbols, HSKIP=3
with exactly one nonzero code-length-code symbol, and a metadata block followed
by an uncompressed block and an empty final block. Every output is obtained
by `brotli.exe -d -f -o OUTPUT INPUT` before the vector is written.

`generate_dictionary_vectors.py` explicitly encodes dictionary references to
each transform ID 0 through 120, using the first length-24 dictionary word.
The transform triples are read only to predict the frame's output length;
expected bytes come from native Brotli decompression. The 121 resulting
input/output hex pairs are in `dictionary-transforms.json`. This covers
prefixes/suffixes, UTF-8 NBSP, omissions and both capitalization operations.
The production dictionary is generated separately by
`tool/fonts/brotli_dictionary.dart` from the existing pinned `third_party`
input, and checks its SHA-256 lazily at first dictionary use.

`roboto-transformed.woff2` (71,476 bytes) is generated from the already pinned
`tool/oracle/fixtures/styles/EPUB/fonts/Roboto-Regular.ttf` (171,676 bytes,
SHA-256 `79e851404657dac2106b3d22ad256d47824a9a5765458edb72c9102a45816d95`).
It retains that fixture's font provenance and licence. No font source bytes
or pre-existing fixtures are edited. The independent Python forward transform
parses TrueType coordinates, composites and instructions, emits WOFF2 glyf,
loca and hmtx transforms with explicit tags, then compresses the single stream
with `brotli.exe -q 11 -w 22`. Roboto retains proportional side bearings;
the empty nonproportional hmtx array is omitted (flags=2). Tests also construct
small transformed fonts with both nonempty omitted arrays and all flags.

The original pinned WOFF2 in `fixed_layout/` uses null glyf/loca transforms;
it is tested unchanged. Its decoded 171,363-byte Brotli stream has SHA-256
`e352319f73b29d722f92528eb4fb1b6ca51a6f05ab10eef31668fb3d27ed5fab`,
independently obtained using Brotli 1.2.0. The transformed vector compares
all 1,294 decoded glyphs (points, contours, bounds, instructions, composite
components and overlap) and unchanged metric/layout tables against the SFNT.

Additional small WOFF2 fonts are constructed in Dart tests with standards
defined stored Brotli blocks. They cover all 128 triplet flags, both on-curve
states, LSB-first overlap versus MSB-first bbox bitmap ordering, calculated
and explicit bounds, both loca formats, all hmtx omission combinations,
all UInt255 lead-byte alternatives, maximum instruction lengths and malformed
directories/transforms. No external executable is required at test runtime.
