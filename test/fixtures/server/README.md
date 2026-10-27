# Synthetic S3 HTTP fixtures

All titles, authors, identifiers, paths, timestamps, validators and addresses
here are invented. No server was contacted and no private book or NAS data was
copied. Hosts use `example.test`, `192.0.2.0/24` and `2001:db8::/32`.

Provenance: read-only `D:/Projects/lan-reader`, clean at commit
`a4bda23fd3e82e285a22566d88576e67d3e8756b` (version 3.3.0).
Source anchors below are relative to that checkout. Values are synthetic;
wire casing, envelopes and declared nullable fields follow the pinned source.

| Key | Source file:line and shape |
| --- | --- |
| H | `server/src/app.ts:73` health; `server/src/db/database.ts:93` returns `ok` or throws; `server/src/http/requestInput.ts:33` unconfigured DB |
| S | `shared/src/api.ts:113`, `shared/src/librarySnapshot.ts:19` envelope/schema; `server/src/services/librarySnapshot.ts:37` trimmed books and `:137` snapshot |
| B | `shared/src/book.ts:60` SnapshotBook nullable fields; `server/src/services/librarySnapshot.ts:56` null versus zero |
| F | `shared/src/folder.ts:30`, `shared/src/shelf.ts:22`; `server/src/services/librarySnapshot.ts:93` ordering, `:107` counts/previews, `:118` shelf |
| R | `shared/src/reading.ts:22` ReadingPosition, `:60` SnapshotRecentEntry; `server/src/services/readingLibrary.ts:28` formatter, `:49` recent query; `server/src/services/librarySnapshot.ts:132` normalized recent |
| D | `shared/src/book.ts:12`, `shared/src/api.ts:29`; `server/src/services/bookLibrary.ts:121` full Book; `server/src/routes/books.ts:130` detail and `:137` missing book |
| E | `shared/src/api.ts:129`, `server/src/http/httpError.ts:28`, `:32`; `server/src/app.ts:105` middleware; `server/src/http/requestInput.ts:71` invalid ID message |
| T | `server/src/db/migrations/001_initial_library_schema.sql:5`, `:23`, `:33` raw UTC SQLite timestamps; `server/src/routes/reading.ts:208` writes reading progress with `strftime('%Y-%m-%d %H:%M:%f', 'now')` (three fractional digits, UTC) |
| V | `shared/src/librarySnapshot.ts:17`, `:48`, `:57`, `:66`; `shared/src/decode.ts:35`, `:42`; S3 `design.md` section 4 adds strict required-nullable, safe-positive-ID and join validation beyond the reference decoder |
| HTTP | `server/src/routes/library.ts:20` headers/bodyless 304; `server/src/services/librarySnapshot.ts:33` revision ETag; `server/src/routes/books.ts:207` sendFile; `server/src/app.ts:62` compression and `:65` covers |
| SEND | Installed `node_modules/send/index.js:514` conditional 304/412, `:549` 416, `:564` 206, `:583` length, `:757` Last-Modified/ETag; `node_modules/etag/index.js:126` size/mtime validator (dependency evidence, not tracked source) |
| URL | `server/src/app.ts:73`, `server/src/routes/library.ts:20`, `server/src/routes/books.ts:130`, `:207` suffixes; `server/src/services/bookLibrary.ts:97` encoded covers. Prefix/normalization/rejection expectations come from task `design.md` section 2, not a backend URL normalizer. |

`manifest.json` inventories every JSON/HTML file, including itself. The test
checks that inventory against this table and the directory, parses every JSON
and checks selected structural invariants. Each invalid payload is a complete
standalone body with one named invariant violation relative to the minimal
snapshot. These are S3 rejection cases, not claims about every reference
decoder rejection.

| File | Purpose | Sources |
| --- | --- | --- |
| `health_ok.json` | Usable 200 health | H |
| `health_database_unconfigured.json` | 200 health with unusable DB | H |
| `health_database_error.json` | Actual 500 body when DB check throws | H, E |
| `health_wrong_service.json` | Synthetic wrong-service mutation | H |
| `health_additive.json` | Synthetic future additive capability | H |
| `snapshot_typical.json` | Root books, folder-contained books, empty folder, ordered joins, typed ID collision, recent, null/0/fraction; SQLite `.SSS` in readingUpdatedAt and recent progress.updatedAt alongside second-only book/folder timestamps | S, B, F, R, T |
| `snapshot_minimal.json` | Valid baseline for isolated invalid cases | S, B, F, T |
| `snapshot_empty.json` | Empty library, revision zero | S |
| `snapshot_explicit_offset.json` | Explicit +08:00, same instant as raw UTC baseline | S, B, T; design section 4 |
| `snapshot_additive.json` | Unknown fields on envelope, snapshot, book, folder, shelf, recent and progress | S, B, F, R; design section 4 |
| `snapshot_invalid_schema_version.json` | Unsupported schema 99 | S, V |
| `snapshot_invalid_missing_nullable.json` | Required nullable author absent | B, V |
| `snapshot_invalid_unsafe_id.json` | ID 9007199254740992 exceeds JS safe integer | B, V |
| `snapshot_invalid_non_positive_id.json` | Zero ID | B, V |
| `snapshot_invalid_fractional_id.json` | Non-integer ID | B, V |
| `snapshot_invalid_duplicate_book_id.json` | Duplicate book identity | S, V |
| `snapshot_invalid_missing_folder_book.json` | Folder bookIds/preview refer to missing book | F, V |
| `snapshot_invalid_missing_shelf_record.json` | Shelf book reference has no record | F, V |
| `snapshot_invalid_shelf_enum.json` | Unknown shelf type collection | F, V |
| `book_detail.json` | Full {book}, detail-only fields and encoded cover | D, URL, T |
| `book_not_found.json` | Exact detail 404 body; no code field | D, E |
| `error_400.json` | Exact invalid book-ID 400 body; no code field | E |
| `error_500.json` | Sanitized 500 body; no code or stack | E |
| `proxy_login.html` | Invented HTML proxy/login response | Synthetic negative input; design sections 2/4 |
| `manifest.json` | Inventory and HTTP status/header descriptors | HTTP, SEND, H, D, E |
| `url_resolution.json` | Exact URL vectors and zero-traffic rejected inputs | URL |

Health never emits `database: "error"`: `checkDatabase` throws and middleware
emits the supplied 500 fixture. Folders have no parent-folder field: nesting
here means books inside folders. No folder hierarchy has been invented.

SnapshotBooks omit description/publisher/language and thumbnail storage paths;
full Book omits snapshot-only readingProgress/readingUpdatedAt. Recent's
`progress` is a ReadingPosition object, including chapterCount/index.
Raw timestamps must remain byte-for-byte available to later DTO tests.

Response descriptors are metadata, not EPUB/image payloads or server captures.
`bodyKind: absent` means zero bytes, never `{}`, `null` or a JSON placeholder.
EPUB/partial-EPUB bytes are supplied by later download tests. Chunked and
no-validator 200s model intermediaries; they do not claim direct sendFile
omits those headers. 206/412/416 are unexpected terminal responses for S3
full downloads. Validators are opaque; snapshot revision is not a file digest.
Cover vectors add an encoded query for client resolution; the formatter
itself only encodes path components. No live compatibility claim is made.
