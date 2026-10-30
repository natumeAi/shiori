# HarfBuzz iOS packaging plan — A2-text segment 7a

2026-10-28 plan; CI wiring implemented on 2026-10-30 after the owner's
"Approve HarfBuzz" approval. The main session verified the official 14.6.0
source asset independently: 20,295,260 bytes, SHA-256
`d07a007327277708a2a73ae437887cdbaf282937f6d03ca5467723e9099af586`.
`tool/ci/build_harfbuzz_ios.sh` now pins that identity and verifies it before
unpacking in CI. No source was downloaded on this Windows wiring session;
no Apple compilation, CI result or device launch is claimed here. The Windows
ZIP/DLL hashes are not substitutes for this source hash.

## Prefixing and static artifact

Pin the official HarfBuzz 14.6.0 release tarball, verify SHA-256 before unpacking,
and retain the archive identity, source notices, compiler/Xcode/SDK versions,
configuration logs, prefix map and per-architecture symbol inventories.

The script scans the pinned source's C/C++ identifiers and force-includes a
generated macro header in **every** translation unit. `hb_*` becomes
`shiori_hb_*`; private `_hb_*` becomes `shiori__hb_*`. Source-declared C++
namespaces (OpenType/AAT/etc., excluding `std`) are also prefixed, to avoid
colliding with Flutter's C++ HarfBuzz implementation. Both declarations and
definitions see the same map. This avoids renaming undefined system functions
such as malloc/free, which a blanket binary `--prefix-symbols` would also rename.
Public headers are consumed through `shiori-harfbuzz.h`, which includes the
prefix map before `hb.h`. Dart uses the prefixed C ABI directly.

Build static device arm64 and simulator arm64/x86_64 archives, using the same
prefix map and iOS 15.0 deployment target (the current Runner target). Disable
GLib/GObject, ICU, FreeType, CoreText and Graphite2; this module uses OT font
functions and HB outline drawing, with no platform-font substitution. Disable
the subset library. Declared optional utilities/tests/raster/vector/GPU/Cairo/
introspection controls are also disabled, with enabled HB_BUILD_/HB_HAVE_ cache
options rejected. Unknown supplied CMake options fail instead of silently
enabling a dependency. Combine simulator slices with lipo and package the
device/simulator libraries and headers using `xcodebuild -create-xcframework`.

Audit each thin archive's defined **and undefined**, demangled symbol names.
Any remaining unprefixed `hb_*`/`_hb_*` fails. A second strict inventory rejects
externally defined names lacking `shiori_`; there is no permissive allowlist.
The defining C++ scope is checked from the Mach-O Itanium name; a prefixed
parameter type cannot excuse an unrelated global. This deliberately catches
unanticipated C++ globals and compiler-generated helpers. Lexical discovery
alone is not proof of complete prefixing: generated
or token-pasted symbols and compiler helpers may require a reviewed adjustment
on the approved toolchain. No such archive is accepted until both audits pass.
Preserve inventories in the XCFramework artifact provenance.

## Xcode and Flutter integration (implemented; Apple CI evidence pending)

`build_ios_unsigned.sh` invokes the source build before `flutter build ios`.
The workflow uses the runner's preinstalled CMake and checks its availability;
no package manager, additional fetched toolchain or cross-run cache is used.
The actual CMake path/version, Xcode, clang and device/simulator SDK versions
are recorded. A missing prerequisite fails explicitly.

Runner has no Podfile and links Flutter directly. Debug and Release include
`ios/Flutter/HarfBuzz.xcconfig` as the sole HarfBuzz link owner. It selects
the device arm64 or combined simulator archive by SDK with a scoped
`-force_load`, inherits existing linker flags, links system libc++, and enables
`-export_dynamic` additively so main-executable globals remain visible to
process lookup. It does not install a restrictive export list. The source-build
script generates a build-only xcconfig containing the fresh archive directory
and `-Wl,-u,_shiori_hb_*` roots extracted from `HarfBuzzBindings._required`
(33 entries on 2026-10-30); the archives and every required definition are
audited before that configuration is published. No generated Flutter/Pods file
or project.pbxproj is edited. All libraries remain static, Do Not Embed.

After Flutter's Release build/strip, `--verify-runner` checks the actual app
executable's defined external symbols (`nm -gUj`) and dyld export trie
(`dyld_info -exports`). The live link-map section must attribute every required
name to the newly built device archive, excluding dead-stripped definitions.
Any missing definition/export or wrong/missing archive owner fails packaging.
The raw-HB ban remains confined to the new archives, leaving Flutter's HB alone.

`build/ios-$BUILD_MODE/harfbuzz/` retains source identity and input hashes,
COPYING and its verified hash, toolchain versions, generated prefix/root maps,
per-slice CMake caches/configure/build/install logs, raw/demangled symbol and
global inventories, all three thin archive hashes and the combined simulator
hash, the zipped static XCFramework, final executable inventories/hash/audit,
and full/excerpted link maps. The existing always-upload step covers this
directory, including available logs when a build/audit fails.

The following packaging and device acceptance requirements remain in force:

1. Retain the static XCFramework for distribution/review; Runner directly
   links its audited device/simulator archive inputs via xcconfig, **Do Not
   Embed**. Add headers only if native code consumes them. Do not ship the
   Windows DLLs or add GLib/libintl to iOS. Do not link unprefixed libharfbuzz.
2. Direct xcconfig linkage is selected because Runner has no Podfile.
   Keep exactly one owner of the library link; do not additionally register
   the XCFramework or create a CocoaPods link owner. Any future ownership
   migration must remove the old owner and leave generated files untouched.
3. Retain the functions used by `HarfBuzzBindings` in Release/AOT. Use a scoped
   `-force_load` of the selected static archive, plus linker roots/exports for
   every prefixed entry in `HarfBuzzBindings._required`, e.g.
   `-Wl,-u,_shiori_hb_shape`. DynamicLibrary lookup does not itself create a
   static-link reference, and force_load alone does not defeat dead stripping.
   Merge these names with Runner's existing export policy; never replace other
   Flutter/plugin exports with a HarfBuzz-only list. Enable a link map.
4. Verify the final Runner executable, not only the archive: required
   `_shiori_hb_*` exports exist and point into the new linked objects. Flutter's
   own embedded library is expected to remain untouched. Restrict the no-raw-HB
   symbol audit to this artifact's objects, because Flutter owns separate HB.
5. On iOS, default bindings call `DynamicLibrary.process()` and look up
   `shiori_` + `hb_*`. Empty prefixes are refused on iOS. The runtime version
   must be exactly 14.6.0; missing symbols fail eagerly with
   `HarfBuzzException(missingSymbol, symbol: ...)`, before native font objects.
6. Run an actual Release/AOT launch and all six module fixtures on device and
   simulator; verify NativeCallable retention, callback isolate/thread rules,
   font use, repeated prepare/cancel/dispose and process/RSS lifetime. Then run
   the authored scene gate after SVG integration. Host evidence proves none of
   these Apple linkage, device raster or performance properties.

## S4c licence notice

HarfBuzz's root COPYING identifies the Old MIT licence and requires preservation
of its copyright notice and both permission/disclaimer paragraphs in copies.
Carry the **complete unmodified** 14.6.0 source COPYING and applicable per-file
notices, including notices for compiled generated data. Review subdirectory
COPYING/LICENSE files against the actual compile inventory. The existing
downloaded notice is local evidence only (SHA-256
`ba8f810f2455c2f08e2d56bb49b72f37fcf68f1f4fade38977cfd7372050ad64`),
also verified against the approved source by the main session. CI now checks
that hash after unpacking and retains the complete notice. Product registration
and applicable per-file notice review remain S4c release work.

S4c should bundle the reviewed text as a product asset and add a
`LicenseRegistry.addLicense` generator yielding a `LicenseEntryWithLineBreaks`
for `HarfBuzz 14.6.0 (Shiori static build)`. Asset loading/registration belongs
in initialization control work. Verify the product's licence view includes
the full notice in Release. This slice edits neither pubspec nor product UI.
The Windows test DLL chain's GLib/libintl licences do not define the statically
linked iOS dependency set; any future Windows distribution needs its own audit.

## Binary-size estimate method

No iOS byte estimate is asserted from the 1,738,752-byte Windows DLL. On one
approved Xcode/Flutter/SDK configuration, compare otherwise identical Release
arm64 Runner archives with and without the new artifact. Record raw thin `.a`
bytes and object section sizes (`size -m`/equivalent), final stripped executable
and app sizes, compressed IPA delta and dSYM size separately. Use link-map
object contributions plus the prefixed symbol inventory to attribute retained
HB text/data; report dead stripping and linker export settings. Simulator/fat
archive size is not delivered device size. Repeat the two builds to identify
build noise and retain flags, architecture and hashes with the estimates.

## Host API and ownership contract

Entry point: `lib/features/reader/engine/text/harfbuzz/harfbuzz.dart`.
`HarfBuzzAdmittedFont.load` coalesces A3's exact canonical face descriptor in
the existing ProcessFontBudget (shared by default); it does not alter the key.
A3 must retain immutable admitted SFNT bytes and their encoded lease. WOFF
conversion, format/descriptor validation and required-font selection remain
A3's responsibilities. Cancellation of a registering waiter preserves the
started registration's permanent process charge; A3 supplies its drain barrier.

`HarfBuzzFont.open` copies admitted bytes into reserved native storage and owns
blob/face/font/draw functions plus five synchronous isolateLocal callbacks.
`shapeRun` accepts direction/script/language/features. This established SVG
placement profile accepts horizontal LTR and returns typed unsupportedRun for
other directions; it does not claim RTL/vertical support. One request performs
two whole-run shapes: requested layout features and those features plus liga=0
for paint. Layout advances and paint refinements remain independently exposed.
Default glyph capacity is 8 * UTF16 length + 16, capped at 65,536; explicit
capacity is injectable. Output exceeding capacity is refused without publishing.

`HarfBuzzRun.place` reuses shaped data, indexed slot offsets and outlines. It
accepts per-UTF16 authored positions/rotation, middle anchoring, textLength and
spacing/spacingAndGlyphs, or a separately owned quadratic traversal and absolute
or percentage startOffset. The established path rule uses 256 chords and the
first component slot's midpoint. Base/combining continuation remains one paint
fragment. Each result exposes independent Paths, glyph indices, layout range,
placement advance and ClusterGeometry with provenance shaped. sourceOffset
relocates run-relative UTF16 ranges; A2 maps across original text nodes.

Inject `HarfBuzzResources` with the existing shared scene ledger or a prepaid
suballocation ledger owned by the scene admission. Do not create an extra
reading-unit budget. Handles/callbacks reserve sourceNodes and conservative
sourceBytes before creation; malloc reserves exact payload bytes before malloc.
Shaping input/copied output/native buffer workspace is reserved before HB
allocation/preallocation. A count-only outline pass reserves complete vector
verbs/double coordinates before constructing Path; the emission pass cannot
exceed those reserved counts. Placement reserves its own complete transformed
Path payload while original outlines remain charged.

Dispose placed results, shaped runs, quadratic traversals and fonts exactly
once (repeated dispose is harmless). A placed result outlives its font/run.
Path.reset plus dropping the owner's reference releases logical ownership;
actual Path backing collection remains engine/GC-controlled. Borrowed Paths
must not be mutated or retained past result disposal. Guarded control APIs
refuse pointer/ticker work before mutation; motion only paints retained Paths.
HB calls are synchronous and cannot be preempted mid-call by same-isolate
cancellation. Check the token before work and after C returns; keep reservations
until physical work and destruction drain. An already canceled shape does no
buffer/outline work. Do not describe a canceled waiter as native teardown.

## Requests and open risks

- A2-svg: call the module during scene preparation with resolved font/style,
  flattened authored UTF16 positions and the correct textLength scope. Retain
  placed Paths in the scene, compose nested/page transforms once, split source
  ranges across original nodes, and attach actual clip/mask/opacity/paint-order
  evidence. Preserve both layoutCluster and refined paint-fragment membership.
  Do not route required text to Complete until D4 also passes.
- A3: supply the exact admitted face descriptor/collection index, immutable SFNT
  lease, shared process owner and font-registration drain barrier. Supply a
  prepaid scene subledger or account these direct charges once in its plan;
  both original and placed paths overlap during preparation. Old/new fonts stay
  charged until actual destruction. No new process budget or unload is added.
- Main/native owner approved the official source pin, CI download and build/
  linkage on 2026-10-30. Wiring is implemented; actual macOS toolchain/
  architecture support, strict prefix-map/global audits, final executable
  exports and link-map attribution still require the first CI run. Compiler
  helpers or unexpected C++ definitions must fail and return for review;
  there is no symbol allowlist. Device/AOT version/fixture checks remain A5.
- Host unhinted D4 remains failed for nested, path-spacing and
  path-spacingAndGlyphs under D7, despite all B geometry passing. No GDI fitting,
  contour edit, new D3 exemption or case-specific painting switch is adopted.
- Native HB allocation growth/caches/language interning, compiler callback
  thunks, actual Path memory, GPU and process RSS remain separately unmeasured.
  HB buffer preallocation is not a hard native allocator cap; copied output and
  logical workspace admission do not prove total native peak memory. A5 must
  measure peaks and device glyph coverage before resource/fidelity acceptance.
- Traversal resolution, optional ligature decomposition, child/parent length
  scope, combining-slot behavior, fallback fonts and hinting on other curves,
  scripts, scales and Safari versions need independent device evidence.
