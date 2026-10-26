# S3 storage, import and platform research

Date: 2026-10-26. Findings distinguish inspected code, external documentation
and proposed engineering decisions. No package installation, prototype,
native build or physical-device test occurred during planning.

## S1/S2 carry-forward

S1 is archived at `archive/2026-10/10-22-ios-free-device-bootstrap`.
S2 is archived at `archive/2026-10/10-22-native-reader-feasibility`; its
`feasibility-report.md:240` records the conditional S4 GO and seven conditions.

The S3-owned item is explicit at that report's line 562: bounded/streamed
inflation and worker parsing before downloaded books. Other S4 items remain:
admission/dirty-drag evidence, memory/native ring investigation, real OS
recovery, mixed-layout explanation, fonts/assets/parser/warm-prepare hardening,
and the default FlutterMetalLayer product path. S3 does not rerun/waive them.

## Existing storage and resource ownership

- `lib/core/storage/app_directories.dart:8` provides Application Support and
  Documents through an injectable interface; extend it with Caches.
- `lib/features/diagnostics/data/probe_book_repository.dart` lists bundled
  fixtures and user-imported Documents EPUBs. This is a probe workflow, not a
  suitable product cache or a new dependency from reader to diagnostics.
- `lib/features/diagnostics/data/book_digest.dart` computes SHA-256 from an
  entire in-memory Uint8List plus padded copy. Do not import this diagnostic
  implementation into product streaming download code.
- Documents is exposed through iOS File Sharing; private endpoint/database/
  cache content must remain in Support/Caches.
- `lib/features/reader/engine/pagination/section_preparer.dart:40` accepts an
  EpubBook; line 238 reads archive bytes for image layout.
  `prepared_section.dart:100` also reads archive bytes for image leasing.
  A worker returning a lazy EpubBook would not remove subsequent root-isolate
  decompression. S3 must define a bounded preloaded source/resource adapter
  and hand it to S4, which owns full reader integration.
- `CssStyleResolver` is pure Dart, but paragraph/font/image/picture work is
  rooted in dart:ui. Do not treat all reader preparation as worker-transferable.

## Archive audit qualification

The S2 report describes declared limits plus a post-expansion length check.
The application still has those checks:
`lib/features/reader/data/epub/epub_archive.dart:9` defines 256 MiB compressed,
20,000 entries, 64 MiB entry and 1 GiB declared total;
line 39 invokes ZipDecoder before app count checks;
line 82 calls readBytes before checking the returned length.

However, the locally resolved archive 4.5.2 source already has partial
protections. The inspected package root is
`C:/Users/H3C/AppData/Local/Pub/Cache/hosted/pub.dev/archive-4.5.2`:

- `lib/src/codecs/zip/zip_file.dart:239` uses decodeLimited against declared
  uncompressedSize; getStream preallocation is bounded by a compressed-size
  ratio as well as its own threshold.
- `lib/src/codecs/zlib/_zlib_decoder_io.dart` drives NativeChunkDecoder,
  whose output is forwarded chunk by chunk.
- `lib/src/util/_limited_output_stream.dart` checks actual output writes and
  rethrows a swallowed limit failure.
- `lib/src/codecs/zip_decoder.dart:70` eagerly reads symbolic-link contents
  while creating the Archive, before EpubArchive's app checks.
- The same decoder's CRC verification block is commented out; passing
  verify:true alone is not proof of CRC validation.
- Decoder duplicate-name coalescing and the reader spec's last-duplicate rule
  need an explicit oracle regression; do not assume the high-level Archive
  list represents every raw directory entry.

Therefore preserve the S2 prerequisite but refine the mechanism: verify the
clean lockfile-resolved implementation and reuse its tested bounded APIs;
enforce app limits before decoding symlink contents and before accumulating
output, count raw entries/aggregate output, and prove corrupt/truncated/CRC/
duplicate behavior. A method named decodeStream is not sufficient evidence.
No package vulnerability or peak-memory result is asserted from this source
inspection alone. This is an implementation proof gate, not a reason to replace
the ZIP library in planning.

The worker also needs bounded resource discovery. EpubSectionLoader discovers
the referenced resources across spine sections to preserve reference token
ordinals. Preserve alias ordering/source offsets while streaming or releasing
temporary bytes; do not approximate the resource graph to obtain low memory.

## Storage/worker choices

Propose one SQLite database owner in a background isolate, typed asynchronous
commands and explicit schema migrations. A small schema does not need another
ORM/code generator. S3 creates only configuration/snapshot/cache records; S4
owns checkpoint/activity/outbox schema additions and atomic business writes.

The sqlite3 maintainer's documentation states that its current 3.x package
bundles SQLite through native hooks, supports iOS and Windows, and exposes
synchronous calls. This supports a background owner rather than UI-thread
SQL. The package page observed during this session lists 3.8.0/MIT.
This is research, not a selected/resolved project pin: confirm compatibility
with Flutter 3.47.7/Dart 3.13.5 and existing lockfile in Phase A, then verify
actual iOS packaging through the existing cloud workflow.

The official Dart crypto package supports chunked SHA-256 and lists 3.0.7/
BSD-3-Clause; that version is already resolved transitively in shiori.
Promoting it to a direct dependency avoids another whole-input hash copy.

Flutter documentation confirms that worker isolates exchange messages and
cannot perform dart:ui work. A long-lived worker keeps archive/source ownership
off the root; typed request IDs, cancellation/exit listeners and bounded byte
transfers are application design obligations. No SQLite handle, callback or
Flutter-owned resource is transferred.

## iOS network and build evidence

Apple TN3179 states that outgoing local-network TCP requires local-network
access, with checks below individual APIs. Native Dart networking does not
remove that permission requirement. Add the purpose description and exercise
grant/denial/re-enable/retry on the real phone. Socket failure alone does not
prove which privacy setting is responsible.

Existing Info.plist has file-sharing/high-refresh declarations but no local
network purpose key. Existing build script always selects main_probe.dart;
an allowlisted app target is required before claiming S3 phone acceptance.

Do not infer ATS policy from the URL scheme alone or from a browser test.
Verify the actual Dio/cover transports. The plan does not add global ATS
exceptions, bypass certificates, introduce Bonjour or require server CORS.
Host tests prove request/status/state logic; CI proves compilation; only
device evidence proves the permission and installation paths.

## External primary sources consulted

- SQLite Dart package and maintainer docs:
  `https://pub.dev/packages/sqlite3`
  `https://pub.dev/documentation/sqlite3/latest/`
- Dart team crypto package, chunked hashing:
  `https://pub.dev/packages/crypto`
- Flutter isolate constraints:
  `https://docs.flutter.dev/perf/isolates`
- Dart isolate lifecycle APIs:
  `https://api.dart.dev/dart-isolate/Isolate-class.html`
- Apple local-network privacy:
  `https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy`

The archive web API page exposed a different documented version from the
local lockfile, so implementation conclusions above use the actual local
4.5.2 source, not a floating latest API page. SDK/package version selection
and native behavior remain executable gates.

