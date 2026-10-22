# Research: lan-reader backend contracts and native-client handoff

- Query: Which existing lan-reader contracts can a native Flutter client use unchanged, and which backend changes are actually needed?
- Scope: mixed; source audit of the read-only D:/Projects/lan-reader checkout plus official HTTP/platform documentation. Output ownership is this file only.
- Date: 2026-10-22 (UTC)

## Findings

### Evidence boundary and conclusion

The inspected local package version is **3.3.0** (package.json:3, server/package.json:3). The lockfile resolves Express 5.2.1, send 1.2.1 and etag 1.8.1. The NAS deployment version, proxy configuration, live responses and installed iOS version were not verified. All relative reference-code paths below start at **D:/Projects/lan-reader**; shiori paths are explicitly identified.

The existing API can support a native client without a replacement API, authentication redesign, server-side EPUB renderer, canonical-text service, or reader-settings endpoint. No unconditional backend source change is established merely by changing the client to Flutter. Native CFI and canonical-text equivalence are client implementation/fixture gates. Existing file HTTP validators are real, but not cryptographic content identities. Existing reading-position writes have no optimistic concurrency protection; a client-side preflight cannot eliminate that race.

### Files found and related specs

| File/group | Purpose |
| --- | --- |
| server/src/app.ts; http/requestInput.ts; http/httpError.ts | Mount paths, health, JSON limits, common validation/status/error envelopes. |
| server/src/routes/{library,books,folders,reading}.ts | Authoritative route registrations, request bodies and response envelopes. |
| shared/src/{api,book,folder,shelf,librarySnapshot,reading}.ts | Camel-case wire models, snapshot schema, chapter tuple. |
| shared/src/{readingStats,readingStatistics}.ts | Activity limits/decoders, dates, goals, statistics shapes and invariants. |
| server/src/services/{bookLibrary,folderLibrary,librarySnapshot,readingLibrary,readingStats,readingStatistics}.ts | Membership, file replacement, revision, progress, idempotency and aggregation semantics. |
| server/src/db/migrations/{001,005,006,007,008}_*.sql | Book identity, cascading deletions, library triggers, statistics and chapter migrations. |
| client/src/utils/{canonicalText,readingActivity,activityOutbox,activityDelivery,chapterProgress}.ts | Required web-compatible normalization, sampling/completion and retry behavior. |
| client/src/api/{transport,libraryApi,readingApi,booksApi}.ts | Existing root-relative URLs, 304 handling and serialized event transport. |
| node_modules/{express,send,etag}/…; package-lock.json | Checked installed HTTP implementation rather than assuming sendFile lacks validators. |
| .trellis/spec/backend/{index,reading-statistics-contract,database-guidelines,error-handling}.md | Reference backend contract ownership and compatibility rules; statistics contract read in full. |
| shiori .trellis/spec/flutter/{index,data-layer,error-handling}.md | Retain repositories, Dio and typed errors; runtime endpoint/persistence additions require task-specific spec updates. |
| shiori .trellis/spec/guides/cross-layer-thinking-guide.md | Trace JSON/parse/state boundaries; source identifiers remain authoritative. |
| This task's prd.md and research/{reference-audit,native-reader-options,reader-fidelity}.md | Accepted native reflow/EPUB scope and prior reconnaissance; this audit supplies exact backend details. |

### Common HTTP contract

- Paths in the following tables are relative to the backend deployment root. The server mounts /api/books, /api/folders, /api/library and /api/reading (server/src/app.ts:84).
- JSON field names are camelCase. Successful JSON responses use the specific envelope in the table, not a universal data wrapper. Default success is 200; book upload and folder creation return 201. Error body is {error: string, code?: string}; status 500 hides the message as "Internal Server Error"; code is included only below 500. A 503 from absent DB is {error:"Database is not configured"}. Unknown routes return 404 {error:"Not Found"} (app.ts:96,105; http/requestInput.ts:47).
- JSON body limit is 1 MB; malformed JSON is 400 and excessive JSON is 413 through Express middleware. Multipart EPUB upload has its own file-size limit (app.ts:63; routes/books.ts:49,74).
- Non-batch legacy ID parsers coerce via Number() and require positive integers, so the server accepts more than numeric JSON values. Flutter should send positive safe integers and ordinary decimal path IDs; do not depend on coercion. Arrays reject duplicate normalized IDs. Batch bookIds must have 1–1000 entries (http/requestInput.ts:71,93,109; shared/src/api.ts:74).
- Most 400/404/409 errors have no code; do not require one. Relevant codes are listed below. File middleware may produce additional HTTP statuses. Treat HTTP status before choosing JSON vs EPUB decoding.
- No app authentication or CORS middleware is installed in createApp (app.ts:57–87). This describes the app, not an unknown NAS proxy. Native Dio does not require browser CORS headers. Do not add an auth/CORS project solely for native access.
- Ordinary JSON responses inherit Express weak response ETags, but only the snapshot has an application revision/cache contract. No route implements If-Match for mutations. Avoid conditional caching on progress/statistics until the client explicitly supports their response-cache semantics (node_modules/express/lib/application.js:95; response.js:168–216).

### Health, snapshot, books and files

| Method/path | Request | Success and important failures |
| --- | --- | --- |
| GET /api/health | None | 200 {status:"ok",service:"epub-reader-server",database:"ok" or "unconfigured"}. A real DB probe runs SELECT 1; a DB exception becomes 500. Thus HTTP 200 alone is insufficient; require database=="ok". No version/capabilities now. app.ts:73; db/database.ts:93. |
| GET /api/library/snapshot | Optional If-None-Match | 200 {snapshot:{schemaVersion:1,version,books,folders,shelf,recent}}, or 304 with no body. Cache-Control: private, no-cache; ETag: "library-N" (quotation marks included); X-Library-Revision: decimal N. Exact string match is the explicit fast path before building payload. routes/library.ts:20; services/librarySnapshot.ts:25,33,72. |
| GET /api/books | Optional folderId positive integer query | {books:Book[]}. No folderId means root shelf books only; a folderId filters membership and may return [] even if that folder is missing. /catalog is the flat all-book list. routes/books.ts:109; services/bookLibrary.ts:154. |
| GET /api/books/catalog | None | {books:CatalogBook[]}, all books by ID; adds folderName, readingProgress, readingUpdatedAt (each nullable). routes/books.ts:121; services/bookLibrary.ts:180. |
| GET /api/books/:id | None | {book:Book}; invalid ID 400; missing ID 404 "Book not found" without a code. routes/books.ts:130. |
| PATCH /api/books/order | {bookIds:[…]} | {books:Book[]}; requires exactly the current root-book membership, no folder entries. Stale membership gives 409 "Book order is out of date". Empty array is valid only when root-book set is empty. Prefer the mixed shelf route for the actual bookshelf. routes/books.ts:146; services/bookLibrary.ts:200. |
| POST /api/books | multipart/form-data, exactly one file field named file, with .epub filename | 201 {book:Book}; default ceiling 100*1024*1024 bytes, EPUB_UPLOAD_MAX_MB configurable. 400 for missing file, unsupported filename, Multer errors (e.g. LIMIT_FILE_SIZE), invalid EPUB (INVALID_EPUB). Actual archive parsing/validation follows extension screening; multiple uploads are separate requests. Not idempotent: uncertain upload retries may create another Book. routes/books.ts:49–105,158; services/fileStorage.ts:203; services/bookLibrary.ts:237. |
| GET /api/books/:id/file | Optional conditional/range headers | Original EPUB bytes, Content-Type: application/epub+zip, Cache-Control: private, no-cache. Missing book 404. Standard sendFile validators/HEAD/range behavior below. routes/books.ts:207. |
| DELETE /api/books/:id | None | {book:Book} containing deleted metadata; missing 404. Removes managed file, DB record and associated progress/statistics; deletion is not an undoable server operation. routes/books.ts:235; services/bookLibrary.ts:469; migrations/001:28 and 006:26. |
| POST /api/books/batch-delete | {bookIds:[…]}, 1–1000 unique | 200 {deleted:Book[],failed:[{id,message}]}; attempts each ID independently, including later IDs after a failure. Earlier deletes are not rolled back. Missing IDs appear in failed, not a whole-request 404. routes/books.ts:225; services/bookLibrary.ts:487. |

Book fields (shared/src/book.ts:12): id, folderId (nullable), title, author/description/publisher/language/identifier (nullable), fileName, fileSize, coverPath/coverUrl (nullable), coverThumbnailSmallPath/coverThumbnailLargePath/coverThumbnailUrl/coverThumbnail2xUrl/coverThumbnailVersion (nullable), sortOrder, createdAt, updatedAt. identifier is publication metadata, **not Book identity**. Duplicate imports intentionally remain distinct. SnapshotBook omits description/publisher/language and thumbnail storage-path fields; adds readingProgress/readingUpdatedAt. Do not decode a snapshot book as a full detail record.

Snapshot folders contain id,name,sortOrder,bookCount,bookIds,previewBookIds,createdAt,updatedAt; bookIds are ordered, previewBookIds are the first four. Shelf entries are {type:"book"|"folder",id,sortOrder} references. Recent entries are {bookId,progress}. Books arrive by ID; folder books by sortOrder then ID; mixed shelf by sortOrder, then type, then ID. Recent excludes progress>=1, returns up to 10, ordered updatedAt DESC then bookId DESC (shared/src/librarySnapshot.ts:19; services/librarySnapshot.ts:61–136; services/readingLibrary.ts:49).

Library revision increments for insert/update/delete on books, folders and reading_progress, not activity/goals/statistic writes. Therefore a snapshot 304 says nothing about whether statistics changed. Even reordering invalidates the snapshot (migrations/005_add_cover_thumbnails_and_library_revision.sql:13–65; migrations/006 and 008).

### File validators, cache identity and replacement

The current route already supports ordinary conditional download. Express sendFile enables send's ETag (node_modules/express/lib/response.js:406); send defaults ETag/Last-Modified/Accept-Ranges on (node_modules/send/index.js:102,110,134), supplies Last-Modified and ETag unless already set (send/index.js:736), and preserves the route's private,no-cache header. Its file ETag is weak and derived from hexadecimal size + mtime milliseconds, not file bytes (node_modules/etag/index.js:70,126).

- Conditional GET can return 304; failed conditional preconditions can return 412. One satisfiable byte range returns 206 with Content-Range; an unsatisfiable range returns 416. Invalid or multiple uncombined ranges fall back to a full response. HEAD returns headers without a body. Compression/proxy behavior can affect transferred Content-Length; do not use it as a content hash (send/index.js:513–591; app.ts:62).
- Store the returned ETag opaquely, preserving quotes and W/. Revalidate downloaded content on connected open using If-None-Match; only reuse on 304 if a validated local EPUB and associated cache record exist. Otherwise request an unconditional full download. Support a manual unconditional refresh when identity is doubtful.
- Cache namespace must include normalized deployment endpoint (scheme/host/port/path prefix) and bookId. Native derived data also needs actual downloaded-byte digest, parser/normalization version and layout settings. Identifier, title, filename, fileSize alone, coverThumbnailVersion, book.updatedAt, and library revision are not sufficient file identity.
- Ordinary import/startup scans detect unchanged files by file size + truncated mtime. The directory watcher's observed change event explicitly forces a refresh, but the file HTTP ETag still depends only on size/mtime. Updating the same stored path preserves its Book ID, progress and statistics; different imports create different IDs. Metadata-preserving replacement can evade an ordinary scan (for example after downtime) and the weak ETag. Reordering/moving also changes book.updatedAt, so updatedAt is not a dedicated content revision (services/bookLibrary.ts:279–295,316–358; :200–231; services/bookDirectoryWatcher.ts:109; services/folderLibrary.ts:275).
- Native client must invalidate parsing/page/CFI-derived caches after actual bytes change, verify any saved CFI against the new document, and keep an unresolved saved position intact until recovery is explicit. Existing activity section signature mismatch already prevents combining incompatible canonical offsets, but does not remap old statistics or anchors.

### Folder and shelf mutations

F = full Folder {id,name,sortOrder,bookCount,previewBooks:Book[0..4],createdAt,updatedAt}; S = full shelf item {type,id,sortOrder,book} or {type,id,sortOrder,folder}. All following return 200 except creation (201). No standalone DELETE-folder or restore/deletion-undo endpoint exists.

| Method/path | Body | Envelope and semantics |
| --- | --- | --- |
| GET /api/folders | None | {folders:F[]} |
| GET /api/folders/shelf | None | {items:S[]} |
| PATCH /api/folders/shelf/order | {items:[{type:"book" or "folder",id}]} | {items:S[]}; exactly current mixed shelf membership, unique typed keys; 409 if stale. |
| POST /api/folders | {sourceBookId,targetBookId,name?} | 201 {folder:F,books:Book[],shelfItems:S[]}; two distinct root books required; source becomes first, target second; folder occupies target's shelf order. Same IDs 400; missing book 404; already-in-folder 409. |
| GET /api/folders/:id | None | {folder:F}; missing 404. |
| PATCH /api/folders/:id | {name} | {folder:F}; name key required (400); missing folder 404. |
| GET /api/folders/:id/books | None | {books:Book[]}; missing folder 404. |
| PATCH /api/folders/:id/books/order | {bookIds:[…]} | {books:Book[]}; exact current folder membership; missing folder 404; stale membership 409. |
| PATCH /api/folders/:id/import-book/:bookId | {} or {bookIds:[…]} | {folder:F,books:Book[],shelfItems:S[]}; only a root book may move in, otherwise 409; appends unless post-move complete order provided. Membership+optional order atomic. Missing book/folder 404. |
| PATCH /api/folders/:id/books/:bookId/move-to-shelf | {} or {items:[…]} | {book:Book,folder:F or null,books:Book[],shelfItems:S[],removedFolderId:number or null}; book must belong to named folder (409 otherwise); defaults to immediately after source folder; optional complete resulting shelf order; removes empty folder and filters it out of requested order. Atomic, stale order 409. |
| PATCH /api/folders/:id/books/batch-import | {bookIds:[…]}, 1–1000 | {folder:F,books:Book[],shelfItems:S[],removedFolderIds:number[]}; accepts root/other-folder sources, skips books already in target, appends in submitted order, removes emptied source folders. Whole transaction rolls back if missing book/folder (404). |
| PATCH /api/folders/shelf/batch-move-out | {bookIds:[…]}, 1–1000 | {shelfItems:S[],removedFolderIds:number[]}; every book must be in a folder; any missing book gives 404 before root-book 409. Each source group keeps its existing folder order and is inserted after the source folder position; emptied folders removed. Atomic. |

Sources: routes/folders.ts:47–203; services/folderLibrary.ts:168,242,308,347,399,447,555. Reorder operations assign (index+1)*1000, not client-supplied sortOrder. Name normalization trims, substitutes "新建文件夹" for non-string/blank, and rejects more than 80 JavaScript UTF-16 code units with 400 INVALID_FOLDER_NAME (folderLibrary.ts:30,49). Flutter should impose the same code-unit limit.

409 checks membership, not a revision: two concurrent reorders of the same set still overwrite each other. Refresh authoritative state on conflict; do not claim general optimistic concurrency. Existing undo calls compensating existing APIs, and is absent for batch deletion or moves whose original folder has disappeared; generic backend undo is not a parity requirement (client/src/hooks/useShelfUndo.ts:122–165).

### Position, goals and recent reading

| Method/path | Contract |
| --- | --- |
| GET /api/reading/:bookId | 200 {progress:null or Position}. It reads only reading_progress and does **not** verify Book existence; unknown/deleted book IDs can also return null. Check book/file separately. Invalid ID 400. services/readingLibrary.ts:16; routes/reading.ts:166. |
| PUT /api/reading/:bookId | JSON {progress,cfi?,chapterHref?,chapterLabel?,chapterCount?,chapterIndex?}; 200 {progress:Position}; missing book 404 BOOK_NOT_FOUND. Finite progress [0,1] required; actual legacy implementation uses Number(progress), so Flutter must validate proper numeric types itself. Text values are stored as supplied or null, not CFI-validated; unbindable object/array values can produce 500. routes/reading.ts:182–221. |
| GET /api/reading/recent | 200 {items:[{book:Book,progress:Position}]}; default limit 10, no query pagination. Same filtering/order as snapshot recent. routes/reading.ts:81; services/readingLibrary.ts:49. |
| PUT /api/reading/goals | JSON {dailyMinutes?,annualBooks?}, at least one; actual safe integer dailyMinutes 1..1440, annualBooks 1..9999. 200 {goals:{dailyMinutes,annualBooks}}; invalid 400 INVALID_READING_GOALS. Omitted setting retained. Defaults 10 minutes / 9 books. There is no separate GET-goals; read stats.goals. routes/reading.ts:131; shared/src/readingStats.ts:34,570; services/readingStats.ts:78. |

Position = {bookId,cfi:string|null,progress:number,chapterHref:string|null,chapterLabel:string|null,chapterCount:number|null,chapterIndex:number|null,updatedAt:string}. The chapter pair is either both absent/both null (unknown), or positive safe-integer count with -1<=index<count. Partial pairs are 400 INVALID_CHAPTER_PROGRESS. Missing legacy pair overwrites old pair with null, so this is full position replacement, not a patch (shared/src/reading.ts:14; server/test/readingPositions.test.ts:96).

The web chapter count comes from unique comparable in-spine TOC boundary CFIs; index -1 means before the first boundary. It is not a native page number and not necessarily the spine count (client/src/utils/chapterProgress.ts:14,25).

Position timestamps are server SQLite UTC text, currently "YYYY-MM-DD HH:MM:SS.SSS" on PUT, with old second-precision rows possible; they are not explicit-zone ISO activity timestamps. Preserve raw timestamp text for comparison and interpret as UTC for display; never use it as a guaranteed unique concurrency token. Backward navigation is valid and deliberately overwrites larger progress. No max-progress merge, client timestamp ordering, device ID, mutation ID, conditional revision or CFI validation exists.

**Client baseline without backend changes:** keep at most one in-flight position write per endpoint/book; coalesce later accepted positions; restore and verify CFI before enabling saves; invalidate callbacks when server/reader session changes. After an uncertain failed write, re-read before deciding what to save. Do not blindly replay an offline position over a newer server position. A local pending checkpoint may be retained as a recovery candidate. This protects against self-generated stale/unverified writes, **not concurrent external writers**. A GET immediately before PUT still has a race. See conditional CAS proposal below.

### Activity: exact immutable event contract

POST /api/reading/activity body:

    {
      "events": [{
        "id": "globally_unique_event_id",
        "bookId": 1,
        "localDate": "2026-10-22",
        "occurredAt": "2026-10-22T02:00:00.000Z",
        "durationMs": 15000,
        "localHour": 22,
        "sections": [{
          "sectionIndex": 0,
          "normalizationVersion": 1,
          "signature": "fnv1a64:0123456789abcdef",
          "sectionLength": 100,
          "intervals": [[0,20],[30,40]]
        }],
        "completion": null
      }]
    }

This is a shape example, not a claim that the sample signature matches a publication. localDate/localHour must be the device-local observation bucket; occurredAt is an absolute instant. They are independently validated, not reconciled to server timezone. Completion when present is {occurredAt,localDate} captured at completion, independent of checkpoint/delivery time.

Validation (shared/src/readingStats.ts:31–76,430–565):

- events length 1..50; globally unique ID string matching [A-Za-z0-9_-]{8,64}. Bad envelope, any unusable ID, or duplicate ID within the batch => whole request 400 INVALID_ACTIVITY_BATCH, no writes.
- Other malformed event fields => a per-event rejected result with reason INVALID_ACTIVITY while valid siblings can commit. bookId is positive JS-safe integer; localDate is a real YYYY-MM-DD date in 1900..9999; occurredAt is a seconds-bearing ISO instant with Z/offset, <=40 chars, valid local/UTC years 1900..9999.
- durationMs is integer 0..86,400,000; optional localHour must be integer 0..23 and reduces the duration ceiling to 3,600,000. Present null is invalid; omit on old records. Missing sections normalizes to []; missing/null completion normalizes to null.
- Maximum 32 sections, no repeated sectionIndex; index 0..100000; normalizationVersion exactly 1; signature ASCII token [A-Za-z0-9._:-]{8,128}; sectionLength 1..10,000,000; each section 1..256 half-open intervals satisfying integer 0<=start<end<=length. Empty/image-only sections cannot be sent as coverage.
- Unknown extra object properties are ignored. Per-section and per-interval array order is preserved in payload hashing, even if the intervals cover the same set.

200 response:

    {"results":[
      {"id":"…","status":"accepted","duplicate":false,"skippedSections":[]},
      {"id":"…","status":"rejected","reason":"INVALID_ACTIVITY"}
    ]}

There is one outcome per event in request order. Permanent rejected reasons are INVALID_ACTIVITY, BOOK_NOT_FOUND, EVENT_ID_CONFLICT. Accepted skippedSections entries are {sectionIndex,normalizationVersion,reason:"SIGNATURE_MISMATCH"}. HTTP 200 does not mean every event or every section was applied (routes/reading.ts:62,151; shared/src/readingStats.ts:138).

Idempotency/aggregation (services/readingStats.ts:108,158,250):

1. Each event is one DB transaction; a later unexpected 500 may occur after earlier events committed.
2. An accepted ID is global to the database, not per book or per client. Same decoded payload returns accepted,duplicate:true and the original skippedSections without incrementing totals. Same ID/different decoded payload is EVENT_ID_CONFLICT. Book existence is checked first; after deletion a replay is BOOK_NOT_FOUND.
3. The server SHA-256 hashes JSON.stringify of a fixed v1 array containing bookId, localDate, occurredAt, durationMs, section values and interval order, completion pair/null; if present it appends ["localHour",h]. Property ordering/ignored extras do not matter, but changing a timestamp's textual representation, intervals/order, or adding localHour does. Native need not send a hash; persist the exact event JSON once and resend unchanged.
4. Coverage storage key is (bookId,normalizationVersion,sectionIndex). First accepted signature+length establishes the bucket; mismatching later signature OR length skips that coverage permanently for that event. Existing and new intervals are unioned, merging overlap/touching; only newly covered characters are attributed to the incoming event.localDate. Re-reading the same interval on another day does not add characters again. Separate devices' unique event durations do add; server does not deduplicate overlapping real-world clock time.
5. Duration and completion still count when some/all coverage is skipped. Never "fix" an already submitted event by changing its payload or minting a replacement ID for the same duration. Surface/suspend incompatible coverage as the web client does.
6. A per-year completion row keeps the earliest captured completion; detail observations preserve every accepted completion, enabling later in-year rereads in period statistics. Reading progress is never updated by activity; reaching progress=1 through PUT alone does not create a new dated completion.

Retry behavior to port: persist before send; acknowledge/remove only attributed outcomes; quarantine permanent rejections; leave missing/malformed/unknown outcomes retryable; split batches on 413 without changing event IDs/payloads; reduce a problematic 400/413 batch to diagnose one record rather than discard all. Reference uses 5s→300s backoff and exact serialized outbox records (client/src/utils/activityOutbox.ts:1,32; activityDelivery.ts:101,114,120,186–223,272). Namespace durable pending/rejected/suspended records by server as well as book.

### Canonical text and activity sampling

The server accepts opaque section signatures and does not independently parse the EPUB to verify them. Matching server normalizationVersion alone is insufficient: Flutter must produce **exactly the web v1 sequence** before writing coverage, or a wrong first signature can block later correct coverage.

Reference algorithm (client/src/utils/canonicalText.ts:22–33,159–200):

- Use original spine-section identity/index. Walk body text nodes in DOM order, falling back to documentElement when no body exists.
- Exclude descendants of script,style,noscript,template and any SVG/MathML namespace ancestor. Do not remove arbitrary hidden/CSS-invisible prose from the coordinate sequence: its positions remain; visibility controls observation only.
- Decode document text consistently; retain punctuation, combining marks and ordinary ruby text. Count Unicode code points, not UTF-16 units, bytes or grapheme clusters. Exclude Unicode White_Space, Cc, Cf and Cs. No NFC/NFKC/case/whitespace insertion normalization occurs.
- Concatenate eligible filtered code points without adding separators; FNV-1a 64-bit over UTF-8, offset basis cbf29ce484222325, prime 100000001b3 modulo 2^64, lowercase zero-padded hex; prefix fnv1a64:. Full-section length/signature are independent of font and pagination.
- Dart must preserve source text/CFI mapping separately from rendered spans. Visible accepted page geometry maps to canonical intervals; prefetch/preview content is not read coverage. Different line/page boundaries are allowed without changing signatures.

Web foreground/checkpoint constants are 15s checkpoint, reject spans over 120s or monotonic/wall drift over 10s. Split accepted time at local hour boundaries (including midnight/DST) with cumulative rounding; time-only events need not contain sections. Completion is a verified navigation from non-final to final page, or first healthy open of a previously unsaved one-page book; restoring at end/reflow/forced snapshots are not completions. These are client semantics, not extra server validation (client/src/utils/readingActivity.ts:32,100,159,318,367).

### Dashboard and period statistics

GET /api/reading/stats?date=YYYY-MM-DD[&bookId=N] returns {stats:{date,goals,days,lifetime,year,currentBook,trackingStartedAt}} (routes/reading.ts:93; shared/src/readingStats.ts:196–246):

- days: exactly seven {date,durationMs,characters} entries, oldest first, ending at requested date, zero-filled.
- lifetime: {durationMs,characters,completedBooks}; global all-time totals, not cut off by date. completedBooks is distinct dated or legacy-completed Book membership.
- year: {year,completedCount,books:[{book,localDate,occurredAt}]}; calendar year of date; earliest completion per book/year, list newest first; count equals list length.
- currentBook: null unless a supplied Book exists, otherwise {bookId,durationMs,streakDays}. duration is all-time for that book; streak ends today if there was positive time today, otherwise yesterday. A missing bookId is not a 404.
- Invalid date or a seven-day window extending before 1900 gives 400 INVALID_DATE; invalid/repeated bookId is 400. Goals come from this endpoint (services/readingStats.ts:330–437).

GET /api/reading/statistics?dimension=day|week|month|year|all&anchor=YYYY-MM-DD&today=YYYY-MM-DD returns {statistics:…}. today is required; anchor is required for non-all and ignored for all. Bad/repeated required parameters or unrepresentable periods => 400 INVALID_STATISTICS_QUERY (routes/reading.ts:116; shared/src/readingStatistics.ts:233).

    statistics = {
      range: {dimension,anchor,start,end,dayCount,today,previousAnchor?,nextAnchor?},
      overview: {durationMs,readingDays,averageDailyMs,longestDayMs,
                 booksRead,booksCompleted,booksInProgress,characters,charactersPerMinute?},
      comparison: null | {previous:null|{start,end,dayCount},
                          metrics:{<each overview metric>:{kind:"delta",delta}|{kind:"unavailable"}}},
      trend: {unit:"hour"|"day"|"month"|"year",buckets:[{key,durationMs}],unknownDurationMs},
      ranking: {entries:[{rank,book,durationMs,characters}],totals:{books,durationMs,characters}},
      completed: {entries:[{book,completedOn?,durationMs,characters}]},
      calendar: null | {days:[{date,durationMs,champion:null|{book,durationMs}}]},
      coverage: {trackingStartedAt,detailTrackingStartedAt?,undatedCompletedBooks}
    }

Here ? denotes a required nullable field, not an omitted field. Numbers are non-negative safe integers except comparison deltas; charactersPerMinute is null when duration is zero. Source of field names/nullability: shared/src/readingStatistics.ts:278–402.

Weeks are Monday–Sunday; day/week/month/year use complete closed periods (even unfinished current periods). all starts at earliest eligible record <=today and ends today. Anchor response is normalized to period start. Trend is 24 hours / 7 days / actual month days / 12 months / contiguous years. Day unknownDurationMs preserves historic daily time without known hours. Ranking entries are at most 20 positive-duration books, but totals cover all books; completed entries are required and uncapped. Month alone has calendar; all alone has no comparison or adjacent anchors. Completion detail uses latest in-range observations; home yearly completion uses earliest-per-year. Do not derive these views from the current reading position or top-20 list. Reference spec .trellis/spec/backend/reading-statistics-contract.md:29–88 supplies metric rules; shared decoder validates cross-field consistency and client API also checks that range matches the actual request (client/src/api/readingApi.ts:20).

### URL resolution and plain HTTP

Current frontend uses leading /api and receives leading /covers URLs; paths are origin-root-relative, and generated cover path segments are already percent-encoded. File URL is constructed from bookId, not supplied in Book. The server has no configured public-base URL or subpath remapping (client/src/api/libraryApi.ts:9; booksApi.ts:4; services/bookLibrary.ts:97,134; server/src/app.ts:64,84). Storage paths such as data/covers/… are not fetch URLs.

Native endpoint recommendation:

1. Persist a deployment root with scheme, authority/port and normalized trailing-slash path prefix; validate http/https, nonempty host, no embedded credentials/query/fragment. Keep the user-entered deployment prefix.
2. Join API suffixes as deployment-relative "api/…" rather than resolving "/api/…" against a prefixed base (which would discard the prefix with ordinary URI resolution).
3. Treat this backend's /covers/… as a backend-root path: prefix the selected deployment path explicitly; preserve percent encoding once. A proxy exposing APIs and covers at different roots needs explicit deployment testing/configuration, not a guessed mapping.
4. Cancel requests and change all provider/cache/outbox namespaces on endpoint change. A stable DB instance ID would help detect database replacement/aliases but does not exist now; endpoint keys are the baseline.
5. Probe health body and actual snapshot/stats/statistics shapes. A reachable HTML login page/SPA, 401/403 proxy response, missing route, DB failure and transport failure are distinct states. Do not "detect compatibility" with destructive mutation probes.

shiori currently uses compile-time Env.apiBaseUrl and a standard Dio provider (lib/core/config/env.dart:4; lib/core/network/dio_provider.dart:11); ios/Runner/Info.plist has neither NSLocalNetworkUsageDescription nor NSAppTransportSecurity. Runtime configuration and local network privacy handling are **client work**.

[Apple local-network guidance](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy) requires a purpose description even for direct unicast local-host access; denial is separate from ATS. User-entered addresses do not need Bonjour browsing or multicast entitlements. Validate the first permission prompt and denied/re-enabled states on the iPhone.

[Flutter network-policy documentation](https://docs.flutter.dev/release/breaking-changes/network-policy-ios-android) distinguishes platform-owned sockets from Dart/Flutter-owned sockets; it explicitly does not claim ATS enforcement at Dart socket level. Thus do not assume a broad NSAllowsArbitraryLoads change is necessary for Dio IO. Verify actual adapter/image-fetch paths in the signed build. If platform-owned transport is introduced, use the applicable scoped local-network/domain policy; [Apple NSAllowsLocalNetworking](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nsallowslocalnetworking) documents OS-specific IP/host behavior. No server HTTPS mandate or CORS rewrite follows from the native-client requirement.

### Minimal backend handoff: classification and precise optional contracts

**Required now:** no backend code modification proven for baseline parity against this checkout. Verify the NAS actually exposes the audited contracts/migrations (especially period statistics completed entries and localHour support). Upgrade/implement missing deployed functionality only if that check fails. Golden Dart/web normalization+CFI tests, client stale-callback guards, typed decoding, runtime endpoint handling and HTTP cache logic are required client work, not reasons to replace backend APIs.

**Recommended small additive enhancement — compatibility reporting.** Extend GET /api/health without removing/changing existing fields:

    {
      "status":"ok","service":"epub-reader-server","database":"ok",
      "appVersion":"<deployed build version>",
      "apiVersion":1,
      "capabilities":["library-snapshot-v1","reading-activity-v1",
                      "activity-local-hour-v1","reading-statistics-v1"],
      "readingTextNormalizationVersion":1
    }

Advertise only implemented capabilities. This is a proposal, not present code. No DB migration required. Older clients ignore extra fields; a new native client can retain read-only shape-probe fallback when fields are absent. Validate exact deployed version, absent/unknown flags, old-client decode compatibility and no false success with database:"unconfigured". Optionally add a persistent opaque instanceId later if identifying the same database across URLs becomes necessary; do not require it just to connect.

**Recommended content identity; required only for a guarantee covering metadata-preserving in-place replacement.** Add contentVersion:"sha256:<64 lowercase hex>" to full/catalog/snapshot books and X-Content-Version to /file; it identifies actual EPUB bytes, not metadata/layout or cover. Existing envelopes/statuses and file validators remain valid. Compute/store during import/backfill and refresh when bytes change, with a defined external-change detection strategy. Merely caching a digest behind the existing size+mtime check does not solve same-size/same-mtime replacement. The file response and digest must describe the same bytes; immutable/versioned file snapshots or verified atomic publication can provide that. Migration can add a nullable digest column/backfill; clients fall back to existing validators until ready. Test reorder/move leaves digest unchanged; changed bytes change it; duplicate imports stay separate IDs; changed file during download cannot produce mixed content/digest. No new download endpoint is necessary.

**Conditional extension — compare-and-set reading position.** Needed if the product promises no stale concurrent writes or automatic offline position replay, neither of which the current API guarantees. Native-only serialization cannot provide this. A minimal compatible proposal:

- Add monotonically incrementing positionRevision (safe integer) to stored progress and JSON. Existing rows begin at 1; an existing book without a position has revision 0 represented by a response-level token.
- GET/PUT /api/reading/:bookId expose a dedicated ETag such as "position-<bookId>-<revision>"; GET null still returns the revision-0 tag for an existing Book. Native persists this opaque token with its accepted checkpoint.
- PUT with If-Match requires exact current position token inside the same DB transaction as the write. Matching token increments once and returns the new position/token. Mismatch => 412 {error:"Reading position changed",code:"READING_POSITION_CONFLICT"} without any write; malformed token => 400 INVALID_POSITION_PRECONDITION. Missing book retains 404 BOOK_NOT_FOUND. Do not use library ETag or timestamp as this token.
- PUT without If-Match preserves legacy unconditional semantics and **still increments** the revision, so an older browser's intervening write invalidates native tokens. Advertise "reading-position-cas-v1" only when this works. Existing browser decoders ignore new fields.
- Full all-client no-lost-update guarantees also require the browser to use CAS; leaving legacy unconditional writes allowed means they can still overwrite a newer native save. This limitation must not be hidden.
- Lost successful responses: a retry with the old token may 412. Re-read and compare canonical saved payload/token; do not force overwrite. An operation-ID ledger is optional only if exact response replay is later needed.
- Validation: absent→first save; stale revisions with same-millisecond timestamps; intentional backward navigation; two writers; browser legacy write invalidates native token; failed restore emits no PUT; timeout after commit; book deletion; restart/migration; rejection leaves progress+library revision unchanged. Any offline reconciliation choice should be explicit; do not select max(progress).

**Conditional future work only:** automatic CFI/statistics rebasing after an edited EPUB, multiple coverage epochs for changed canonical text, remote reader-setting sync, proxy auth, split API/asset roots, or a server-supplied canonical manifest. None is needed merely because Flutter paginates differently. Current signature mismatch is a deliberate safe skip; changed-content policy needs a separate agreed product behavior before expanding the schema.

### Validation handoff and inspected test evidence

No tests were executed and no server was started. Inspection found relevant existing suites: server/test/libraryPerformance.test.ts:413 (snapshot ETag/304), readingPositions.test.ts:96 (tuple atomicity/backward/legacy reset), readingStats.test.ts:352–562 (dedup/conflict/coverage/partial batches), readingStatistics.test.ts; shared/test/{readingStats,readingStatistics,chapterProgress,librarySnapshot}.test.ts; client/test/readingActivity{Text,Geometry,Session,Delivery}.test.ts. Reuse their fixtures/expectations for Dart, not a second invented normalization model.

Before feature acceptance, exercise the deployed NAS non-destructively for health/version/shape/ETag/file GET/HEAD/range and proxy-prefix behavior, then use an explicitly disposable book for mutation/cross-client tests. Required compatibility fixtures include supplementary code points, combining marks, whitespace/control/format exclusions, excluded namespaces/elements, CSS-hidden text, images-only pages, repeated interval unions, mixed valid/invalid activity batches, duplicate delivery after a simulated lost response, hour/midnight/DST splits, wrong signature with time still accepted, and web→Flutter→web saved-anchor round trips.

## External references

- [Express 5 response API](https://expressjs.com/en/5x/api/response/#res.sendFile) — sendFile options; installed source/lockfile above determines this checkout's exact behavior.
- [Apple TN3179](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy) — local-network privacy and direct local-host access.
- [Apple NSAllowsLocalNetworking](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nsallowslocalnetworking) — ATS local-resource behavior.
- [Flutter HTTP policy note](https://docs.flutter.dev/release/breaking-changes/network-policy-ios-android) — platform-owned vs Dart-owned socket distinction; page warns historical migration instructions may age.
- Versions: local app 3.3.0; lockfile Express 5.2.1 / send 1.2.1 / etag 1.8.1. No claim about NAS package versions.

## Caveats / Not Found

- No current explicit API version, instance identity, content digest, position CAS, request idempotency for uploads/folder creation, generic undo endpoint, or server-side canonical manifest was found.
- No NAS/deployed-version/proxy/iPhone network validation was performed. Source findings are build-design evidence, not live integration acceptance.
- Native parsing must not submit speculative signatures or positions. Current backend trusts these values, and first accepted wrong coverage signatures can affect subsequent correct clients.
- File validators cannot detect all byte replacements preserving filesystem metadata. Position GET+PUT cannot guarantee prevention of concurrent stale writes. Both limitations have conditional additive proposals above.
- This file does not authorize implementation or changes to lan-reader. Only this research file was written; the reference repository remains read-only.

