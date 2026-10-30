---
name: flutter-reader-font-conversion
description: Pure-Dart WOFF/WOFF2 to SFNT conversion, Brotli decoder, admission order and fixed SVG text font routing
paths:
  - lib/features/reader/engine/layout/brotli_*.dart
  - lib/features/reader/engine/layout/woff*.dart
  - lib/features/reader/engine/layout/font_*.dart
  - lib/features/reader/engine/fixed/fixed_svg_text_fonts.dart
  - third_party/brotli/**
  - tool/fonts/**
  - test/features/reader/engine/layout/**
  - test/fixtures/reader/fonts/**
---

# WOFF / WOFF2 Font Conversion (S4a A3)

## 1. Scope / Trigger

Direct `ui.loadFontFromList` registration of WOFF or WOFF2 completes but shapes
with fallback (A0 host probe), so every packaged web font is converted to SFNT
in Dart before process admission. Apply this contract when changing
`FontRegistry`, font admission, `FixedSvgTextFontService`, the Brotli decoder or
the vendored dictionary. Paths are relative to `lib/features/reader/engine/`
unless a repository-root path is given. Process-wide byte/face policy is in
[Reader Resource Admission](./reader-resource-admission.md); do not duplicate it.

- No native Brotli/WOFF2 library, plugin or network input exists. The only
  vendored input is the Brotli static dictionary (data, no code).
- Conversion is synchronous with finite byte/table/work bounds. No iPhone decode
  time, native font allocation, RSS or fallback behavior is claimed; that is A5
  device evidence.

## 2. Signatures

| Boundary | API / source |
| --- | --- |
| WOFF 1.0 | `WoffDecoder({maxBytes, maxTableBytes, maxTables}).decode(Uint8List, {ReaderResourceBudget? budget}) -> ConvertedFont` (`layout/woff_decoder.dart`) |
| WOFF2 | `Woff2Decoder({maxBytes, maxTableBytes, maxTables}).decode(Uint8List, {budget}) -> ConvertedFont` (`layout/woff2_decoder.dart` plus `woff2_{binary,directory,glyf,points,metrics}.dart` parts) |
| Brotli | `BrotliDecoder({maxOutputBytes, maxInputBytes}).decode(Uint8List, {int? exactOutputBytes}) -> Uint8List` (`layout/brotli_decoder.dart`, parts `brotli_{dictionary,huffman}.dart`) |
| Converted buffer | `ConvertedFont.admitted(bytes, ReaderResourceSession)`; `bytes`; idempotent `dispose()` retires the session |
| Routing | `FontRegistry._loadFace` switches on the first four bytes: `wOFF` -> WOFF, `wOF2` -> WOFF2, SFNT tags (`0x00010000`, `OTTO`, `true`, `ttcf`) pass through, anything else `FontFormatException(unsupportedFormat)` (`layout/font_registry.dart`) |
| Failure types | `FontFormatException(FontFormatFailure)`: `unsupportedFormat`, `malformed`, `limitExceeded`, `missing`; `RequiredFontException(cause)`; `ReaderResourceException(budgetExceeded)` (`layout/font_format.dart`, `data/resources/reader_resource_budget.dart`) |
| Fixed SVG text | `FixedSvgTextFontService.acquire(SvgTextFontRequest) -> Future<FixedSvgTextFontLease>` converts WOFF and WOFF2 with the same decoders (`fixed/fixed_svg_text_fonts.dart`) |
| Dictionary | `third_party/brotli/dictionary.bin` -> `layout/brotli_dictionary_data.dart` (generated); `dart run tool/fonts/brotli_dictionary.dart [--check]` |

## 3. Contracts

### Bounds

`FontRegistry.maxFontBytes` (default 32 MiB) is passed as `maxBytes` to both
decoders and is also the per-face input cap checked against the declared resource
size before bytes are read. Other bounds:

| Quantity | Limit | Over-limit result |
| --- | --- | --- |
| WOFF2 file, declared SFNT total, total transformed stream | 32 MiB each | `limitExceeded` |
| Brotli input / output | 32 MiB / exact declared stream size (<= `maxBytes`) | `limitExceeded` / mismatch is `malformed` or `limitExceeded` |
| One table (original, transformed or reconstructed) | 16 MiB | `limitExceeded` |
| Table count | 128 | `limitExceeded` |

Brotli output storage is allocated once at the exact (or maximum) admitted size;
there is no growing list and no per-byte allocation. WOFF2 decodes one Brotli
stream for all tables and requires its decoded length to equal the sum of the
directory's transformed sizes.

### Admission order (WOFF2; WOFF 1.0 reserves only `sfnt`)

All charges use `ReaderResourceBudget` (default `ReaderResourceBudget.shared`,
the existing 128 MiB encoded owner); there is no separate conversion capacity and
no process-RSS claim. A fresh `ReaderResourceSession` owns each conversion.

1. Validate header/directory (cheap, no allocation of output).
2. Reserve `woff2-stream` (transformed stream size) before Brotli allocates.
3. If `glyf` or `hmtx` is transformed, reserve `woff2-glyph-work` (fixed typed
   glyph scratch: 65,536 points plus per-glyph `loca`/`xMin` arrays) before
   allocating it.
4. A validating `glyf` pass computes the exact reconstructed SFNT length, then
   reserve `sfnt` before allocating or emitting it.
5. `woff2-stream` and `woff2-glyph-work` release when `decode` returns; every
   charge is retired when it throws. Only the `sfnt` charge survives.
6. `FontRegistry._loadFace` passes the converted bytes to
   `ProcessFontBudget.load` (process byte/face charge and digest/face dedup
   happen there, before `register` runs) and calls `ConvertedFont.dispose()` in
   a `finally` only after that shared load settles. The `_loadFace` future has no
   caller cancellation: a canceled waiter does not release the conversion charge
   while native registration is pending or coalesced; `drainFonts()` waits for it.
7. A native failure releases the conversion charge but leaves the process
   owner's uncertain registration charge (see resource admission).

`FixedSvgTextFontService.acquire` converts the same packaged bytes again for the
HarfBuzz asset, charges `registry.conversionBudget`, and disposes every
`ConvertedFont` exactly once when the lease releases or acquisition throws. The
face must already have a loaded `FontRegistry` record; the HarfBuzz token alias
must equal the registry alias or `RequiredFontException('svg-text-font-identity')`.

### WOFF2 structure accepted

Single-face fonts with flavor `0x00010000`, `OTTO` or `true`. Header reserved
field zero; table count 1..128; 63 known tags plus explicit tags; unique tables;
legal null/transform versions only (`glyf`/`loca` version 0 or 3, `hmtx` 0 or 1,
others 0); matching `glyf`/`loca` transform state with `glyf` before `loca`;
transformed `loca` stored size 0; `head.indexToLocFormat` equal to the
transformed `glyf` header; metadata/private blocks present only with valid
4-byte-aligned, non-overlapping ranges (the metadata block is validated, never
decompressed); zero padding only; no trailing data. Transformed `glyf` handles
every triplet flag, curve state, explicit/computed bounding boxes, composites with
instructions, empty glyphs and the overlap bitmap (LSB-first; `bboxBitmap` is
MSB-first). `hmtx` supports every omission combination and derives `xMin` from
reconstructed or null-transformed `glyf`. Table checksums and
`head.checkSumAdjustment` are rebuilt. TrueType collections (`ttcf` flavor) are
refused with `unsupportedFormat`; any other flavor is `malformed`.

### Brotli decoder

RFC 7932 decode-only: window bits 10..24 (large-window excluded), compressed,
uncompressed and metadata blocks, simple and complex prefix codes (HSKIP 0..3,
including a single nonzero code-length symbol and exact space exhaustion),
literal context modes and context maps with MTF, block switching, command and
distance codes, and all 121 dictionary transforms (including the two-byte UTF-8
NBSP affix). Truncation, trailing input, incomplete/oversubscribed codes and
non-zero padding are `malformed`; output overflow is `limitExceeded`. Debug
output and unbounded retry paths are forbidden.

### Vendored dictionary

`third_party/brotli/dictionary.bin` is the unmodified 122,784-byte RFC 7932
Appendix A dictionary (SHA-256
`20e42eb1b511c21806d4d227d07e5dd06877d8ce7b3a817f378f313653f35c70`, google/brotli
`v1.1.0`, MIT; `LICENSE` is kept beside it; the notice still has to be added to
the app licence registry). `.gitattributes` marks `third_party/**` binary so line
endings stay exact. `tool/fonts/brotli_dictionary.dart` verifies length and
digest of the binary, then writes base64 into `brotli_dictionary_data.dart`
(generated; never hand edit); `--check` fails when that file differs. The decoder
rechecks length and SHA-256 once, lazily, at first dictionary use and fails
`malformed` on mismatch.

## 4. Validation & Error Matrix

| Condition | Outcome |
| --- | --- |
| Declared resource size or bytes exceed `maxFontBytes` | `limitExceeded` before bytes are read / converted |
| Unknown magic that is not SFNT | `FontFormatException(unsupportedFormat)` before any native call |
| WOFF2 collection (`ttcf`) | `unsupportedFormat`, no charge left |
| Bad header, directory, padding, transform, Brotli stream, checksum or size | `malformed`; all conversion charges retired |
| Table/stream/total/count cap | `limitExceeded`; all conversion charges retired |
| Conversion reservation does not fit | `ReaderResourceException(budgetExceeded)`; never converted to missing-font fallback |
| Process byte/face cap | `SceneAdmissionException(processFontExhausted)` before registration; propagates |
| Ordinary conversion/native failure, `requiredFonts: false` | `FontLoadRecord(loaded: false, failure: <type name>)`, reflow family fallback |
| Same failure, `requiredFonts: true` | `RequiredFontException(cause)`; no silent substitution |
| Cancellation | Waiter gets `ProcessFontLoadCanceled`; conversion and registration continue and drain |

## 5. Good/Base/Bad Cases

Good: a transformed WOFF2 converts to an SFNT whose Paragraph and HarfBuzz
advances equal the original SFNT's and differ from the absent-family control.
Base: a null-transformed WOFF2 (all tables stored) converts byte-identically per
table. Bad: calling `loadFontFromList` on WOFF/WOFF2 bytes, accepting the
callback as proof of use, disposing the `ConvertedFont` when the waiter is
canceled, or hand-editing the generated dictionary file.

## 6. Tests Required

Keep, under `test/features/reader/engine/layout/`: `brotli_decoder_test`,
`woff_decoder_test`, `woff2_{decoder,directory,transforms,harfbuzz}_test`,
`font_admission_test` (typed pre-registration failure, rollback, retained
buffers during pending shared registration, release only after drain, native
failure). `woff2_harfbuzz_test` opens converted buffers with the host HarfBuzz
module and compares glyph IDs, clusters, advances and offsets with the SFNT
control. `svg_feature_text_test` ("WOFF2 faces convert and shape like their SFNT
control") covers the fixed SVG text route. Run the dictionary check from the
repository root:

```bash
dart run tool/fonts/brotli_dictionary.dart --check
flutter test test/features/reader/engine/layout
```

Vectors in `test/fixtures/reader/fonts/` are committed bytes; tests execute no
compressor and load no native Brotli library. Their provenance (offline Brotli
1.2.0 CLI, qualities 0/1/4/5/6/9/11, every window 10..24, bit-level HSKIP and
metadata frames, all 121 transform IDs, a forward-transformed Roboto WOFF2 with
glyph-by-glyph comparison to the pinned SFNT) and the regeneration commands are
in that directory's `README.md`; generators need Python 3 and a Brotli CLI only
when intentionally regenerating (`generate_brotli_vectors.py`,
`generate_dictionary_vectors.py`, `generate_woff2.py`, repository root). A
regeneration must be byte-identical unless the generator changed.

## 7. Wrong vs Correct

```dart
// Wrong: registration callback completion is not format support.
await ui.loadFontFromList(woff2Bytes, fontFamily: alias);

// Correct: convert, admit the converted bytes, keep the charge through drain.
final converted = Woff2Decoder(maxBytes: registry.maxFontBytes)
    .decode(bytes, budget: registry.conversionBudget);
try {
  alias = await processBudget.load(converted.bytes, face: descriptor, register: register);
} finally {
  converted.dispose();
}
```

Wrong: size a WOFF2 buffer after decoding or grow a list while decoding.
Correct: reserve the stream, scratch and exact SFNT bytes before each allocation
and retire every charge on any exception.
