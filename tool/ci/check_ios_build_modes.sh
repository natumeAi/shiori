#!/usr/bin/env bash
# Host-neutral regression check; never invokes Flutter or creates build output.
set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/build_ios_unsigned.sh"
readonly SCRIPT
readonly PROBE_PLAN='mode=probe
entryPoint=lib/main_probe.dart
outputDirectory=build/ios-probe
ipa=shiori-probe-<BUILD_ID>.ipa
ipa=shiori-probe-<BUILD_ID>-cametal.ipa'
readonly APP_PLAN='mode=app
entryPoint=lib/main.dart
outputDirectory=build/ios-app
ipa=shiori-app-<BUILD_ID>.ipa'

assert_plan() {
  local label="$1" actual="$2" expected="$3"
  if [[ "$actual" != "$expected" ]]; then
    printf 'FAIL: %s\nExpected:\n%s\nActual:\n%s\n' "$label" "$expected" "$actual" >&2
    exit 1
  fi
  printf 'PASS: %s\n' "$label"
}
assert_plan 'unset mode defaults to probe (two IPAs)' \
  "$(env -u BUILD_MODE bash "$SCRIPT" --print-build-plan)" "$PROBE_PLAN"
assert_plan 'explicit probe target and package names' \
  "$(BUILD_MODE=probe bash "$SCRIPT" --print-build-plan)" "$PROBE_PLAN"
assert_plan 'app target and single package name' \
  "$(BUILD_MODE=app bash "$SCRIPT" --print-build-plan)" "$APP_PLAN"

for invalid in '' invalid APP 'probe app' 'app/../../lib/main.dart'; do
  # Exercise the normal invocation too: invalid input must fail before host,
  # Git, output directories, traps or any build command can run.
  for invocation in build plan; do
    args=()
    [[ "$invocation" != plan ]] || args=(--print-build-plan)
    if output="$(BUILD_MODE="$invalid" bash "$SCRIPT" "${args[@]}" 2>&1)"; then
      printf 'FAIL: invalid mode accepted: <%s> (%s)\n' "$invalid" "$invocation" >&2
      exit 1
    fi
    [[ "$output" == 'Invalid BUILD_MODE: expected probe or app.' ]] || {
      printf 'FAIL: invalid mode reached a later step: %s\n' "$output" >&2
      exit 1
    }
  done
done
printf 'PASS: five invalid modes rejected before build (normal and plan)\n'

if output="$(BUILD_MODE=probe bash "$SCRIPT" --target lib/main.dart 2>&1)"; then
  echo 'FAIL: free-form target accepted.' >&2
  exit 1
fi
[[ "$output" == 'Usage: build_ios_unsigned.sh [--print-build-plan]' ]]
printf 'PASS: free-form target rejected\n'
