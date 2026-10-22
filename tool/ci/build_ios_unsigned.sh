#!/usr/bin/env bash
# Host-neutral build logic. Requires macOS, explicitly selected Xcode and Flutter.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
readonly EXPECTED_FRAMEWORK=abaf9c523780a608bd46686fd5e53740a07077f8
readonly EXPECTED_ENGINE=deb287481e3ce9468f3434937ced4240a70539ca
readonly OUTPUT_DIR="$PWD/build/ios-probe"
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
      printf '### Unsigned probe build\n\n'
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
  --arg commit "$SOURCE_COMMIT" --arg runner "${RUNNER_LABEL:-unavailable}" \
  --arg image "${ImageVersion:-unavailable}" --arg macos "$(sw_vers -productVersion)" \
  --arg xcode "$(xcodebuild -version)" --arg sdk "$(xcrun --sdk iphoneos --show-sdk-version)" \
  --arg flutter "$FRAMEWORK_VERSION" --arg framework "$FRAMEWORK" --arg engine "$ENGINE" \
  '{buildId:$buildId,buildNumber:$buildNumber,commit:$commit,runner:$runner,image:$image,macos:$macos,xcode:$xcode,iosSdk:$sdk,flutter:$flutter,framework:$framework,engine:$engine,unsigned:true}' \
  > "$OUTPUT_DIR/provenance.json"

flutter pub get --enforce-lockfile
git diff --exit-code -- pubspec.lock
flutter build ios --release --no-codesign --no-pub \
  --target lib/main_probe.dart \
  --build-number "$BUILD_NUMBER" \
  --dart-define="BUILD_ID=$BUILD_ID" \
  --dart-define="BUILD_NUMBER=$BUILD_NUMBER"
# FLUTTER_VERSION and the revision defines are reserved: the Flutter tool
# injects them itself and the app reads them through FlutterVersion.

readonly APP="$PWD/build/ios/iphoneos/Runner.app"
readonly PLIST="$APP/Info.plist"
plist_value() { plutil -extract "$1" raw -o - "$PLIST"; }
[[ "$(plist_value DTPlatformName)" == iphoneos ]]
[[ "$(plist_value CFBundleIdentifier)" == io.github.natumeai.shiori ]]
[[ "$(plist_value CFBundleVersion)" == "$BUILD_NUMBER" ]]
EXECUTABLE="$(plist_value CFBundleExecutable)"
[[ -n "$EXECUTABLE" && "$EXECUTABLE" != */* ]]
test -s "$APP/$EXECUTABLE"
lipo -verify_arch arm64 "$APP/$EXECUTABLE"
printf 'Validated arm64 device executable: %s\n' "$EXECUTABLE"
for framework in Flutter App; do
  test -d "$APP/Frameworks/$framework.framework"
  test -s "$APP/Frameworks/$framework.framework/$framework"
  lipo -verify_arch arm64 "$APP/Frameworks/$framework.framework/$framework"
  printf 'Validated arm64 framework: %s.framework\n' "$framework"
done
printf 'Validated bundle: iphoneos, io.github.natumeai.shiori, version %s\n' "$BUILD_NUMBER"
plutil -p "$PLIST" > "$OUTPUT_DIR/bundle-info.txt"

STAGING="$(mktemp -d "${TMPDIR:-/tmp}/shiori-package.XXXXXX")"
mkdir "$STAGING/Payload"
ditto "$APP" "$STAGING/Payload/Runner.app"
readonly IPA="$OUTPUT_DIR/shiori-probe-$BUILD_ID.ipa"
(
  cd "$STAGING"
  zip -qry "$STAGING/probe.ipa" Payload
)
mv "$STAGING/probe.ipa" "$IPA"
test -s "$IPA"
unzip -t "$IPA"
unzip -Z1 "$IPA" | grep -Fx 'Payload/Runner.app/Info.plist'
shasum -a 256 "$IPA" > "$OUTPUT_DIR/sha256.txt"
printf 'Unsigned device package: %s\n' "$IPA"
