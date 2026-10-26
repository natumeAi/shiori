# S2 per-command evidence

Relocated on 2026-10-23 during Phase F part 1. This directory contains the
complete corrected inventory: **31 JSON files** (25 oracle, 5 quality-gate,
1 dependency-install). `../task.json` is task metadata, not evidence.

Every JSON was moved as raw bytes. SHA-256 was taken before and after each move;
all 31 matched, with no newline conversion. The manifest below records the
pre-move hashes and byte lengths. Historical results are retained, not rerun or
rewritten: in particular D's JSON is the 784-test pre-review gate, E's is the
962-test pre-review gate. The later 785/969 results are in
[local validation](../local-validation.md#phase-d-review-and-independent-re-run)
and [the Phase E review](../local-validation.md#phase-e-independent-trellis-check-review--2026-10-23).

## Index

Commands are historical unless explicitly identified as a snapshot/inspection.
Oracle npm commands ran in `tool/oracle/`; Flutter gates ran at the repository
root. Local-book arguments are deliberately represented only as
`<the four local sample books>`, without reproducing private names.

| File | Phase | Command / operation | What it proves |
| --- | --- | --- | --- |
| [oracle-browser-install.json](oracle-browser-install.json) | A | `npx playwright install webkit chromium` | Browser installation exit 0; not an oracle comparison. |
| [oracle-build-fixtures-1.json](oracle-build-fixtures-1.json) | A | `npm.cmd run build-fixtures` | Initial synthetic corpus generation exits 0. |
| [oracle-build-fixtures-2.json](oracle-build-fixtures-2.json) | A | `npm.cmd run build-fixtures` | Second initial corpus generation exits 0. |
| [oracle-build-fixtures-final-1.json](oracle-build-fixtures-final-1.json) | A | `npm.cmd run build-fixtures` | Reviewed corpus generation exits 0; final-clean records supersede its digests. |
| [oracle-check-reference-final.json](oracle-check-reference-final.json) | A | `npm.cmd run check-reference` | Final vendored-reference drift check exits 0. |
| [oracle-check-reference.json](oracle-check-reference.json) | A | `npm.cmd run check-reference` | Initial vendored-reference drift check exits 0. |
| [oracle-ci.json](oracle-ci.json) | A | `npm.cmd ci --no-audit --no-fund --fetch-retries=0 --fetch-timeout=45000` | Locked Node dependencies install, exit 0. |
| [oracle-final-clean-1-build-fixtures.json](oracle-final-clean-1-build-fixtures.json) | A | `npm.cmd run build-fixtures` | Clean UTC corpus build exits 0. |
| [oracle-final-clean-1-vectors.json](oracle-final-clean-1-vectors.json) | A | `npm.cmd run vectors` | Clean UTC browser-vector generation exits 0. |
| [oracle-final-clean-1-verify-vectors.json](oracle-final-clean-1-verify-vectors.json) | A | `npm.cmd run verify-vectors` | Clean UTC vector verification exits 0. |
| [oracle-final-clean-2-build-fixtures.json](oracle-final-clean-2-build-fixtures.json) | A | `npm.cmd run build-fixtures` | Clean Asia/Hong_Kong corpus build exits 0. |
| [oracle-final-clean-2-vectors.json](oracle-final-clean-2-vectors.json) | A | `npm.cmd run vectors` | Clean Asia/Hong_Kong browser-vector generation exits 0. |
| [oracle-final-clean-2-verify-vectors.json](oracle-final-clean-2-verify-vectors.json) | A | `npm.cmd run verify-vectors` | Clean Asia/Hong_Kong vector verification exits 0. |
| [oracle-final-reproducibility.json](oracle-final-reproducibility.json) | A | `python .trellis/tasks/10-22-native-reader-feasibility/verify_oracle_reproducibility.py` | Final 32 generated/attribute files: identical hashes across both timezones, no source-filter mismatches. |
| [oracle-install.json](oracle-install.json) | A | `npm install --no-audit --no-fund --fetch-retries=0 --fetch-timeout=45000` | Tool dependency installation exits 0. |
| [oracle-local-books.json](oracle-local-books.json) | A | `npm.cmd run vectors-local -- <the four local sample books>` | Both-engine local extraction exits 0; private arguments are not repeated here. |
| [oracle-reproducibility-first.json](oracle-reproducibility-first.json) | A | Initial generation SHA-256 snapshot | Historical 43-output hash baseline; superseded by final reproducibility. |
| [oracle-resolve-smoke.json](oracle-resolve-smoke.json) | A | `npm.cmd run resolve -- ../../build/oracle-local/synthetic-resolve-input.json` | Native-CFI resolve CLI smoke check exits 0. |
| [oracle-source-lf-normalization.json](oracle-source-lf-normalization.json) | A | Raw source / Git blob inspection and LF normalization | Records affected hashes, preserved mixed-newline fixture, 86 tracked oracle files and zero final HEAD mismatches. |
| [oracle-timezone-reproducibility.json](oracle-timezone-reproducibility.json) | A | `TZ=UTC` / `TZ=Asia/Hong_Kong node src/build-fixtures.mjs` (historical environment assignments) | 14 generated assets byte-identical across timezones. |
| [oracle-vectors-1.json](oracle-vectors-1.json) | A | `npm.cmd run vectors` | Initial WebKit/Chromium vector generation exits 0. |
| [oracle-vectors-2.json](oracle-vectors-2.json) | A | `npm.cmd run vectors` | Second initial vector generation exits 0. |
| [oracle-vectors-final-1.json](oracle-vectors-final-1.json) | A | `npm.cmd run vectors` | Reviewed generation exits 0; final-clean records supersede its digests. |
| [oracle-vectors-reviewed-1.json](oracle-vectors-reviewed-1.json) | A | `npm.cmd run vectors` | Post-review generation exits 0. |
| [oracle-verify-vectors.json](oracle-verify-vectors.json) | A | `npm.cmd run verify-vectors` | Vector schema/corpus verification exits 0. |
| [quality-gate-0.json](quality-gate-0.json) | 0 | Codegen; format `lib test tool/diag`; analyze; test | Four exits 0; 91 baseline tests. |
| [quality-gate-A-source-lf.json](quality-gate-A-source-lf.json) | A | Codegen; format `lib test tool/diag`; analyze; test | Four exits 0 after source-byte correction; 91 tests. |
| [quality-gate-A.json](quality-gate-A.json) | A | Codegen; format `lib test tool/diag`; analyze; test | Initial Phase A gate exits 0; 91 tests. |
| [quality-gate-D.json](quality-gate-D.json) | D | Codegen; format `lib test tool/reader`; analyze; test | Four exits 0; 784 passed, 1 skipped before lifecycle review fix. |
| [quality-gate-E.json](quality-gate-E.json) | E | Codegen; format `lib test tool/reader tool/diag tool/ci`; analyze; test; shell syntax; fixture guard; strict analyzer | Seven exits 0; 962 passed, 1 skipped before independent review. |
| [reader-dependency-install.json](reader-dependency-install.json) | B (initial) | `flutter pub add archive xml html csslib` | Initial install exits 0; final dependency choices are documented in PRD and later validation. |

Gate abbreviations above mean `dart run build_runner build`,
`dart format --set-exit-if-changed <listed paths>`, `flutter analyze` and
`flutter test`. E additionally records `bash -n tool/ci/build_ios_unsigned.sh`,
`dart run tool/ci/check_reader_fixtures.dart`, and
`dart run tool/diag/analyze_reader_export.dart --strict test/fixtures/reader/exports/passing-120hz-a1-1.json`.
Their exact timeout, exit, duration and output fields remain in the JSON.

## Writers and references

The three scripts in the task root now create/write `evidence/`. The
reproducibility wrapper invokes the same oracle wrapper and points its appended
validation reference here. Existing local-validation and resume-handoff paths
are updated; report links use this location.

Protected historical references were not edited: `../implement.md:142-144`
names the old root inventory patterns, and `../research/source-resume.md:15`
names `reader-dependency-install.json` (now here). The coordinator owns those
updates. This index does not replace or edit those historical files.

## Phase F part 1 verification (2026-10-23)

The final repository-root checks completed with explicit subprocess timeouts:

| Command / check | Timeout | Exit / result |
| --- | --- | --- |
| `dart format --set-exit-if-changed lib test tool/reader tool/diag tool/ci` | 180 s | 0; 253 files, 0 changed |
| `flutter analyze` | 180 s | 0; no issues |
| `flutter test` | 900 s | 0; 969 passed, 1 skipped |
| `python -m py_compile` on the three task scripts | 30 s | 0 |
| `bash -n tool/ci/build_ios_unsigned.sh` (Git Bash) | 180 s | 0 |
| `dart run tool/ci/check_reader_fixtures.dart` | 180 s | 0; real repository PASS |
| `dart run tool/diag/analyze_reader_export.dart --strict test/fixtures/reader/exports/passing-120hz-a1-1.json` | 180 s | 0; reader/engine MATCH, 7 pass rows, 0 fail, 2 unavailable; one synthetic repeat is not device acceptance |

The three script edits only redirect evidence writers/create the directory and
update the appended reproducibility reference; command bodies/timeouts remain
unchanged. The destructive/regenerating oracle wrapper was not rerun in this
documentation scope. Local-validation and resume-handoff changes are path-only
after CRLF normalization. Runbook checks matched 22 literal localized labels
and all 15 scenario/mode options. All 31 JSON hashes and byte lengths match the
manifest. The six protected task/coordinator files checked before/after are
unchanged. No app/spec update, commit, push or device operation was made.

## Raw-byte SHA-256 manifest

| File | Bytes | SHA-256 before = after move |
| --- | ---: | --- |
| `oracle-browser-install.json` | 11235 | `78f636c5eabc73efcba4633f5200d2d54ed3eae12e958b0d84d8fa4835be3d44` |
| `oracle-build-fixtures-1.json` | 607 | `5e94bad645e52b2c425b0114e02b74582963e736a6068e832261646d078da3c6` |
| `oracle-build-fixtures-2.json` | 607 | `ef025f21c5cd16b2868f8fcb6e2ced10d4d2b6fa0bbef8d4c0d7639ec4463486` |
| `oracle-build-fixtures-final-1.json` | 607 | `971c8d33b58a78be49ce7d0a95ba221287417cc632c45ceee8ddff3b5364807f` |
| `oracle-check-reference-final.json` | 692 | `1041b8bb68b30bd564b5450e70bbf12e0ce8db699020ebb7f7cbca53560a1d0a` |
| `oracle-check-reference.json` | 692 | `85c86d109081b76d5b6d84b369e6b79b66ae5714ce9cc71847e6167a8f481c1b` |
| `oracle-ci.json` | 571 | `cc18badfac9fea5ff8305320dee59476873f15f33ed2fda690f83bb8ddf2c1f2` |
| `oracle-final-clean-1-build-fixtures.json` | 607 | `cb0cffc4d69862414960f36a1aed65e97b2e4cb6be6703111553861baca801ea` |
| `oracle-final-clean-1-vectors.json` | 1169 | `341437cb93a7775285c04940a5dc10f0b81f5f99ea9183938cbacd847a0f3ad6` |
| `oracle-final-clean-1-verify-vectors.json` | 427 | `8ee468fd3bb74b2c6db6609613ba3b74d115e973d7c475f48255ffbbda2c3058` |
| `oracle-final-clean-2-build-fixtures.json` | 607 | `e29d55ee82f8803448622c86184185164dddb44c2b50909ee9339d1d78415680` |
| `oracle-final-clean-2-vectors.json` | 1169 | `c7aeee7b5ded6bfc82e27d5ff2309bf8cfbf2c27a93a9c25d0b6c019c8478222` |
| `oracle-final-clean-2-verify-vectors.json` | 427 | `03cdc057ce0411d8c6cb58d94076b5addd534a57fff1d77860107344103a5a0d` |
| `oracle-final-reproducibility.json` | 4082 | `bbe857f9878736c457ad2167964ecfe31b3b18a7246bde80a0d89235efda0cae` |
| `oracle-install.json` | 561 | `048b5ba5c6b4842c50ac6732eae4ef901336dfe50a2b6a010e940d3b9d81f4ee` |
| `oracle-local-books.json` | 1809 | `0428f26d5c5ff65a4abf5d814e1bd918805d763e7ccc19bf4899f6d8f9361e57` |
| `oracle-reproducibility-first.json` | 5289 | `7cc838c07227a82f672764f061ee767fba525a65027d6480c5c998185107c979` |
| `oracle-resolve-smoke.json` | 478 | `ed38c9d3556ade3850e6ad32e938548a79e9c9e0a53220695234696d5edd9588` |
| `oracle-source-lf-normalization.json` | 2155 | `db2ebef26429adde62efb4f5bdb9b270297743d6c4c4f3984d60dc7ef8213bc7` |
| `oracle-timezone-reproducibility.json` | 570 | `5f6e180b27cd6cc86572a6bb8b5932a7190d4e4b5176d6396d25183c1416054d` |
| `oracle-vectors-1.json` | 1169 | `1a225d94c29ce22bcee4bd724c80e89c205a0c2d476626a819f38624234d133c` |
| `oracle-vectors-2.json` | 1169 | `ea6c5ec126d14f84eba18b712e4233fbc9cd80f340b495b28d7cbaa0c60842db` |
| `oracle-vectors-final-1.json` | 1169 | `f380a8ba8bf398332cbe1cb8ed63f32acd819057e42cfa4366f4a74a072ff788` |
| `oracle-vectors-reviewed-1.json` | 1169 | `79fc62cef74afd541f811373f9ca9265ccc6bc6277645ee5e879a270cd928cdb` |
| `oracle-verify-vectors.json` | 392 | `c9aae4a992899393c9de2fa1834a5b5ba302b510080813c776a97022a49db336` |
| `quality-gate-0.json` | 4791 | `a4fb5ac5856e58ebe427fb97a4375994c66fa56904347ea4024a006a2f57b970` |
| `quality-gate-A-source-lf.json` | 4745 | `fa36cb475063e1d6582b1c530be7237c47e3be2361ec04b11735b15b0c24f153` |
| `quality-gate-A.json` | 4798 | `ffb71fe2e35123f8d594ff99cdda15712eb428cfa2f1b0b67bb6822f235502e3` |
| `quality-gate-D.json` | 5811 | `de44c06cc24fbec99ffeff153c1f66125194fd889aee0a86bae3ce88e28ea7ed` |
| `quality-gate-E.json` | 5938 | `344ab18377845e099c59720e1ee82d02e44549c0db3f639b150255fafe3ec9ce` |
| `reader-dependency-install.json` | 916 | `374c87c566a59462c32679910016b8e85b532d37261d1a2af302fc6889c44cb3` |

