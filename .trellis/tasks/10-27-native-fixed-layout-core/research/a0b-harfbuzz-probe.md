# A0b: Windows HarfBuzz outline probe

**Round 3 below is the owner-extended final slice; earlier rounds are historical.**
It resolves the historical input stop and PATH requirement recorded in round 1.
The svg-text row still fails. Definition B was adopted before round 3;
definition A is retained as a diagnostic.

2026-10-28. One bounded host slice; no production adoption, network, download,
sub-agent, dependency change, commit or reference modification. The experiment
executes successfully; the required svg-text row **fails** on its measured
inputs. D2 remains in force. This result does not prove that every possible
HarfBuzz SVG implementation is infeasible.

## Stop condition and input identity

During the evidence audit, current fixture hashes were found to differ from
the authoritative A0 closure report. Work stopped under the dispatch's explicit
instruction to stop on a checkout discrepancy. No input was reconciled.

| Input | A0 closure SHA-256 | Actually measured SHA-256 |
| --- | --- | --- |
| corpus.json | aa61e4776195e20d49392c4af5e710db5ffdf5276d8b3d1440a7a5608d5f2dd7 | eb8379f5745d57a42c4bd2b10ed9587fee0260054af3a2747b799f8f6813af44 |
| oracle.json | 4eb18eb6aa389f648f0ee36b2b6ad740c1c985bd742a8f9154e6e3d7d8349917 | 33708a0fce1c0b7b523069b7e4e901923a53d4237bb51697de5a822cd1b857af |

Both current files contain zero CRLF sequences; normalizing line endings does
not restore the closure pins. Their exact measured hashes are in the ignored
`build/harfbuzz-probe/report.json`. The document's measurements describe those
bytes only. Comparison with the closure-pinned corpus is **unverified** pending
main/oracle-owner review. No fixture, oracle, expected data or shared helper was
edited by A0b. The dispatch did not itself supply corpus/oracle digest literals;
the discrepancy was discovered against its required closure-report context.

## Binary, font and bindings

Runtime `hb_version_string`: **14.6.0**. The hand-written C ABI structures are
20-byte glyph info and 20-byte glyph position records; runtime execution checks
their sizes. Pinned identity is tracked in
`tool/reader/harfbuzz_probe_manifest.json`; no binary is in a tracked path.

| Item | Bytes / SHA-256 |
| --- | --- |
| Windows MinGW x64 release ZIP | 6,315,868 / a773b8e99aa13f9a387d3d243eaad594d6dc530fba1bb852445282639b40b0b3 |
| libharfbuzz-0.dll | 54f305d0e69f70a0ae285d45aa9bf6c73ef4d86b93480312c7cff142996d63c3 |
| Roboto-Regular.ttf, corpus font path | 171,676 / 79e851404657dac2106b3d22ad256d47824a9a5765458edb72c9102a45816d95 |
| downloaded COPYING | ba8f810f2455c2f08e2d56bb49b72f37fcf68f1f4fade38977cfd7372050ad64 |

The DLL is opened in place. The PowerShell launch prepends the absolute
`build/third_party/harfbuzz-14.6.0/extracted/harfbuzz-win64` directory to the test
process PATH; its same-folder libglib dependency consequently resolves. There
is no system installation or tracked binary copy. The ZIP size/hash, DLL hash,
font hash and runtime version are checked before measurement.

Surface: blob_create/destroy; face_create/get_upem/destroy; font_create,
ot_font_set_funcs, font_set_scale/destroy; buffer_create/add_utf16,
set_direction/script/language/cluster_level, allocation_successful,
get_glyph_infos/positions/destroy; language_from_string; hb_shape;
draw_funcs_create/set_move_to/set_line_to/set_quadratic_to/set_cubic_to/
set_close_path/destroy; hb_font_draw_glyph; version_string; CRT malloc/free.
No ffigen/libclang is used. Direction=LTR (HB enum 4), script=Latn,
language=en, MONOTONE_GRAPHEMES cluster level 0, default shape features.
Font scale=(2048,2048); multiply coordinates by 20/2048 and invert outline y.

READONLY blob memory stays allocated until font, face and blob destruction.
Buffer input and language/length scratch are scoped; borrowed arrays are copied
before buffer destruction. Five isolateLocal NativeCallable callbacks execute
synchronously on the calling isolate and close after draw_funcs destruction.
Pictures, codecs, images and Paragraphs use finally disposal. Path has no public
dispose: reset each outline and release its owner; actual backing-store and
PathMetric reclamation remain GC-managed. The DLL and registered engine font
also remain process resources; no unload API is claimed.

## Shaping evidence

Each run is shaped once per scene, and those exact glyph records produce both
the Path paint and shaped ClusterGeometry. There is no substring reshaping,
grapheme clipping, glyph cropping, nominal-advance substitution or pixel mask
around a native deviation.

| Run | Glyph IDs | HB UTF-16 cluster indices | x advances in font units |
| --- | --- | --- | --- |
| Ab fi | 37,70,4,444 | 0,1,2,3 | 1336,1149,507,1134 |
| Ab fi e\u0301 Z | 37,70,4,444,4,675,4,62 | 0,1,2,3,5,6,8,9 | 1336,1149,507,1134,507,1085,507,1226 |

All y advances and x/y offsets in these two runs are zero. Glyph 444 is the
single fi cluster [3,5); glyph 675 covers e + combining acute [6,8). The short
map is [0,1),[1,2),[2,3),[3,5). The long map additionally has [5,6),[6,8),[8,9),
[9,10). Every fixture-declared map in all six measured cases is confirmed.
Widths are **40.29296875** and **72.763671875** CSS px, exactly equal to the
native Paragraph widths and corresponding WebKit computedTextLength; deltas=0.
Paragraph glyph IDs are not exposed by public dart:ui. Advance equality does
not independently establish identical Paragraph glyph IDs.

Positioned runs resolve x/y/dx/dy/rotate lists through text/tspan ancestors at
the cluster's first character, anchor the chunk, and emit one rigid transform
per cluster. Quadratic text uses source path data, native PathMetric, 5%
startOffset, and each cluster's mid-advance tangent. Child spacingAndGlyphs
scales glyph outlines and advances; spacing places cluster starts using the
authored UTF-16 spacing distribution. Parent textLength is ignored for these
WebKit-compatible nested textPaths. These are bounded fixture rules, not a
general SVG parser. Per-character positioning inside a shaped cluster remains
a material unresolved compatibility issue, especially for child spacing.

The independent f\u0301 control has glyphs 74 and 169, both cluster 0, advances
711 and 0 units. Its outline crosses the cluster advance by 0.029296875 px.
Both straight and quadratic versions paint both glyphs exactly once and retain
source range [0,2). Their screenshot is retained, but has no reference PNG and
is explicitly unverified for oracle fidelity. It is not a passing extra row.

## Per-case gate results

Uses A2's shared geometry, D4 and D3 helpers read-only. Real unit adapters carry
whole-cluster outer edges; interior component geometry is not substituted for
the gate. The wrapper retains sharedHelperProvisional and replaces the exported
provisional flag only after actual HB membership confirmation. All exports use
ClusterGeometry provenance=shaped. Nested geometry stays in SVG user space;
paint applies (7,9), clip and .8 opacity. Probe captures apply the recorded
XHTML host body margin (8,8) only to raster coordinates.

Geometry is the maximum same-channel CSS-pixel error. D4 lists interior / edge
neighbourhood / support bounds / components / exact samples. No tolerance changed.

| Case | Geometry max | D4 I/E/B/C/S | Components native/reference | Raw changed | RD-1 pixels | Verdict |
| --- | ---: | --- | --- | ---: | ---: | --- |
| svg-text-positive | 1.230398 | P/P/P/F/P | 8/7 | 655 | 1 | fail |
| svg-text-boundary | 1.230398 | P/P/P/F/P | 8/7 | 655 | 1 | fail |
| svg-text-nested | 1.230398 | P/P/P/F/P | 8/7 | 646 | 0 | fail |
| svg-text-path-none | 0.775690 | P/P/P/P/P | 4/4 | 410 | 1 | fail |
| svg-text-path-spacing | 11.162514 | P/P/P/F/P | 6/8 | 465 | 1 | fail |
| svg-text-path-spacingAndGlyphs | 1.775340 | P/P/P/F/P | 7/8 | 747 | 1 | fail |

Every glyph emission and original UTF-16 unit is accounted exactly once, and
all CFI round trips pass. Full cases emit 12 glyphs / 15 UTF-16 units; path-only
cases emit 8 glyphs / 10 units. All exact sample deltas are zero. D3 only exempts
RD-1's eligible (0,0) pixel from its existing independent control. RD-2 never
applies. No new exception, widened scope or component waiver is proposed.

The none failure is the fi end. The upper positioned fi end misses 1.230398 px.
Under spacing, reference fi outer endpoints span 22.295867 px, whereas the
retained HB glyph advance is 11.074219 px; the actual reference screenshot shows
separated f and i. Thus whole-run advance equality does not establish that SVG
paints the run with identical cluster placement. Under spacingAndGlyphs, fi
end error is 1.775340; e\u0301 end error is 0.541114 and rotation displacement
0.877365. Native PathMetric versus WebKit path sampling also remains unresolved.
Visual inspection and D4 confirm raster differences beyond the original slice
artifact: the upper fi has two native components versus one reference component.
The cause is not certified as a reference defect. The simple rigid-cluster
route is not accepted by this experiment, and no claim of general impossibility
or successful A2 adoption follows.

## Resource accounting and limits

The ledger ends with **zero live owned HB handles, callbacks, outlines and
explicit allocation payload bytes**. Across two shaping diagnostics, six
required scenes and the two-run overhang control:

- Created/destroyed: 1 blob, 1 face, 1 font, 1 draw_funcs, 13 buffers;
  5 NativeCallable thunks closed; 76 outline owners reset/released.
- Peak HB handles: 5 (blob/face/font/draw_funcs plus one buffer); peak callbacks
  5; peak retained outline owners 12. Outline callbacks emit 1,064 operations
  overall; full scene=172, path-only=108, overhang control=52 operations.
- Explicit native payload peaks: font input 171,676 bytes; UTF-16 input 20;
  language scratch 3; length scratch 4. Buffer-owned glyph info/position logical
  payload peak 320 bytes. Buffer capacity, allocator metadata and caches are
  **unmeasured**; the latter number is not a total native allocation size.
- Retained outline command/coordinate logical payload peak 3,500 bytes
  (one verb byte plus eight bytes per coordinate); actual ui.Path storage is
  unmeasured. Source map objects, quads and report JSON have additional VM cost.
- Two diagnostic Paragraphs are disposed. Seven render Pictures and seven
  native images are disposed; each native surface is 307,200 RGBA8 bytes.
  Six case reference codecs/images are also disposed. The shared D3 loader
  decodes/disposes ten control codecs/images and retains ten 320x240 RGBA
  arrays (3,072,000 bytes) until this probe's local control owner is collected.
  Case native/reference images overlap at 614,400 known RGBA8 bytes; raw
  comparison arrays, encoded PNGs, decode scratch and nested saveLayer add
  storage. These figures are not RSS or GPU memory measurements.
- Native Paragraph font registration is one process-retained face / 171,676
  input bytes, reported separately from destroyable HB ownership. DLL modules,
  HB's language intern table and engine font caches are process resources.

Probe bounds: font input <=32 MiB, shaping input <=4,096 UTF-16 units, glyph
output <=16,384, each outline <=100,000 operations and 16 MiB logical command
payload. Callbacks stop recording on overflow and report failure after returning
to Dart. They never propagate an exception through a native callback boundary.
Only the small pinned corpus is exercised; these bounds and measured counters
do not constitute A3 aggregate admission integration or iPhone-safe limits.

## iOS packaging plan and risks

Proposed next packaging work, **not executed** in this Windows/no-network slice:

1. In owner-approved hosted macOS CI, obtain the exact HarfBuzz **14.6.0 source**
   archive with a separately approved source hash; the Windows binary ZIP hash
   is not a source pin. Build the OT shaping/drawing subset statically with
   Apple clang for arm64 iphoneos and the required simulator architectures,
   matching Runner's minimum deployment target. Avoid GLib/FreeType/tool builds
   for the minimal OT-only route. Record source/configuration/compiler hashes.
2. Prevent collision with HarfBuzz already statically linked into Flutter's
   engine. Do not use unqualified DynamicLibrary.process lookups of hb_*.
   Prefix **all** vendored HB symbols and internal cross-object references in
   a reproducible source/build step; verify with nm that no unprefixed global
   hb_* definition remains. Hide those prefixed symbols behind a uniquely named
   C bridge, or export only the prefixed subset that Dart actually binds.
   Visibility hiding alone does not prove freedom from duplicate static symbols
   or symbol interposition; validate link maps and binding provenance on device.
3. Package device/simulator static archives as an XCFramework with headers and
   the bridge, integrate it through the owning iOS/plugin build target, and
   retain the FFI entry points against dead stripping. Use no runtime dynamic
   library download. Validate archive slices, release/AOT callbacks, linker
   retention, Flutter coexistence and installed-device rendering/lifetimes.
4. HarfBuzz uses Old MIT: distribute the downloaded COPYING copyright notice,
   permission paragraph and disclaimer paragraphs in the application third
   party notices and source/binary distribution. Audit any additional selected
   source components' licences. Do not distribute this MinGW/GLib host build as
   the iOS artifact. The existing pinned font keeps its own licence obligations.

No iOS binary, static link, symbol-prefix implementation, source hash approval,
device measurement or packaging change is claimed. ABI/provenance, release
callback behavior, native caches and process-font lifetime need those checks.

## Commands, validation and requests

All SDK calls use the direct installed dart.exe, never a .bat wrapper.

```powershell
$dart = 'D:/DevTools/flutter/bin/cache/dart-sdk/bin/dart.exe'
$flutterTools = 'D:/DevTools/flutter/bin/cache/flutter_tools.snapshot'
$owned = @('tool/reader/harfbuzz_probe.dart',
  'tool/reader/harfbuzz_probe_ffi.dart', 'tool/reader/harfbuzz_probe_draw.dart',
  'tool/reader/harfbuzz_probe_shape.dart', 'tool/reader/harfbuzz_probe_scene.dart',
  'test/tool/reader/harfbuzz_probe_test.dart')
& $dart format @owned
& $dart analyze @owned
$probeDllDirectory = (Resolve-Path 'build/third_party/harfbuzz-14.6.0/extracted/harfbuzz-win64').Path
$env:PATH = $probeDllDirectory + ';' + $env:PATH
& $dart $flutterTools test test/tool/reader/harfbuzz_probe_test.dart --no-pub --reporter expanded
```

Final focused format exit **0**; focused analysis exit **0**, no issues; test
exit **0**, one executed/passed. The earlier analysis exited 1 on untyped FFI
callback parameters and brace lint; these were fixed before that passing run.
Test success establishes execution/conservation/teardown, never fidelity.
On non-Windows or when the approved DLL path is absent, the test skips with an
explicit platform/missing-binary reason and performs no download. The missing
binary skip branch was reviewed but not exercised by removing/moving the binary.
No further executable checks ran after discovering the input-pin discrepancy.

An attempted optional inspection used unavailable Python PIL and failed;
inspection instead used built-in Windows System.Drawing to composite copies
over white in ignored build output. The first contact-sheet command had a
PowerShell constructor error; the corrected command exited 0. Neither attempt
changes measurement rasters, reference PNGs or gates.

Requests to main/oracle owner: review the differing fixture hashes and publish
the authoritative pins before any follow-up; determine why SVG component
placement differs from whole-run shaped advances without weakening the contract
or adding a D3 exemption for native differences. Request to A2: keep required
curved/positioned text open; do not adopt this probe as a passing renderer.
The shared comparator's provisional output is retained in a wrapper rather
than edited; no shared-helper change is required by this slice. iOS source pin,
symbol-prefix build and device proof remain packaging-owner work after approval.

The session stops here. At most one follow-up is permitted by the dispatch;
this slice supplies measured failure evidence and leaves owner review open.

## Round 2: final bounded slice (2026-10-28)

### Identity, scope and Windows loading

The final dispatch explicitly authorizes the actual measured pins:
corpus `eb8379f5745d57a42c4bd2b10ed9587fee0260054af3a2747b799f8f6813af44`,
oracle `33708a0fce1c0b7b523069b7e4e901923a53d4237bb51697de5a822cd1b857af`.
They are now checked before measurement and recorded in the probe manifest.
No fixture/reference/expected bytes were regenerated or edited. Round 1's
closure-pin stop is resolved by this new authorization, not normalization.

Read-only PE import inspection found HB -> GLib -> libintl -> Windows system
DLLs. HbApi now opens libintl-8.dll, then libglib-2.0-0.dll, then HarfBuzz,
all at absolute paths. The manifest pins both dependency hashes and the runner
verifies them before loading. Module owners persist for the process; no PATH
or process DLL search-directory mutation is necessary. Missing main DLL and
non-Windows still explicitly skip without downloading. Missing dependencies
fail rather than masquerading as a successful skip. The absent-main-DLL branch
was preserved/reviewed, not exercised by moving the shared approved binary.

Only A0b tool/manifest/test/research files and this owner's progress section
changed. Shared geometry, D4 and D3 helpers remain read-only. Diagnostic variant
filenames retain their original fixture ID for the existing D3 eligibility
check, with identical source/reference/control checks. This is not an expanded
exception. Tests assert liga-on diagnostics have identical D3/D4 results to
their original cases. No network, download, new dependency or sub-agent ran.

### A and B: same inputs, independent results

A is the unchanged shared comparison: cluster start; cluster end against the
last WebKit component end; both component rotations converted to displacement;
and unchanged D4. B keeps every cluster start, run total advance against
computedTextLength, and rotation displacement only for one-UTF-16-component
clusters in this BMP fixture. Ends and multi-component rotations remain
diagnostics. B uses the actual applied glyph scale for run advance; spacing
gaps are excluded, matching WebKit's spacing computedTextLength=72.763671875.
spacingAndGlyphs advance=180 versus WebKit 179.99996948242188 (0.000031 px).
No angle, pixel, component-count or 0.5 px tolerance was changed.

The following table describes the original whole-cluster/default-liga route,
retained as `cases` in report.json. G=geometry; final=G AND D4 AND conservation.
The extra feature experiments below never silently replace a case or a gate.

| Case | A max px | A G/final | B max px | B G/final | D4 I/E/B/C/S |
| --- | ---: | --- | ---: | --- | --- |
| svg-text-positive | 1.230398 | F/F | 0.103859 | P/F | P/P/P/F/P |
| svg-text-boundary | 1.230398 | F/F | 0.103859 | P/F | P/P/P/F/P |
| svg-text-nested | 1.230398 | F/F | 0.103859 | P/F | P/P/P/F/P |
| svg-text-path-none | 0.775690 | F/F | 0.103859 | P/P | P/P/P/P/P |
| svg-text-path-spacing | 11.162514 | F/F | 0.095346 | P/F | P/P/P/F/P |
| svg-text-path-spacingAndGlyphs | 1.775340 | F/F | 0.356530 | P/F | P/P/P/F/P |

**svg-text row: A=FAIL, B=FAIL.** B changes only path-none's final verdict.
Main owns the A/B decision. Every final case still confirms the original
default-shaping fixture clusters and source/CFI/glyph conservation. B's unit
test independently rejects a wrong run advance while excluding only the two
specified diagnostic channels. D4 is a shared single result, not reimplemented.

### H1: optional fi decomposition, not a sufficient liga=0 fix

Feature ABI is a checked Dart Struct with tag/value/start/end; liga=0 applies
to the entire run. No substring shaping or outline cropping is used. Glyph
444 / cluster [3,5) becomes glyphs 74 and 77 / [3,4),[4,5). The long raw shaped
width increases from 72.763671875 to 73.486328125 (+0.72265625 px).
Both the per-character oracle and PNGs show separate f and dotted i for
spacing. However, WebKit keeps computedTextLength=72.763671875 and places i
using the default ligature's half-advance slot, not the raw unligated advance.
Thus simply switching liga off changes layout incorrectly.

A second, explicitly diagnostic model shapes the whole run twice: default
shaping supplies layout width and equal component slots within its clusters;
liga=0 supplies complete painted glyphs and their natural end/rotation extent.
Both results are retained until scene teardown. The model reads no oracle
coordinate/rotation/PNG in layout. Reported raw glyph advances remain unchanged.
The fixture map disagreement is explicit in `fixtureClusterMapsMatch`; the
comparison uses actual HB paint clusters, with a separately checked refinement
of the declared layout clusters. This does not claim the declared fi remains
one paint cluster with liga=0.

| Probe / paint-layout mode | Max start px | A max px | B max px | D4 components native/ref | D4 |
| --- | ---: | ---: | ---: | --- | --- |
| none / default | 0.103859 | 0.775690 | 0.103859 | 4/4 | P |
| none / raw liga=0 | 1.482145 | 1.482145 | 1.482145 | 6/4 | F |
| none / liga=0 + default slots | 0.088848 | 0.118032 | 0.088848 | 4/4 | P |
| spacing / default | 0.095346 | 11.162514 | 0.095346 | 6/8 | F |
| spacing / raw liga=0 | 1.142271 | 1.142271 | 1.142271 | 7/8 | F |
| spacing / liga=0 + default slots | 0.076281 | 0.181220 | 0.076281 | 6/8 | F |
| spacingAndGlyphs / default | 0.356530 | 1.775340 | 0.356530 | 7/8 | F |
| spacingAndGlyphs / raw liga=0 | 2.642196 | 2.642196 | 2.642196 | 8/8 | F |
| spacingAndGlyphs / liga=0 + default slots | 0.339569 | 0.877365 | 0.339569 | 7/8 | F |

CSS reference: CSS Text Module Level 3, section 7.2, Tracking: the letter-spacing
property (`https://www.w3.org/TR/css-text-3/#letter-spacing-property`). Its
nonzero-effective-spacing rule recommends suppressing optional ligatures;
mandatory script ligatures are exempt. It does not by itself prove WebKit's
SVG textLength implementation, nor require suppression for pure glyph scaling.
No online fetch was attempted under this round's explicit no-network rule.

Conclusion: spacing's PNG supports decomposed fi painting; H1 as a complete
"turn liga off" explanation is rejected. Neither raw feature choice passes
both starts and full D4 for either adjusted probe. The default-slot diagnostic
improves spacing geometry to 0.181220 px but still fails D4: native i dot/stem
are one connected support component [116,56,121,71], versus reference dot
[116,55,118,58] plus stem [116,59,121,71]; native e/acute likewise merge,
where the reference acute [155,51,160,55] is separate from e [152,56,162,68].
These are real raster-topology failures, not new exemptions. spacingAndGlyphs
also retains the e-acute end=0.541114 / rotation-displacement=0.877365 miss.
No adjusted probe earns a certified liga switch. The successful unadjusted
model is evidence for the bounded SVG decomposition explanation only; it is
not silently generalized or adopted into the required-case route.

### H2: locate every upper-run component discrepancy

All bounds below are pixel LTRB in positive/boundary screenshots, before the
nested (7,9) translation. Source geometry stays in SVG user coordinates.

| Upper ink | Native support bounds | WebKit support bounds | Diagnosis |
| --- | --- | --- | --- |
| A | [140,25,153,40] | [140,26,153,40] | Pairable within D4's existing 1 px bounds rule |
| b | [156,26,167,43] | [156,26,167,43] | Exact component bounds |
| fi | [173,27,183,42] plus [178,32,183,43] | [173,26,183,42] | Two versus one: the only upper-run unmatched components |

The fi start is exactly (171.072265625,41); native and both WebKit rotations
are exactly 10 degrees. This is not an x/y/dx/dy/anchor or rotation error.
Native whole-cluster end=(181.978242109,42.923017905), WebKit last-component
end=(181.389160156,41.842803955): 1.230398 px. The end-channel semantic
disagreement and the actual component-topology failure are distinct evidence.

The complete positive default-slot/liga=0 diagnostic has max start=0.088848,
A max=0.118032, B max=0.088848 and **all D4 channels pass**, 7/7 components.
Its upper fi bound [173,27,183,42] pairs with the single reference component.
The unchanged positions/angles with different glyph decomposition explain
the failure; simply raw liga=0 still fails (A/B max=1.482145; 9/7 components).
The same diagnostic also passes path-none, so decomposition is not specific
to nonzero CSS spacing. This is host-observed behavior, not a WebKit internals
trace or proof of a general SVG shaping implementation.

### Final checks, lifetime and remaining risks

Direct SDK commands from repository root, with no PATH assignment:
`dart.exe format --set-exit-if-changed <the six changed Dart files>`: exit 0.
`dart.exe analyze <the same six files>`: exit 0, no issues.
`dart.exe flutter_tools.snapshot test test/tool/reader --no-pub --reporter expanded`:
exit 0, **7 passed**, including two A0b tests. Focused A0b executions also
exited 0. All executed experiment tests establish evidence/conservation,
not a passing svg-text row. Scoped diff whitespace check: exit 0.

Final ledger: 31 buffers; 218 outline owners; 10 scoped 16-byte feature inputs;
five callback thunks; one blob/face/font/draw_funcs. All owned live counters and
payloads finish at zero. Peak retained outlines=26 / logical payload=7564 bytes;
borrowed glyph-array payload peak=360 bytes. Dual-shaping diagnostics raise
these peaks; they are not production memory acceptance. DLL modules, registered
engine font, opaque caches, Path storage and RSS remain process/unmeasured costs.

iOS remains unexecuted: approved 14.6.0 source hash, static device/simulator
XCFramework, full symbol prefixing and link-map provenance, Old MIT notices,
release/AOT callback retention, on-device raster topology and lifetime/RSS proof.
Windows dependency preloading supplies no iOS packaging evidence. D2 and all
required rows remain in force; main/A2 must keep adjusted curved SVG text open.
No shared-helper change is requested. The probe stops after this final slice.

## Round 3: owner-extended painting rule (2026-10-28)

### Rule recorded before implementation

This is an inference from WebKit 27.2's six required records and PNGs, not a
claim about WebKit source internals or unmeasured scripts/paths. Keep default
whole-run HarfBuzz shaping for advance and equal UTF-16 component slots inside
each layout cluster. Paint optional-ligature components as independently
positioned fragments of a liga=0 run, retaining base-plus-combining-mark
shaping. Each fragment uses its
first character's slot for placement; its complete natural glyph advance and
outline remain independent of that slot. A combining continuation has zero
reported advance at the base's natural end and shares its rotation.

For positioned text, apply the character's authored position/rotation to its
fragment. On a path, choose the tangent at the midpoint of the first character's
scaled metric slot, and back up half that slot along the tangent. Paint the
whole fragment there. Apply spacing by original UTF-16 index; spacingAndGlyphs
scales both metric slots and outlines. Do not use the full combining fragment's
advance for its tangent. The bounded quadratic reference traverses a 256-chord
dyadic polyline, rather than Flutter's PathMetric or an analytic tangent.

Evidence before implementation:
- positive/boundary: fi's two origins are 171.072265625 and 176.609375, both
  at y=41/10 degrees; their gap is half the default 11.07421875 advance.
  Round-2 component painting passes D4 at these origins; rigid fi does not.
- nested: the same character records and topology recur under (7,9), clip and
  .8 opacity; no new placement parameter is needed.
- path-none: f/i have distinct rotations; e and acute share -19.83189 degrees,
  and the acute is zero-width at e's end. The first-slot midpoint explains both.
- path-spacing: computedTextLength stays 72.763671875 while gaps increase by
  (180-72.763671875)/9 per original UTF-16 position; e/acute share .429607 degrees.
- path-spacingAndGlyphs: computedTextLength becomes 179.99996948242188; e/acute
  again share .429607 degrees. A full-cluster midpoint predicts 2.34746 instead.
- Across all three path probes, inverse quadratic slopes recover segment
  midpoints (odd integers)/512 for every non-continuation character. A single
  256-chord traversal and first-slot midpoint predicts every origin within
  .000485 px and every rotation within .000035 degrees (double arithmetic).

The 256-chord resolution is one observed reference-profile constant, shared by
all quadratic paths in this bounded adapter, not a per-case correction. Other
curves/scales and Safari versions need independent evidence before generalizing
the traversal resolution. Neither this inference nor fragment reshaping yet
establishes that raster D4 passes; that is the implementation experiment below.

### Paint amendment recorded before implementation

The first implementation confirms first-slot/chord placement (all six A/B
maxima <.0005 px) but adjusted D4 remains 6/8 components. Geometry alone cannot
explain the topology. A local Windows GDI outline query, using the actual HB
glyph IDs and a memory-loaded font whose GetFontData bytes exactly equal the
171676-byte pinned font, measures grid-fitted i yMax=15 versus OT yMax=14.4140625,
and e-acute yMax=16 versus OT yMax=15 at nominal 20 px. This matches the reference
dot/acute upper bounds (55/51) versus native unhinted bounds (56/52).

Amend the single fragment rule to grid-fit glyph outlines at nominal font size
before applying the SVG fragment rotation and lengthAdjust transform. Preserve
HarfBuzz glyph IDs and unhinted advances; do not substitute GDI layout metrics.
This is a host-specific raster-backend inference to test, not proof that Safari
uses GDI. Obtain outlines by glyph ID from the exact font, never crop contours,
shift accents/dots separately, or read oracle pixels during painting. A5 must
recheck glyph grid fitting and topology on its own CoreText-backed platform.

Nominal-size grid fitting alone is insufficient: it passes spacing but splits
the unadjusted e/acute into two components (reference one), and scaled fi still
merges its dot. A second GDI query supplies the actual fragment rotation and
horizontal scale as MAT2. Inverting that transform for comparison gives
e-acute yMax=14.88169 at -19.83189 degrees, rather than the axis-aligned 16;
at .429607 degrees it remains 16.00008, and horizontal scaling changes its
x fitting too. Thus the testable general amendment is **transform-aware grid
fitting of each HB glyph**, not nominal-size fitting followed by an unrelated
rotation/scale. Apply the same transform-aware API for all fragments/cases.
Neither fitting choice changes source membership, glyph IDs or advances.

### Final measured result: placement confirmed, painting candidate rejected

There is **no certified general WebKit painting rule closing D4** in this
slice. First-slot placement is strongly supported; transform-aware GDI fitting
is an explicitly unaccepted host painting approximation. It passes spacing,
but fails nested and spacingAndGlyphs. Selecting hinting by case, opacity or
lengthAdjust to assemble passes would have no independently established rule
and was not implemented. The per-character-own-shaped-run hypothesis is not
proved: the evidence supports fragment placement, and the implementation uses
two whole-run HB shapes, not isolated substring shaping.

`report.json.cases` uses the same transform-aware fitting rule in every required
case. `rasterComparisons` retains all six unhinted first-slot-fragment renders;
`featureComparisons` retains the eleven round-2 variants. No oracle coordinate,
rotation or PNG enters layout or painting. The generic 256-chord traversal uses
source quadratic control points for all cases; its resolution is observed
behavior of this bounded reference, not an established arbitrary-path policy.

| Case | B max px / geometry | A max px diagnostic | D4 I/E/B/C/S | Components native/ref | B final |
| --- | --- | ---: | --- | --- | --- |
| svg-text-positive | .000115495 / P | .000122662 | P/P/P/P/P | 7/7 | P |
| svg-text-boundary | .000115495 / P | .000122662 | P/P/P/P/P | 7/7 | P |
| svg-text-nested | .000115495 / P | .000122662 | P/P/P/F/P | 8/7 | F |
| svg-text-path-none | .000115495 / P | .000122662 | P/P/P/P/P | 4/4 | P |
| svg-text-path-spacing | .000484398 / P | .000484398 | P/P/P/P/P | 8/8 | P |
| svg-text-path-spacingAndGlyphs | .000471645 / P | .000475706 | P/P/P/F/P | 7/8 | F |

**svg-text row: B=FAIL; diagnostic A=FAIL.** All gated geometry passes at the
unchanged .5 px value. Nested's hinted path fi splits into [61,70,69,87] and
[68,74,74,85], where WebKit has one [61,71,74,87]. Scaled f and i-dot remain
one native [106,54,128,72] component versus separate reference f
[106,54,121,72] and dot [122,54,128,57]; the i stem is separate in both.
The scaled acute/e topology now matches. All other D4 channels pass, including
zero interior mismatches, one-pixel edge/support rules and exact samples.
Raw changed pixels: 625/625/614/405/373/679 in table order, still reported.

Unhinted fragments pass D4 for positive/boundary/nested/none, fail spacing and
spacingAndGlyphs (6/8 in each), with exactly the same A/B geometry. Nominal-only
GDI fitting, tested before transform-aware fitting, also failed the full row:
8/7,8/7,8/7,5/4,8/8,7/8 components respectively. These failures distinguish
layout accuracy, font grid fitting and final raster support; none is waived.
The residual rasterizer/coverage cause remains unproved. No replacement
reference, alpha threshold, glyph crop, per-case constant or D3 scope was used.

D3 is the existing shared helper only: RD-1 exempts exactly (0,0) in positive,
boundary and all three path probes, zero pixels in nested. RD-2 exempts zero in
every case. Shared geometry/D4/D3 helper hashes equal the pre-slice report.
`round3-inspect.png` is a visual contact sheet of candidate/unhinted/reference
for every required case; all original per-case PNGs and raw D4 data remain.

### Shaping, source geometry and lifetime

The painted unit is a **component fragment**, not the default ligature cluster.
The actual liga=0 HB paint map refines fi to [3,4),[4,5), and retains [6,8)
for e+acute. Default shaping supplies layout membership and advance; paint
membership, default `layoutClusterUtf16`, `placementAdvance`, `paintedUnit`,
`outlineProvenance` and traversal provenance are exported explicitly. Both
maps come from HB. The fixture-map disagreement remains visible; confirmation
means exact refinement of every declared layout cluster, not equality to it.

Full cases paint 14 glyphs and cover 15 UTF-16 units; path probes paint 9 glyphs
and cover 10 units. Each paint glyph, including empty-outline spaces, is emitted
once; every original source unit and its CFI round trip is conserved. GDI is
called by HB glyph ID, never by character, and GetFontData SHA/length checks
reject a different face. Complete GGO_NATIVE contours become Paths with the
original fill; no contour is clipped, removed or repositioned independently.
GDI layout advances are ignored. The original unhinted f+acute overhang control
remains an independent, reference-unverified control, not a required-case pass.

Ledger: 58 HB buffers, 485 outline owners, 28 feature inputs, five callback
thunks; one blob/face/font/draw_funcs; one GDI memory-font/DC/font owner and
120 scoped GDI scratch allocations. All owned handles, callbacks, outlines and
payload counters end at zero. Peak outlines=27 / logical payload=8129 bytes;
borrowed glyph payload=360; GDI scratch=171676. System GDI font/raster allocations,
HB caches, actual Path backing, GPU and RSS are unmeasured. GDI font/DC/resource
handles are actually deleted/removed; system DLL modules and the separately
registered ui font remain process resources. This supplies no A3 budget proof.

### Content identity, verification and requests

Start/end canonical measured hashes (also checked against the pre-edit snapshot):
- corpus: `6c0db5fba6b3b76b7ed9d9bf45d3510b2fb1db3375b4cea86e27ec0212e70b65`
- oracle: `699af229946ad242b4cff9d9184b856467ce85ecb01db635185716ac8492af87`

Both are unchanged. Canonicalization recursively sorts object keys, retains
array order, encodes compact UTF-8 JSON, and selects all four SVG text case
records (including unsupported) plus all three probes in each input. It removes
`clusterSource`, `clusterConfirmation` and evidence/provenance fields only;
sources, measurements, PNGs, samples and maps stay hashed. Python's pre-edit
snapshot and Dart produce the same digests. Whole-file digests are informational
only; the round-2 whole-file pins no longer block A2's provenance regeneration.

Changed Dart scope (only these eight files are formatted/analyzed):
`tool/reader/harfbuzz_probe{,_scene,_shape,_inputs,_path,_gridfit,_gridfit_path}.dart`
and `test/tool/reader/harfbuzz_probe_test.dart`.
Final direct SDK commands: format --set-exit-if-changed on this scope: exit 0;
analyze on this scope: exit 0, no issues; flutter_tools.snapshot test
test/tool/reader/harfbuzz_probe_test.dart --no-pub --reporter expanded: exit 0,
three tests passed. Tests verify execution/conservation, geometry, paired D3,
hash sensitivity and cleanup, never require or invent a D4 pass. Earlier check
found two brace lint infos (fixed); an intermediate test failed because the
new fitting changed the historical overhang control (its original unhinted
control mode was restored). An optional hb-shape.exe launch was unavailable;
local ctypes HB inspection replaced it. No dependency/download/network ran.

A5 must re-verify fragment decomposition versus ligature metrics, combining
first-slot placement, spacing distribution, child/parent textLength behavior,
path subdivision/tangents at other curves/scales, device font hinting and
raster component topology, DPR, nested opacity/clip, and the independently
reproduced D3 scope on the iPhone's actual Safari version. GDI is Windows-only;
it is not an iOS implementation or proof of Safari internals. All earlier iOS
source-pin/static packaging/symbol-prefix/release/lifetime risks remain open.

Requests: A2/main keep the svg-text row open under D2; do not adopt the GDI
candidate as a passing renderer. No shared helper change is requested. A full
platform glyph-rasterizer comparison is needed to establish the remaining
paint rule; no new raster dependency is authorized or fetched in this slice.
Round 3 ends here; neither A0b nor the parent task is marked complete.
