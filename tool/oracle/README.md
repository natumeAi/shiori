# Native reader reference oracle

This development-only ESM project runs the pinned reader dependencies in real
browser engines. It does not ship JavaScript or a browser in the Flutter app.

## Toolchain and licences

| Dependency | Exact version / revision | Licence | Purpose |
| --- | --- | --- | --- |
| foliate-js | `78914aef4466eb960965702401634c2cb348e9b1` (package version `0.0.0`) | MIT | Reference EPUB loader, spine CFI bases, CFI grammar/resolution |
| fflate | `0.8.2` | MIT | Same UTF-8 ZIP decoding as the reference; deterministic synthetic ZIPs |
| esbuild | `0.28.2` | MIT | Bundle TypeScript and reference browser modules |
| playwright | `1.64.1` | Apache-2.0 | Drive WebKit and Chromium |
| playwright-core | `1.64.1` (transitive) | Apache-2.0 | Browser transport |
| @esbuild/win32-x64 | `0.28.2` (host transitive) | MIT | Bundler executable on the validated Windows host |

Validated Node `v24.19.0`, npm `11.17.0`; WebKit `27.2` (Playwright build
`2370`), Chromium `156.0.8078.4` (build `1248`). The lockfile records tarball
integrity. Other host-specific esbuild executables are optional packages in
the lockfile, all at the same exact version and MIT licence.

The vendored lan-reader source has no declared repository licence. It was
copied under the repository owner's explicit task authorization. Each source
has a provenance header and an unchanged original payload; `provenance.json`
records the original source SHA-256 and header byte count. The shared module
is retained unchanged; the bundler exports its exact normalization-version
constant without pulling unrelated shared-module imports into the oracle.

Roboto fixture provenance and the Apache-2.0 licence are in
`fixtures/styles/README.md`, `LICENSE-Roboto.txt`, and the EPUB's font resources.
All fixture prose is hand-authored or deterministic generated filler.

## Commands

Run from `tool/oracle/`:

```powershell
npm ci
npx playwright install webkit chromium
npm run check-reference
npm run build-fixtures
npm run vectors
npm run verify-vectors
npm run vectors-local -- "D:/path/to/book.epub" "D:/path/to/another.epub"
npm run resolve -- "D:/path/to/cfi-list.json"
```

`LAN_READER_DIR` overrides the read-only reference-check location (default
`D:/Projects/lan-reader`). The drift check uses `git show` at the full pinned
commit, strips only the documented provenance header, and compares bytes and
SHA-256. It never updates that checkout or installs dependencies there.

Fixture source directories contain `fixture.json` plus files rooted at their
archive entry paths. The builder creates the container, OPF, nav, NCX, generated
PNG where requested, and expands the explicit long-content tokens. EPUBs have
an uncompressed first `mimetype`, lexically sorted remaining entries, and fixed
local-calendar DOS timestamps (independent of host timezone).

`vectors` runs both engines. It commits the authoritative WebKit vectors
(`<id>.webkit.json`) under `test/fixtures/reader/oracle/`, plus a summary, all
cross-engine differences and the full generated Unicode exclusion range table.
Full Chromium vectors go to gitignored `build/oracle-chromium/` for inspection;
`verify-vectors` checks them when present and rejects committed Chromium files.
Vector files use a compact layout of the same sorted JSON (short values on one
line, long primitive arrays wrapped) to keep the repository small. `unicode-table.json` is the pinned table source
for Phase B; the browser does not expose its Unicode database version, so that
field is explicitly null. Engine version and the complete table pin actual
behavior. No date/time, local path or random blob identifier is serialized.

The extractor calls the actual EPUB `init`, installs the exact reference
transform handlers, calls `section.load()`, and navigates a sandboxed iframe
to its protected Blob URL, matching the final reparse in Foliate's paginator.
It records both the original sample point and the actual resolved point:
merged Text/CDATA boundaries can intentionally resolve to another node.
Projected stylesheet Blob URLs are replaced only in output with stable tokens
of identical UTF-16 length and a sorted resource-path alias map; the live DOM
is untouched. Only exact captured URLs are replaced. Literal Blob-looking prose
stays unchanged, and byte-identical resources retain every package-path alias.

The oracle uses only a loopback server (`127.0.0.1:41739`). Browser context
requests outside that origin, `blob:` and `data:` are blocked. No NAS,
reference server, account or user library network request is involved.

Resolve input is a JSON array of `{ "fixtureId": "cfi-structure", "cfis":
["epubcfi(...)"] }` groups. For local books replace `fixtureId` with an
`epubPath`. Results always go to gitignored
`build/oracle-local/resolve-results.json` and include both engines' endpoints.

## Committed versus private output

- Commit synthetic sources, their attributed font, deterministic synthetic
  EPUB assets/manifest, vectors, source/provenance, package manifest and lockfile.
- Never commit `node_modules`, Playwright browser caches, real EPUBs, real-book
  vectors, or raw personal device exports.
- `vectors-local` reads each provided EPUB in place. Its filename is replaced
  in output identity by the EPUB SHA-256; all generated vectors remain under
  gitignored `build/oracle-local/`. They contain private book text, so keep the
  entire directory local. No real book is copied into the source/assets tree.

Windows WebKit is a reference engine approximation, not iPhone Safari or
physical presentation evidence. See the S2 task's `research/oracle-notes.md`
for exact observations and reference ambiguities.
