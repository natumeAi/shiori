#!/usr/bin/env bash
# Host-neutral build logic. Requires macOS, explicitly selected Xcode and Flutter.
set -euo pipefail

# Validate before touching output, checking the host or invoking build tools.
readonly BUILD_MODE="${BUILD_MODE-probe}"
case "$BUILD_MODE" in
  probe) ENTRY_POINT=lib/main_probe.dart; PACKAGE_VARIANTS=(default cametal) ;;
  app) ENTRY_POINT=lib/main.dart; PACKAGE_VARIANTS=(default) ;;
  *) echo 'Invalid BUILD_MODE: expected probe or app.' >&2; exit 1 ;;
esac
readonly ENTRY_POINT
readonly -a PACKAGE_VARIANTS
readonly OUTPUT_SUBDIR="build/ios-$BUILD_MODE"
ipa_filename() {
  local build_id="$1" variant="$2" suffix=''
  [[ "$variant" != cametal ]] || suffix=-cametal
  printf 'shiori-%s-%s%s.ipa' "$BUILD_MODE" "$build_id" "$suffix"
}
# Read-only selection check; no macOS, Flutter, Git or build identity required.
if [[ "${1:-}" == --print-build-plan && $# == 1 ]]; then
  printf 'mode=%s\nentryPoint=%s\noutputDirectory=%s\n' "$BUILD_MODE" "$ENTRY_POINT" "$OUTPUT_SUBDIR"
  for variant in "${PACKAGE_VARIANTS[@]}"; do
    printf 'ipa=%s\n' "$(ipa_filename '<BUILD_ID>' "$variant")"
  done
  exit 0
fi
[[ $# == 0 ]] || { echo 'Usage: build_ios_unsigned.sh [--print-build-plan]' >&2; exit 1; }

cd "$(git rev-parse --show-toplevel)"
readonly EXPECTED_FRAMEWORK=abaf9c523780a608bd46686fd5e53740a07077f8
readonly EXPECTED_ENGINE=deb287481e3ce9468f3434937ced4240a70539ca
readonly OUTPUT_DIR="$PWD/$OUTPUT_SUBDIR"
mkdir -p "$OUTPUT_DIR"

# Also retain native migrations when Flutter/Xcode fails part-way through.
finish() {
  local result=$?
  trap - EXIT
  git status --porcelain --untracked-files=all -- ios/ > "$OUTPUT_DIR/ios-status.txt"
  git diff --binary -- ios/ > "$OUTPUT_DIR/ios-project.diff"
  # A tracked diff omits new migration files. Preserve their contents, including
  # hidden paths, in a ZIP so upload-artifact does not filter them out.
  local native_file
  local has_untracked=false
  while IFS= read -r -d '' native_file; do
    mkdir -p "$(dirname "$OUTPUT_DIR/ios-untracked/$native_file")"
    ditto "$native_file" "$OUTPUT_DIR/ios-untracked/$native_file"
    has_untracked=true
  done < <(git ls-files --others --exclude-standard -z -- ios/)
  if [[ "$has_untracked" == true ]]; then
    ditto -c -k "$OUTPUT_DIR/ios-untracked" "$OUTPUT_DIR/ios-untracked.zip"
  fi
  printf '%s\n' "$result" > "$OUTPUT_DIR/build-exit-code.txt"
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    {
      printf '### Unsigned %s build\n\n' "$BUILD_MODE"
      printf 'Entry point: `%s`\n\n' "$ENTRY_POINT"
      printf 'Build: `%s`; exit: `%s`\n\n' "${BUILD_ID:-unavailable}" "$result"
      printf '```text\n'
      cat "$OUTPUT_DIR/toolchain.txt" 2>/dev/null || true
      printf '\n```\n\n'
      printf 'Review `ios-status.txt`, `ios-project.diff` and, when present, `ios-untracked.zip`. '
      printf 'Cloud compilation does not establish signing, installation or physical presentation.\n'
    } >> "$GITHUB_STEP_SUMMARY"
  fi
  exit "$result"
}
trap finish EXIT

[[ "$(uname -s)" == Darwin ]] || { echo 'This build requires macOS.' >&2; exit 1; }
: "${BUILD_NUMBER:?Set BUILD_NUMBER to the monotonically increasing host run number}"
: "${BUILD_HOST:?Set BUILD_HOST (gha for GitHub Actions)}"
[[ "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || { echo 'Invalid build number.' >&2; exit 1; }
[[ "$BUILD_HOST" =~ ^[a-z0-9]+$ ]] || { echo 'Invalid host name.' >&2; exit 1; }
SOURCE_COMMIT="${SOURCE_COMMIT:-$(git rev-parse HEAD)}"
[[ "$SOURCE_COMMIT" =~ ^[0-9a-f]{40}$ ]] || { echo 'Invalid source commit.' >&2; exit 1; }
[[ "$SOURCE_COMMIT" == "$(git rev-parse HEAD)" ]] || { echo 'Source commit mismatch.' >&2; exit 1; }
BUILD_ID="${SOURCE_COMMIT:0:12}-$BUILD_HOST-$BUILD_NUMBER"
export BUILD_ID

flutter --version --machine > "$OUTPUT_DIR/flutter-version.json"
FRAMEWORK_VERSION="$(jq -r '.frameworkVersion' "$OUTPUT_DIR/flutter-version.json")"
FRAMEWORK="$(jq -r '.frameworkRevision' "$OUTPUT_DIR/flutter-version.json")"
ENGINE="$(jq -r '.engineRevision' "$OUTPUT_DIR/flutter-version.json")"
CHANNEL="$(jq -r '.channel' "$OUTPUT_DIR/flutter-version.json")"
[[ "$FRAMEWORK_VERSION" == 3.47.7 && "$CHANNEL" == stable && "$FRAMEWORK" == "$EXPECTED_FRAMEWORK" ]] || {
  echo 'Flutter version/channel/framework pin mismatch.' >&2; exit 1;
}
[[ "$ENGINE" == "$EXPECTED_ENGINE" ]] || { echo 'Flutter engine pin mismatch.' >&2; exit 1; }
{
  sw_vers
  printf 'Runner label: %s\nImage: %s (%s)\n' "${RUNNER_LABEL:-unavailable}" "${ImageOS:-unavailable}" "${ImageVersion:-unavailable}"
  printf 'Developer directory: %s\n' "$(xcode-select -p)"
  xcodebuild -version
  xcrun --sdk iphoneos --show-sdk-version
  flutter --version
  printf 'Framework: %s\nEngine: %s\nCommit: %s\nBuild ID: %s\nBuild number: %s\n' "$FRAMEWORK" "$ENGINE" "$SOURCE_COMMIT" "$BUILD_ID" "$BUILD_NUMBER"
} > "$OUTPUT_DIR/toolchain.txt"
cat "$OUTPUT_DIR/toolchain.txt"
jq -n --arg buildId "$BUILD_ID" --arg buildNumber "$BUILD_NUMBER" \
  --arg mode "$BUILD_MODE" --arg entryPoint "$ENTRY_POINT" \
  --arg commit "$SOURCE_COMMIT" --arg runner "${RUNNER_LABEL:-unavailable}" \
  --arg image "${ImageVersion:-unavailable}" --arg macos "$(sw_vers -productVersion)" \
  --arg xcode "$(xcodebuild -version)" --arg sdk "$(xcrun --sdk iphoneos --show-sdk-version)" \
  --arg flutter "$FRAMEWORK_VERSION" --arg framework "$FRAMEWORK" --arg engine "$ENGINE" \
  '{buildId:$buildId,buildNumber:$buildNumber,mode:$mode,entryPoint:$entryPoint,commit:$commit,runner:$runner,image:$image,macos:$macos,xcode:$xcode,iosSdk:$sdk,flutter:$flutter,framework:$framework,engine:$engine,unsigned:true}' \
  > "$OUTPUT_DIR/provenance.json"

flutter pub get --enforce-lockfile
git diff --exit-code -- pubspec.lock
dart run tool/ci/check_reader_fixtures.dart
flutter build ios --release --no-codesign --no-pub \
  --target "$ENTRY_POINT" \
  --build-number "$BUILD_NUMBER" \
  --dart-define="BUILD_ID=$BUILD_ID" \
  --dart-define="BUILD_NUMBER=$BUILD_NUMBER"
# FLUTTER_VERSION and the revision defines are reserved: the Flutter tool
# injects them itself and the app reads them through FlutterVersion.

readonly APP="$PWD/build/ios/iphoneos/Runner.app"
plist_value() { plutil -extract "$1" raw -o - "$2/Info.plist"; }
validate_bundle() {
  local app="$1" executable framework sqlite_binary
  [[ "$(plist_value DTPlatformName "$app")" == iphoneos ]]
  [[ "$(plist_value CFBundleIdentifier "$app")" == io.github.natumeai.shiori ]]
  [[ "$(plist_value CFBundleVersion "$app")" == "$BUILD_NUMBER" ]]
  executable="$(plist_value CFBundleExecutable "$app")"
  [[ -n "$executable" && "$executable" != */* ]]
  test -s "$app/$executable"
  lipo "$app/$executable" -verify_arch arm64
  printf 'Validated arm64 device executable: %s\n' "$executable"
  for framework in Flutter App; do
    test -d "$app/Frameworks/$framework.framework"
    test -s "$app/Frameworks/$framework.framework/$framework"
    lipo "$app/Frameworks/$framework.framework/$framework" -verify_arch arm64
    printf 'Validated arm64 framework: %s.framework\n' "$framework"
  done
  for framework in "$app"/Frameworks/*; do
    [[ -d "$framework" ]] || continue
    case "$(basename "$framework" | tr '[:upper:]' '[:lower:]')" in
      *sqlite*.framework)
        sqlite_binary="$(plist_value CFBundleExecutable "$framework")"
        [[ -n "$sqlite_binary" && "$sqlite_binary" != */* ]]
        test -s "$framework/$sqlite_binary"
        lipo "$framework/$sqlite_binary" -verify_arch arm64
        printf 'Validated arm64 SQLite framework: %s\n' "$(basename "$framework")"
        ;;
    esac
  done
  printf 'Validated bundle: iphoneos, io.github.natumeai.shiori, version %s\n' "$BUILD_NUMBER"
}
metal_value() {
  local value
  if value="$(plist_value FLTUseFlutterMetalLayer "$1" 2>/dev/null)"; then
    [[ "$value" == true || "$value" == false ]] || {
      echo 'Invalid FLTUseFlutterMetalLayer boolean.' >&2; return 1;
    }
    printf '%s' "$value"
  else
    printf null
  fi
}
LC_ALL=C ls -1A "$APP/Frameworks" > "$OUTPUT_DIR/frameworks.txt"
jq --rawfile frameworks "$OUTPUT_DIR/frameworks.txt" \
  '.packagedFrameworks = ($frameworks | split("\n") | map(select(length > 0))) | .packagedFrameworksFile = "frameworks.txt"' \
  "$OUTPUT_DIR/provenance.json" > "$OUTPUT_DIR/provenance-frameworks.json"
mv "$OUTPUT_DIR/provenance-frameworks.json" "$OUTPUT_DIR/provenance.json"
validate_bundle "$APP"
plutil -p "$APP/Info.plist" > "$OUTPUT_DIR/bundle-info.txt"
DEFAULT_METAL="$(metal_value "$APP")"
if [[ "$BUILD_MODE" == app && "$DEFAULT_METAL" != null ]]; then
  echo 'App mode requires the default Flutter Metal layer with no plist override.' >&2
  exit 1
fi
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/shiori-package.XXXXXX")"
: > "$OUTPUT_DIR/sha256.txt"
for variant in "${PACKAGE_VARIANTS[@]}"; do
  stage="$STAGING/$variant"
  mkdir -p "$stage/Payload"
  bundle="$stage/Payload/Runner.app"
  ditto "$APP" "$bundle"
  filename="$(ipa_filename "$BUILD_ID" "$variant")"
  if [[ "$variant" == cametal ]]; then
    if [[ "$DEFAULT_METAL" == null ]]; then
      plutil -insert FLTUseFlutterMetalLayer -bool false "$bundle/Info.plist"
    else
      plutil -replace FLTUseFlutterMetalLayer -bool false "$bundle/Info.plist"
    fi
    [[ "$(metal_value "$bundle")" == false ]]
  else
    cmp "$APP/Info.plist" "$bundle/Info.plist"
  fi
  validate_bundle "$bundle"
  metal="$(metal_value "$bundle")"
  [[ "$variant" != default || "$metal" == "$DEFAULT_METAL" ]]
  plutil -p "$bundle/Info.plist" > "$OUTPUT_DIR/bundle-info-$variant.txt"
  (
    cd "$stage"
    zip -qry "$stage/probe.ipa" Payload
  )
  mv "$stage/probe.ipa" "$OUTPUT_DIR/$filename"
  test -s "$OUTPUT_DIR/$filename"
  unzip -t "$OUTPUT_DIR/$filename"
  unzip -Z1 "$OUTPUT_DIR/$filename" | grep -Fx 'Payload/Runner.app/Info.plist'
  checksum="$(shasum -a 256 "$OUTPUT_DIR/$filename")"
  checksum="${checksum%% *}"
  printf '%s  %s\n' "$checksum" "$filename" >> "$OUTPUT_DIR/sha256.txt"
  jq --arg file "$filename" --arg sha256 "$checksum" --arg variant "$variant" \
    --argjson metal "$metal" \
    '.variants = (.variants // []) + [{file:$file,sha256:$sha256,variant:$variant,FLTUseFlutterMetalLayer:$metal,FLTUseFlutterMetalLayerEffective:(if $metal == null then true else $metal end)}]' \
    "$OUTPUT_DIR/provenance.json" > "$STAGING/provenance.json"
  mv "$STAGING/provenance.json" "$OUTPUT_DIR/provenance.json"
  printf 'Unsigned device package: %s\n' "$OUTPUT_DIR/$filename"
done
