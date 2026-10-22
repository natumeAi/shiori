# lan-reader changes for the shiori client

This document is for the user to implement separately in
`D:/Projects/lan-reader`. No changes there have been made by this task.
Baseline: inspected local version 3.3.0; the NAS version is not yet verified.
Detailed source anchors and existing test suites are in
`research/backend-contract-audit.md`.

## 1. What can remain unchanged

The first native vertical slice can use the current APIs:

| Purpose | Existing endpoints |
| --- | --- |
| Connection/database probe | `GET /api/health` |
| Library snapshot | `GET /api/library/snapshot` with ETag/304 |
| Books/details/upload/file | `/api/books`, `/api/books/catalog`, `/api/books/:id`, `/api/books/:id/file` |
| Mixed shelf/folder operations | `/api/folders/shelf`, folder order/import/move and batch routes |
| Position and recent reading | `GET/PUT /api/reading/:bookId`, `/api/reading/recent` |
| Goals/home/period statistics | `/api/reading/goals`, `/api/reading/stats`, `/api/reading/statistics` |
| Reading activity | `POST /api/reading/activity` |

Native Flutter must implement the existing CFI and text-normalization
contracts. Different line/page breaks do not by themselves require a new
position format, server-side pagination, a canonical-text service, or database
migration. Reader appearance remains device-local as it is in the web app.
Native networking does not require browser CORS changes.

The file endpoint already supplies standard validators through Express
`sendFile`; adding ETag support is not a missing prerequisite. The client must
properly handle 304/HEAD/partial responses and its local cache.

## 2. Recommended: explicit service compatibility information

**Priority:** small useful enhancement, not a blocker for the first client.

Extend the existing `GET /api/health` response additively:

```json
{
  "status": "ok",
  "service": "epub-reader-server",
  "database": "ok",
  "appVersion": "<actual deployed build version>",
  "apiVersion": 1,
  "readingTextNormalizationVersion": 1,
  "capabilities": [
    "library-snapshot-v1",
    "reading-activity-v1",
    "activity-local-hour-v1",
    "reading-statistics-v1"
  ]
}
```

- Preserve the three existing fields and their semantics. Do not return a
  false success for an unavailable/unconfigured database.
- Read the actual build version; do not hardcode the example placeholder.
- Advertise only contracts implemented by the deployed build. Future changes
  must not reuse a capability name for incompatible semantics.
- No DB migration is needed. Native falls back to read-only shape checks
  when these additional fields are absent; old web clients remain compatible.
- Likely files: `server/src/app.ts`, version/build metadata wiring, health
  tests; shared types only if the health DTO is formalized.
- Validate old/new responses, omitted/unknown capabilities, DB failure, and
  that an old web client still works.

## 3. Recommended: explicit EPUB content identity

**Priority:** robustness enhancement; necessary only if guaranteeing detection
of replacements that preserve size and mtime.

Existing file ETags are based on file size and modification time. Neither
book `updatedAt` (also changed by sorting/moves) nor the global library
revision is an EPUB-byte identity.

Proposed additive contract:

- Full/catalog/snapshot Book DTOs gain optional nullable
  `contentVersion: "sha256:<64 lowercase hex>"`.
- `GET/HEAD /api/books/:id/file` exposes the same value in
  `X-Content-Version` when known. Keep the endpoint and existing validators.
- Compute the digest for imported/replaced EPUB bytes and backfill existing
  rows. A nullable column during migration permits old records/clients.
- The advertised digest and served bytes must be from the same published
  file generation. Use atomic file publication/versioning or an equivalent
  verified scheme; do not hash one generation and serve a later one.
- To cover same-size/same-mtime replacement, define actual change detection
  beyond the current metadata shortcut. Storing a digest behind that same
  shortcut does not solve the problem.
- Duplicate imports retain separate Book IDs even with identical digests.
  Native keys content under endpoint + Book ID + digest.
- Native invalidates derived layout/source caches on a changed digest,
  verifies the existing CFI against new content, and preserves unresolved
  progress. Do not automatically migrate old read coverage to changed text.
- Likely files: additive DB migration, import/watcher/storage services,
  `shared/src/book.ts`, book/snapshot formatters and file route.

Validation: reorder/move does not change digest; changed bytes do; duplicate
imports remain independent; old clients ignore extra fields; interrupted
replacement cannot mix byte generations; conditional GET/HEAD still work.
Without this enhancement, use current HTTP validators, client byte digests,
and explicit refresh, with the metadata-preserving replacement limitation
documented.

## 4. Conditional: conflicting reading-position writes

**Priority:** only if adding a stronger multi-client/offline-write guarantee
than the current web product. Do not make this an automatic first-release
backend dependency.

Current `PUT /api/reading/:bookId` is an unconditional replacement. Sequential
browser/app use is supportable, but parallel sessions can overwrite each
other. A client GET-before-PUT cannot eliminate the race, and maximum progress
would incorrectly reject intentional backward reading.

If stronger concurrency is required, implement a compatible CAS extension:

1. Store a monotonic `positionRevision`; expose a dedicated response ETag for
   position reads/writes, including revision zero for an existing book with
   no saved position. Do not use timestamps or library revision as the token.
2. Native `PUT` sends `If-Match`. Compare and update in one DB transaction.
   Success increments once; mismatch returns 412 with
   `code: "READING_POSITION_CONFLICT"` and makes no write.
3. Preserve old `PUT` requests without the precondition, but increment their
   revision too, so they invalidate stale native tokens.
4. Full all-client protection additionally requires the browser to use CAS;
   unconditional legacy writers can still overwrite a newer value.
5. Advertise `reading-position-cas-v1` only when implemented. On an uncertain
   successful write, re-read/compare after a failed retry rather than force an
   overwrite. Keep explicit conflict/recovery UX in a separately reviewed
   scope if needed.

Validate first save, two writers, same-millisecond updates, backward turns,
timeout after commit, old web writes, missing books, migration and no mutation
on precondition failure.

## 5. Separate implementation request

The most useful first backend task is section 2 alone: add health version and
capability information, preserve old behavior, and test it. Section 3 may be
implemented independently if robust content replacement is desired. Section 4
is conditional and should not be bundled into the compatibility-report task.

No change is currently requested to authentication, CORS, EPUB rendering,
reader-settings synchronization or the existing statistics normalization.
The app's first integration can proceed against the existing API while these
enhancements remain optional.
