#!/usr/bin/env bash
# Owner-approved source build (2026-10-30). No cross-run cache.
set -euo pipefail

HB_VERSION=14.6.0
HB_SHA256='d07a007327277708a2a73ae437887cdbaf282937f6d03ca5467723e9099af586'
HB_COPYING_SHA256='ba8f810f2455c2f08e2d56bb49b72f37fcf68f1f4fade38977cfd7372050ad64'
HB_PREFIX=shiori_
HB_URL="https://github.com/harfbuzz/harfbuzz/releases/download/${HB_VERSION}/harfbuzz-${HB_VERSION}.tar.xz"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# One source of truth for archive audits, linker roots and executable audits.
# This read-only mode works on Windows without native tools or downloads.
required_symbols() {
  python3 - "$REPO_ROOT/lib/features/reader/engine/text/harfbuzz/hb_bindings.dart" <<'PY'
import pathlib, re, sys
source = pathlib.Path(sys.argv[1]).read_text(encoding='utf-8')
matches = re.findall(r'static\s+const\s+_required\s*=\s*\[(.*?)\];', source, re.S)
if len(matches) != 1:
    raise SystemExit('Expected exactly one HarfBuzzBindings._required literal')
body = re.sub(r'//[^\n]*|/\*.*?\*/', '', matches[0], flags=re.S)
names = re.findall(r"'(hb_[A-Za-z0-9_]+)'", body)
remainder = re.sub(r"'(hb_[A-Za-z0-9_]+)'|[\s,]", '', body)
if remainder or not names or len(names) != len(set(names)) or 'hb_version_string' not in names:
    raise SystemExit('Unsupported or duplicate _required entries; review extraction')
print(''.join('_shiori_' + name + '\n' for name in names), end='')
PY
}
if [[ "${1:-}" == --print-required-symbols && $# == 1 ]]; then
  required_symbols
  exit 0
fi

# Audit Flutter's final Release/stripped executable, not an intermediate binary.
if [[ "${1:-}" == --verify-runner && $# == 3 ]]; then
  executable="$2"
  provenance="$3"
  test -s "$executable"
  required_symbols > "$provenance/runner-required-symbols.txt"
  cmp "$provenance/required-symbols.txt" "$provenance/runner-required-symbols.txt"
  xcrun nm -arch arm64 -m "$executable" > "$provenance/runner-symbols.txt"
  xcrun nm -arch arm64 -gUj "$executable" > "$provenance/runner-defined-globals.txt"
  xcrun dyld_info -arch arm64 -exports "$executable" > "$provenance/runner-exports.txt"
  HB_RUN="$(cat "$provenance/build-root.txt")"
  cp "$HB_RUN/Runner-Release-iphoneos-arm64.map" "$provenance/Runner-LinkMap.txt"
  shasum -a 256 "$executable" > "$provenance/runner-sha256.txt"
  python3 - "$provenance" "$HB_RUN/device-arm64/install/lib/libharfbuzz.a" <<'PY'
import pathlib, re, sys
root, archive = pathlib.Path(sys.argv[1]), sys.argv[2]
required = set((root / 'required-symbols.txt').read_text().splitlines())
defined = set((root / 'runner-defined-globals.txt').read_text().splitlines())
exports = set(re.findall(r'(?<![A-Za-z0-9_])_shiori_hb_[A-Za-z0-9_]+',
                         (root / 'runner-exports.txt').read_text()))
missing, unexported = required - defined, required - exports
objects, live, excerpt = {}, {}, []
section = ''
for line in (root / 'Runner-LinkMap.txt').read_text().splitlines():
    if line in {'# Object files:', '# Sections:', '# Symbols:', '# Dead Stripped Symbols:'}:
        section = line
    if section == '# Object files:':
        match = re.fullmatch(r'\[\s*(\d+)\]\s+(.+)', line)
        if match and (match[2].startswith(archive + '(') or match[2].startswith(archive + '[')):
            objects[match[1]] = match[2]
            excerpt.append(line)
    if section == '# Symbols:':
        match = re.fullmatch(r'(0x[0-9A-Fa-f]+)\s+(0x[0-9A-Fa-f]+)\s+\[\s*(\d+)\]\s+(\S+)', line)
        if match and match[4] in required:
            if match[4] in live:
                raise SystemExit('Duplicate required link-map definition: ' + match[4])
            live[match[4]] = match[3]
            excerpt.append(line)
(root / 'Runner-LinkMap-harfbuzz.txt').write_text('\n'.join(excerpt) + '\n')
wrong_owner = {name for name in required if live.get(name) not in objects}
if missing or unexported or wrong_owner:
    raise SystemExit(f'Runner audit failed: undefined/missing={sorted(missing)}, '
                     f'not exported={sorted(unexported)}, wrong/missing archive owner={sorted(wrong_owner)}')
(root / 'runner-audit.txt').write_text(
    f'PASS: {len(required)} required symbols defined, exported and owned by {archive}\n'
    'Runtime version 14.6.0 and device/AOT execution remain device gates.\n')
print((root / 'runner-audit.txt').read_text(), end='')
PY
  exit 0
fi
[[ $# == 1 && "$1" != --* ]] || {
  echo 'Usage: build_harfbuzz_ios.sh <provenance-directory> | --print-required-symbols | --verify-runner <executable> <provenance-directory>' >&2
  exit 2
}

if [[ ! "$HB_SHA256" =~ ^[0-9a-f]{64}$ ]]; then
  echo 'STOP: owner approval and a reviewed source SHA-256 pin are required.' >&2
  exit 2
fi
[[ "$(uname -s)" == Darwin ]] || { echo 'macOS/Xcode required' >&2; exit 2; }
for command in curl shasum tar python3 cmake xcrun xcodebuild; do
  command -v "$command" >/dev/null || { echo "Missing $command" >&2; exit 2; }
done

mkdir -p "$1"
HB_PROVENANCE="$(cd "$1" && pwd)"
HB_WORK="$REPO_ROOT/build/third_party/harfbuzz-ios-${HB_VERSION}"
mkdir -p "$HB_WORK"
# A fresh work directory avoids stale/unprefixed object reuse. No deletion.
HB_RUN="$(mktemp -d "$HB_WORK/build-XXXXXX")"
printf '%s\n' "$HB_RUN" > "$HB_PROVENANCE/build-root.txt"
required_symbols > "$HB_PROVENANCE/required-symbols.txt"
{
  sw_vers
  xcodebuild -version
  xcrun clang --version
  xcrun --find ld
  xcrun --sdk iphoneos --show-sdk-version
  xcrun --sdk iphonesimulator --show-sdk-version
  command -v cmake
  cmake --version
  python3 --version
} > "$HB_PROVENANCE/toolchain.txt" 2>&1
shasum -a 256 "$0" "$REPO_ROOT/tool/ci/build_ios_unsigned.sh" \
  "$REPO_ROOT/lib/features/reader/engine/text/harfbuzz/hb_bindings.dart" \
  "$REPO_ROOT/ios/Flutter/"{HarfBuzz,Debug,Release}.xcconfig \
  "$REPO_ROOT/.github/workflows/ios-unsigned.yml" > "$HB_PROVENANCE/input-sha256.txt"
printf 'version=%s\nurl=%s\nbytes=20295260\nsha256=%s\ncache=none\n' \
  "$HB_VERSION" "$HB_URL" "$HB_SHA256" > "$HB_PROVENANCE/source.txt"
HB_ARCHIVE="$HB_RUN/harfbuzz.tar.xz"
curl --fail --location --proto '=https' --proto-redir '=https' --tlsv1.2 "$HB_URL" -o "$HB_ARCHIVE"
printf '%s  %s\n' "$HB_SHA256" "$HB_ARCHIVE" | shasum -a 256 -c -
[[ "$(wc -c < "$HB_ARCHIVE" | tr -d '[:space:]')" == 20295260 ]]
shasum -a 256 "$HB_ARCHIVE" > "$HB_PROVENANCE/source-archive-sha256.txt"
tar -xf "$HB_ARCHIVE" -C "$HB_RUN"
HB_SOURCE="$HB_RUN/harfbuzz-${HB_VERSION}"
test -f "$HB_SOURCE/CMakeLists.txt"
printf '%s  %s\n' "$HB_COPYING_SHA256" "$HB_SOURCE/COPYING" | shasum -a 256 -c -
cp "$HB_SOURCE/COPYING" "$HB_PROVENANCE/HarfBuzz-COPYING"
shasum -a 256 "$HB_PROVENANCE/HarfBuzz-COPYING" > "$HB_PROVENANCE/COPYING-sha256.txt"

# A forced-include macro map renames every hb_* and _hb_* source identifier,
# including private definitions, types and declarations, before compilation.
# Every architecture receives the SAME map; no unprefixed bootstrap library.
# The subsequent archive symbol audit is authoritative and fails closed for
# generated/token-pasted symbols missed by this lexical discovery.
python3 - "$HB_SOURCE" "$HB_RUN/hb-prefix.h" "$HB_PREFIX" <<'PY'
import pathlib, re, sys
root, destination, prefix = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3]
names = set()
namespaces = set()
for path in root.rglob('*'):
    if path.is_file() and path.suffix in {'.h', '.hh', '.hpp', '.c', '.cc', '.cpp', '.inc', '.in'}:
        source = path.read_text(errors='strict')
        names.update(re.findall(r'\b_?hb_[A-Za-z0-9_]+\b', source))
        namespaces.update(re.findall(r'\bnamespace\s+([A-Za-z_][A-Za-z0-9_]*)\s*\{', source))
if 'hb_shape' not in names or 'hb_font_draw_glyph' not in names:
    raise SystemExit('Unexpected source export surface')
# Isolate C++ OpenType/AAT/etc. definitions as well as the public C ABI. Never
# rename the standard library namespace. Generated names still need nm review.
names.update(namespaces - {'std'})
destination.write_text('#pragma once\n' + ''.join(
    f'#define {name} {prefix}{name}\n' for name in sorted(names)))
PY
cp "$HB_RUN/hb-prefix.h" "$HB_PROVENANCE/hb-prefix.h"

# Pin the 14.6.0 cache contract, including its tri-state STRING demo switch.
# option()-only discovery misses set(... CACHE STRING ...) controls. Use the
# same typed definitions for configure and validation; unknown HB entries and
# unused arguments still fail. Retain CMakeLists for CI review of OFF semantics.
cat > "$HB_RUN/component-cmake-flags.txt" <<'FLAGS'
-DBUILD_SHARED_LIBS:BOOL=OFF
-DHB_BUILD_GPU:BOOL=OFF
-DHB_BUILD_GPU_DEMO:STRING=OFF
-DHB_BUILD_RASTER:BOOL=OFF
-DHB_BUILD_SUBSET:BOOL=OFF
-DHB_BUILD_UTILS:BOOL=OFF
-DHB_BUILD_VECTOR:BOOL=OFF
-DHB_HAVE_CAIRO:BOOL=OFF
-DHB_HAVE_CORETEXT:BOOL=OFF
-DHB_HAVE_FREETYPE:BOOL=OFF
-DHB_HAVE_GLIB:BOOL=OFF
-DHB_HAVE_GOBJECT:BOOL=OFF
-DHB_HAVE_GRAPHITE2:BOOL=OFF
-DHB_HAVE_ICU:BOOL=OFF
-DHB_HAVE_INTROSPECTION:BOOL=OFF
FLAGS
cp "$HB_RUN/component-cmake-flags.txt" "$HB_PROVENANCE/component-cmake-flags.txt"
cp "$HB_SOURCE/CMakeLists.txt" "$HB_PROVENANCE/CMakeLists.txt"
component_flags=()
while IFS= read -r flag; do component_flags+=("$flag"); done < "$HB_RUN/component-cmake-flags.txt"

HB_MIN_IOS=15.0 # Matches the checkout's Runner deployment target on 2026-10-28.
for target in device-arm64 simulator-arm64 simulator-x86_64; do
  case "$target" in
    device-arm64) sdk=iphoneos; arch=arm64 ;;
    simulator-arm64) sdk=iphonesimulator; arch=arm64 ;;
    simulator-x86_64) sdk=iphonesimulator; arch=x86_64 ;;
  esac
  sdk_path="$(xcrun --sdk "$sdk" --show-sdk-path)"
  destination="$HB_RUN/$target"
  cmake -S "$HB_SOURCE" -B "$destination" -G Xcode \
    -DCMAKE_SYSTEM_NAME:STRING=iOS -DCMAKE_OSX_SYSROOT:PATH="$sdk_path" \
    -DCMAKE_OSX_ARCHITECTURES:STRING="$arch" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET:STRING="$HB_MIN_IOS" \
    -DCMAKE_INSTALL_PREFIX:PATH="$destination/install" \
    -DCMAKE_C_FLAGS:STRING="-include \"$HB_RUN/hb-prefix.h\"" \
    -DCMAKE_CXX_FLAGS:STRING="-include \"$HB_RUN/hb-prefix.h\"" \
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED:STRING=NO \
    -DCMAKE_XCODE_ATTRIBUTE_GCC_SYMBOLS_PRIVATE_EXTERN:STRING=NO \
    "${component_flags[@]}" \
    2>&1 | tee "$HB_PROVENANCE/$target-configure.log"
  # An unrecognized option needs review, never a silent optional dependency.
  if grep -q 'Manually-specified variables were not used' "$HB_PROVENANCE/$target-configure.log"; then
    echo 'CMake option drift: review pinned source options before continuing' >&2
    exit 3
  fi
  cp "$destination/CMakeCache.txt" "$HB_PROVENANCE/$target-CMakeCache.txt"
  python3 - "$destination/CMakeCache.txt" "$HB_RUN/component-cmake-flags.txt" <<'PY'
import pathlib, re, sys
cache = pathlib.Path(sys.argv[1]).read_text()
if not re.search(r'^BUILD_SHARED_LIBS:BOOL=OFF$', cache, re.M):
    raise SystemExit('Expected a static HarfBuzz build: BUILD_SHARED_LIBS:BOOL=OFF')
expected = {}
for flag in pathlib.Path(sys.argv[2]).read_text().splitlines():
    match = re.fullmatch(r'-D([A-Z0-9_]+):(BOOL|STRING)=(OFF)', flag)
    if not match or match[1] in expected:
        raise SystemExit('Invalid or duplicate component cache definition: ' + flag)
    expected[match[1]] = (match[2], match[3])
# This is CMake's choice-list metadata, not another component switch. Keep the
# exception exact; do not exempt arbitrary INTERNAL or *-STRINGS HB entries.
metadata = {'HB_BUILD_GPU_DEMO-STRINGS': ('INTERNAL', 'AUTO;ON;OFF')}
seen = set()
for line in cache.splitlines():
    if not (line.startswith('HB_') or line.startswith('BUILD_SHARED_LIBS:')):
        continue
    match = re.fullmatch(r'([^:]+):([^=]+)=(.*)', line)
    if not match or match[1] in seen:
        raise SystemExit('Malformed or duplicate HarfBuzz cache entry: ' + line)
    name, kind, value = match.groups()
    wanted = expected.get(name, metadata.get(name))
    if wanted != (kind, value):
        raise SystemExit('Unexpected HarfBuzz component/dependency cache entry: ' + line)
    seen.add(name)
missing = expected.keys() - seen
if missing:
    raise SystemExit('Missing HarfBuzz cache definitions: ' + ', '.join(sorted(missing)))
PY
  cmake --build "$destination" --config Release --target harfbuzz \
    2>&1 | tee "$HB_PROVENANCE/$target-build.log"
  cmake --install "$destination" --config Release \
    2>&1 | tee "$HB_PROVENANCE/$target-install.log"
  test -f "$destination/install/lib/libharfbuzz.a"
  xcrun lipo -verify_arch "$arch" "$destination/install/lib/libharfbuzz.a"
  xcrun nm -a "$destination/install/lib/libharfbuzz.a" > "$HB_PROVENANCE/$target-symbols-raw.txt"
  xcrun c++filt < "$HB_PROVENANCE/$target-symbols-raw.txt" > "$HB_PROVENANCE/$target-symbols.txt"
  xcrun nm -gUj "$destination/install/lib/libharfbuzz.a" > "$HB_PROVENANCE/$target-globals-raw.txt"
  xcrun c++filt < "$HB_PROVENANCE/$target-globals-raw.txt" > "$HB_PROVENANCE/$target-globals.txt"
  python3 - "$HB_PROVENANCE/$target-symbols.txt" "$HB_PROVENANCE/$target-globals-raw.txt" \
    "$HB_PROVENANCE/required-symbols.txt" <<'PY'
import pathlib, re, sys
symbols = pathlib.Path(sys.argv[1]).read_text()
bad = re.findall(r'(?<![A-Za-z0-9_])_*hb_[A-Za-z0-9_]+', symbols)
if bad:
    raise SystemExit('Unprefixed HB symbols (including undefined): ' + ', '.join(sorted(set(bad))))
defined = set(pathlib.Path(sys.argv[2]).read_text().splitlines())
missing = set(pathlib.Path(sys.argv[3]).read_text().splitlines()) - defined
if missing:
    raise SystemExit('Missing prefixed definitions: ' + ', '.join(sorted(missing)))
PY
  # Reject any externally defined non-prefixed name, including unexpected C++
  # globals. Compiler-generated helpers may require a reviewed source/toolchain
  # treatment; there is no permissive symbol allowlist. Check the defining C++
  # scope, not a prefixed parameter/return type in an unrelated global name.
  python3 - "$HB_PROVENANCE/$target-globals-raw.txt" <<'PY'
import pathlib, re, sys
symbols = pathlib.Path(sys.argv[1]).read_text().splitlines()
def prefixed(name):
    if name.startswith('_shiori_'):
        return True
    if not name.startswith('__Z'):
        return False
    encoded = name[3:]
    # Itanium ABI guard/vtable/typeinfo wrappers still name their owner.
    encoded = re.sub(r'^(GV|TV|TI|TS)', '', encoded)
    encoded = re.sub(r'^N[rVK]*', '', encoded)
    match = re.match(r'([1-9][0-9]*)([A-Za-z_][A-Za-z0-9_]*)', encoded)
    if not match:
        return False
    owner = match[2][:int(match[1])]
    return owner.startswith('shiori_')
bad = [s for s in symbols if s.strip() and not s.rstrip().endswith(':') and not prefixed(s)]
if bad:
    raise SystemExit('Non-prefixed global definitions require review: ' + repr(bad))
PY
done

mkdir -p "$HB_RUN/simulator" "$HB_RUN/headers"
xcrun lipo -create \
  "$HB_RUN/simulator-arm64/install/lib/libharfbuzz.a" \
  "$HB_RUN/simulator-x86_64/install/lib/libharfbuzz.a" \
  -output "$HB_RUN/simulator/libharfbuzz.a"
xcrun lipo -verify_arch arm64 x86_64 "$HB_RUN/simulator/libharfbuzz.a"
cp "$HB_RUN/device-arm64/install/include/harfbuzz/"*.h "$HB_RUN/headers/"
cp "$HB_RUN/hb-prefix.h" "$HB_RUN/headers/shiori-hb-prefix.h"
printf '#include "shiori-hb-prefix.h"\n#include "hb.h"\n' > "$HB_RUN/headers/shiori-harfbuzz.h"
xcodebuild -create-xcframework \
  -library "$HB_RUN/device-arm64/install/lib/libharfbuzz.a" -headers "$HB_RUN/headers" \
  -library "$HB_RUN/simulator/libharfbuzz.a" -headers "$HB_RUN/headers" \
  -output "$HB_RUN/ShioriHarfBuzz.xcframework" \
  2>&1 | tee "$HB_PROVENANCE/xcframework.log"
shasum -a 256 "$HB_RUN"/*/install/lib/libharfbuzz.a "$HB_RUN/simulator/libharfbuzz.a" \
  > "$HB_PROVENANCE/archive-sha256.txt"
ditto -c -k --keepParent "$HB_RUN/ShioriHarfBuzz.xcframework" "$HB_PROVENANCE/ShioriHarfBuzz.xcframework.zip"
# Build output only; never rewrite Flutter's Generated.xcconfig or the project.
python3 - "$HB_WORK/HarfBuzz.generated.xcconfig" "$HB_RUN" "$HB_PROVENANCE/required-symbols.txt" <<'PY'
import pathlib, sys
destination, build_root, required = pathlib.Path(sys.argv[1]), sys.argv[2], pathlib.Path(sys.argv[3])
if any(c in build_root for c in ('$', '#', '\n', '\r', '"')) or '//' in build_root:
    raise SystemExit('Build path cannot be represented safely in xcconfig')
destination.write_text('// Generated by build_harfbuzz_ios.sh; no cross-run cache.\n'
    f'SHIORI_HB_BUILD_DIR = {build_root}\n'
    'SHIORI_HB_REQUIRED_LDFLAGS = ' + ' '.join(
        '-Wl,-u,' + name for name in required.read_text().splitlines()) + '\n')
PY
cp "$HB_WORK/HarfBuzz.generated.xcconfig" "$HB_PROVENANCE/HarfBuzz.generated.xcconfig"
echo "HarfBuzz built and symbol-audited: $HB_RUN; provenance: $HB_PROVENANCE"
