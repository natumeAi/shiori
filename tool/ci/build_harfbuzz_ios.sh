#!/usr/bin/env bash
# DRAFT ONLY: unwired; do not execute until the owner approves the download,
# pins the official 14.6.0 tarball SHA-256, and reviews the macOS toolchain.
set -euo pipefail

HB_VERSION=14.6.0
HB_SHA256='TODO_AT_OWNER_APPROVAL_PIN_OFFICIAL_SOURCE_SHA256'
HB_PREFIX=shiori_
HB_URL="https://github.com/harfbuzz/harfbuzz/releases/download/${HB_VERSION}/harfbuzz-${HB_VERSION}.tar.xz"

if [[ ! "$HB_SHA256" =~ ^[0-9a-f]{64}$ ]]; then
  echo 'STOP: owner approval and a reviewed source SHA-256 pin are required.' >&2
  exit 2
fi
[[ "$(uname -s)" == Darwin ]] || { echo 'macOS/Xcode required' >&2; exit 2; }
for command in curl shasum tar python3 cmake xcrun xcodebuild; do
  command -v "$command" >/dev/null || { echo "Missing $command" >&2; exit 2; }
done

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HB_WORK="$REPO_ROOT/build/third_party/harfbuzz-ios-${HB_VERSION}"
mkdir -p "$HB_WORK"
# A fresh work directory avoids stale/unprefixed object reuse. No deletion.
HB_RUN="$(mktemp -d "$HB_WORK/build-XXXXXX")"
HB_ARCHIVE="$HB_RUN/harfbuzz.tar.xz"
curl --fail --location --proto '=https' --tlsv1.2 "$HB_URL" -o "$HB_ARCHIVE"
printf '%s  %s\n' "$HB_SHA256" "$HB_ARCHIVE" | shasum -a 256 -c -
tar -xf "$HB_ARCHIVE" -C "$HB_RUN"
HB_SOURCE="$HB_RUN/harfbuzz-${HB_VERSION}"
test -f "$HB_SOURCE/CMakeLists.txt"

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
    -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT="$sdk_path" \
    -DCMAKE_OSX_ARCHITECTURES="$arch" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$HB_MIN_IOS" \
    -DCMAKE_INSTALL_PREFIX="$destination/install" \
    -DCMAKE_C_FLAGS="-include $HB_RUN/hb-prefix.h" \
    -DCMAKE_CXX_FLAGS="-include $HB_RUN/hb-prefix.h" \
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO \
    -DCMAKE_XCODE_ATTRIBUTE_GCC_SYMBOLS_PRIVATE_EXTERN=NO \
    -DBUILD_SHARED_LIBS=OFF -DHB_BUILD_SUBSET=OFF \
    -DHB_HAVE_GLIB=OFF -DHB_HAVE_GOBJECT=OFF -DHB_HAVE_ICU=OFF \
    -DHB_HAVE_FREETYPE=OFF -DHB_HAVE_CORETEXT=OFF -DHB_HAVE_GRAPHITE2=OFF \
    2>&1 | tee "$destination-configure.log"
  # An unrecognized option needs review, never a silent optional dependency.
  if grep -q 'Manually-specified variables were not used' "$destination-configure.log"; then
    echo 'CMake option drift: review pinned source options before continuing' >&2
    exit 3
  fi
  cmake --build "$destination" --config Release --target harfbuzz
  cmake --install "$destination" --config Release
  test -f "$destination/install/lib/libharfbuzz.a"
  xcrun nm -a "$destination/install/lib/libharfbuzz.a" | xcrun c++filt > "$destination/symbols.txt"
  xcrun nm -gUj "$destination/install/lib/libharfbuzz.a" | xcrun c++filt > "$destination/globals.txt"
  python3 - "$destination/symbols.txt" <<'PY'
import pathlib, re, sys
symbols = pathlib.Path(sys.argv[1]).read_text()
bad = re.findall(r'(?<![A-Za-z0-9_])_*hb_[A-Za-z0-9_]+', symbols)
if bad:
    raise SystemExit('Unprefixed HB symbols (including undefined): ' + ', '.join(sorted(set(bad))))
for name in ('hb_shape', 'hb_font_draw_glyph', 'hb_version_string'):
    if not re.search(r'\b_shiori_' + name + r'\b', symbols):
        raise SystemExit('Missing prefixed export: ' + name)
PY
  # Reject any externally defined non-prefixed name, including unexpected C++
  # globals. Compiler-generated helpers may require a reviewed source/toolchain
  # treatment; this draft deliberately has no permissive symbol allowlist.
  python3 - "$destination/globals.txt" <<'PY'
import pathlib, sys
symbols = pathlib.Path(sys.argv[1]).read_text().splitlines()
bad = [s for s in symbols if s.strip() and not s.rstrip().endswith(':') and 'shiori_' not in s]
if bad:
    raise SystemExit('Non-prefixed global definitions require review: ' + repr(bad))
PY
done

mkdir -p "$HB_RUN/simulator" "$HB_RUN/headers"
xcrun lipo -create \
  "$HB_RUN/simulator-arm64/install/lib/libharfbuzz.a" \
  "$HB_RUN/simulator-x86_64/install/lib/libharfbuzz.a" \
  -output "$HB_RUN/simulator/libharfbuzz.a"
cp "$HB_RUN/device-arm64/install/include/harfbuzz/"*.h "$HB_RUN/headers/"
cp "$HB_RUN/hb-prefix.h" "$HB_RUN/headers/shiori-hb-prefix.h"
printf '#include "shiori-hb-prefix.h"\n#include "hb.h"\n' > "$HB_RUN/headers/shiori-harfbuzz.h"
xcodebuild -create-xcframework \
  -library "$HB_RUN/device-arm64/install/lib/libharfbuzz.a" -headers "$HB_RUN/headers" \
  -library "$HB_RUN/simulator/libharfbuzz.a" -headers "$HB_RUN/headers" \
  -output "$HB_RUN/ShioriHarfBuzz.xcframework"
cp "$HB_SOURCE/COPYING" "$HB_RUN/HarfBuzz-COPYING"
xcodebuild -version > "$HB_RUN/toolchain.txt"
xcrun --sdk iphoneos --show-sdk-version >> "$HB_RUN/toolchain.txt"
shasum -a 256 "$HB_RUN"/*/install/lib/libharfbuzz.a > "$HB_RUN/archive-sha256.txt"
echo "Draft artifacts built and symbol-audited: $HB_RUN"
# This script never edits ios/, Podfile, CI workflows, or uploads artifacts.
