#!/bin/bash
set -euo pipefail

# Homebrew tools such as xcsift and swiftlint can be missing from PATH in git hooks and GUI-launched shells.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

run_and_format() {
  if command -v xcsift >/dev/null 2>&1; then
    raw_log=$(mktemp -t carouline-xcodebuild.XXXXXX)
    filtered_log=$(mktemp -t carouline-xcsift.XXXXXX)
    trap 'rm -f "$raw_log" "$filtered_log"' EXIT
    set +e
    "$@" 2>&1 | tee "$raw_log" | xcsift -f toon -w | tee "$filtered_log"
    statuses=("${PIPESTATUS[@]}")
    set -e

    status=0
    for pipeline_status in "${statuses[@]}"; do
      if [ "$pipeline_status" -ne 0 ]; then
        status=$pipeline_status
      fi
    done

    if [ "$status" -ne 0 ]; then
      xcodebuild_status=${statuses[0]:-0}
      if [ "$xcodebuild_status" -ne 0 ] && [ ! -s "$filtered_log" ]; then
        echo "" >&2
        echo "xcodebuild exited $xcodebuild_status and xcsift produced no output - raw log:" >&2
        cat "$raw_log" >&2
      fi
      exit "$status"
    fi
  else
    "$@"
  fi
}

# `--device <udid>` builds for that iPhone or iPad, and lets automatic signing register it and
# renew its profile.
destination='generic/platform=iOS Simulator'
signing_args=()
if [ "${1:-}" = "--device" ]; then
  destination="id=${2:?--device needs a device UDID}"
  signing_args=(-allowProvisioningUpdates)
  shift 2
fi

# macOS ships bash 3.2, where `set -u` treats an empty array as unbound, so expand it only when set.
run_and_format xcodebuild \
  -project Carouline.xcodeproj \
  -scheme Carouline \
  -destination "$destination" \
  -derivedDataPath .build/xcode \
  ${signing_args[@]+"${signing_args[@]}"} \
  build \
  "$@"
