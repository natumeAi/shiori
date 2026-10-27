# S3 contract audit

Inspected 2026-10-26; local source is authoritative for current contracts.
Reference checkout: clean, `a4bda23fd3e82e285a22566d88576e67d3e8756b`,
package version 3.3.0. shiori HEAD: `f1220fa`. No live NAS request was made.
All `server/` and `shared/` paths in this file belong to the read-only
`D:/Projects/lan-reader`; `lib/` paths belong to shiori.

## Existing transport and boot

- `lib/core/config/env.dart:4` reads `API_BASE_URL`; build ID/number are
  separate and must remain.
- `lib/core/network/dio_provider.dart` constructs one compile-time Dio with
  10-second connect/20-second receive timeout. Debug LogInterceptor can expose
  request paths even with headers disabled; runtime private endpoints need a
  redacted logger.
- `lib/core/network/guard_dio.dart` maps most Dio failures, including
  cancellation and bad certificates, to NetworkException. That is unsuitable
  for session switching/retry and needs explicit classification.
- `lib/core/network/retry_policy.dart` retries only NetworkException, up to
  three times. Preserve this retry distinction rather than retry all failures.
- `lib/app/routes.dart:7` exposes only placeholder HomeRoute. There is no
  existing product setup/library behavior to preserve.
- `tool/ci/build_ios_unsigned.sh:87` hardcodes `lib/main_probe.dart`.
  `.github/workflows/ios-unsigned.yml` uses the same script and run counter.
  A product-entry build selector is necessary for S3 device acceptance.

## Required reads

| Source | Contract |
| --- | --- |
| `server/src/app.ts:73` | Health returns status, service and database. HTTP 200/database unconfigured is not a usable connection. Optional future fields must not become prerequisites. |
| `server/src/routes/library.ts:20` | Snapshot sets private/no-cache, ETag and X-Library-Revision; exact If-None-Match may return a bodyless 304 before building payload. |
| `server/src/services/librarySnapshot.ts:34` | ETag is a quoted library revision, not file identity. |
| `server/src/services/librarySnapshot.ts:73` | Snapshot assembled transactionally; includes all books, normalized folders, ordered shelf and recent. |
| `server/src/routes/books.ts:109` | GET /api/books returns only root books unless folderId supplied; it cannot stand in for the complete snapshot. |
| `server/src/routes/books.ts:121` | /catalog is a separate flat list; not required by S3's snapshot-driven list. |
| `server/src/routes/books.ts:130` | Detail envelope is {book}, with missing Book 404. |
| `server/src/routes/books.ts:207` | File route returns original application/epub+zip through sendFile with private/no-cache. |
| `server/src/services/bookLibrary.ts:134` | Cover URLs are served /covers paths; storage coverPath is not a request URL. |
| `server/src/app.ts:63` | Thumbnail static route is immutable/year cached; ordinary /covers is separate. Transport/prefix scoping still applies. |

S3 does not implement POST/PATCH/PUT/DELETE requests. Snapshot and detail are
sufficient for its list/folder/preparation views. Reading position/activity,
goals/statistics, upload and library mutations are later-stage owners.

## Wire model distinctions

- `shared/src/librarySnapshot.ts:19`: schemaVersion 1, version, books,
  folders, shelf, recent. Unknown schema cannot be decoded as current.
- `shared/src/book.ts:12`: full Book includes description, publisher,
  language and thumbnail storage paths as well as common metadata.
- `shared/src/book.ts:60`: SnapshotBook lacks those detail fields and adds
  readingProgress/readingUpdatedAt. Preserve null progress versus numeric zero.
- `shared/src/folder.ts:30`: SnapshotFolder carries ordered bookIds,
  previewBookIds and bookCount, not embedded full Book records.
- `shared/src/shelf.ts`: snapshot shelf entries are typed ID references;
  a book ID and folder ID may be numerically equal without being the same key.
- `server/src/db/migrations/001_initial_library_schema.sql:5` and `:23`
  use CURRENT_TIMESTAMP (`YYYY-MM-DD HH:mm:ss`, UTC).
  `server/src/routes/reading.ts:208` writes reading positions using
  `strftime('%Y-%m-%d %H:%M:%f', 'now')`, emitting UTC
  `YYYY-MM-DD HH:mm:ss.SSS` in SnapshotBook.readingUpdatedAt and
  recent[].progress.updatedAt. The initial audit and C1 converter missed this
  fractional form; corrected after the 2026-10-27 device-run finding.
  Accept space-separated UTC timestamps with optional 1–9 fractional digits;
  the same fractions are accepted with `Z` or explicit `+/-HH:mm` offsets
  (space or `T` separator). Offset-free `T` remains invalid. Retain the first
  six fractional digits, padding shorter fractions to microseconds; discard
  further digits without rounding or carrying into another second. Keep raw
  strings unchanged where later acknowledgment comparisons depend on exact
  representation; chronological comparisons use the converted UTC instant.
- IDs, revisions and sizes must be safe integers, not rounded doubles.
  Nullable required fields are not silently supplied when absent.

The reference decoder deliberately validates only consumer-indexed identity
fields (`shared/src/librarySnapshot.ts:48`). The backend formatter emits the
full declared shape. S3's checked DTOs validate that actual shape; do not infer
a permissive contract for arbitrary partial third-party servers. Ignore
unknown additive fields and report incompatible/malformed records clearly.

## File validation and replacement

The parent `research/backend-contract-audit.md` audited the same unchanged
commit and installed Express/send/etag implementation. Reuse its full route
inventory and file findings:

- ETag/Last-Modified/HEAD/range already exist. File ETag is derived from size
  and mtime, not cryptographic bytes. Preserve quotes and W/ opaquely.
- A conditional 304 has no body. It cannot repair an absent or corrupt cache.
- S3 uses full downloads and handles unexpected range/precondition responses
  without publishing a partial file; range resume is not required.
- Imported Book ID plus endpoint identifies the record. Publication identifier,
  filename/title, updatedAt, thumbnail version and snapshot revision are not
  content digests. A byte digest identifies a downloaded generation.
- Metadata-preserving remote replacement can escape the existing validator.
  Explicit refresh is the supported fallback. Stronger identity remains in
  the parent's optional backend handoff, not a new unconditional dependency.
- 404/deletion or a new digest never authorizes deleting future checkpoint/
  outbox state. Revalidation and accepted-position proof belong to S4.

## Prefix, stale work and storage implications

Use deployment-root relative API and cover resolution. `/api/...` resolved
as an origin-root URI would lose a configured prefix. Preserve URL-encoded
resource paths rather than applying EPUB-internal path helpers:
`lib/features/reader/data/epub/epub_url.dart:12` is explicitly package-relative
and has different query/decoding semantics.

Every cache/provider/file/worker result is scoped to normalized endpoint and
activation generation. CancelToken alone cannot prevent a response already
in flight/decoded from publishing; check generation at commit/publication.
The same endpoint reactivated later is a new generation.

SQLite snapshot and file metadata storage must keep validators paired with
the exact cached representation. Network HTTP metadata and local byte identity
are separate facts. S3 adds no statistical cache invalidation rule.

## Parent handoff conclusion

No unconditional backend change is established by this audit. Continue using
the existing API. Health capability metadata and strong content identity are
optional recommendations already described in
`../10-22-flutter-lan-reader-parity/backend-handoff.md` (path relative to the
child task root). Live compatibility/proxy checks remain device integration
evidence, not facts inferred from this local source.

