#!/bin/bash
set -euo pipefail

# Homebrew tools such as xcsift and swiftlint can be missing from PATH in git hooks and GUI-launched shells.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

# shellcheck source=lib/testing.sh
source "$repo_root/scripts/lib/testing.sh"
# shellcheck source=lib/screenshots.sh
source "$repo_root/scripts/lib/screenshots.sh"

if ! command -v brew >/dev/null 2>&1; then
  echo "error: Homebrew is required. Install it from https://brew.sh/ and rerun this script." >&2
  exit 1
fi

install_brew_formula() {
  formula=$1
  if brew list --formula "$formula" >/dev/null 2>&1; then
    echo "$formula already installed"
  else
    brew install "$formula"
  fi
}

install_brew_formula xcsift
install_brew_formula swiftlint
# Taps, drags and reads the simulator's accessibility tree without the host's cursor.
install_brew_formula cameroncooke/axe/axe

"$repo_root/scripts/install-git-hooks.sh"

# xcodebuild runs a destination named without an OS on the newest iOS, so the scripts' simulators
# belong on the newest runtime, where the snapshot baselines are recorded.
ios_runtime=$(xcrun simctl list runtimes available --json |
  jq -r '[.runtimes[] | select(.platform == "iOS")] | sort_by(.version | split(".") | map(tonumber)) | last | .identifier // empty')
if [ -z "$ios_runtime" ]; then
  echo "error: no iOS simulator runtime is installed. Install one with 'xcodebuild -downloadPlatform iOS' and rerun this script." >&2
  exit 1
fi

# Creates a simulator by this name on the newest iOS runtime unless one is there, since the run,
# test, snapshot and screenshot scripts find their devices by name and fail without them.
create_simulator() {
  local name=$1
  if xcrun simctl list devices available --json |
    jq -e --arg runtime "$ios_runtime" --arg name "$name" '(.devices[$runtime] // []) | any(.name == $name)' >/dev/null; then
    echo "$name simulator already exists"
    return
  fi
  local device_type
  device_type=$(xcrun simctl list devicetypes --json |
    jq -r --arg name "$name" 'first(.devicetypes[] | select(.name == $name) | .identifier) // empty')
  if [ -z "$device_type" ]; then
    echo "error: this Xcode has no '$name' simulator. Update Xcode and rerun this script." >&2
    exit 1
  fi
  xcrun simctl create "$name" "$device_type" "$ios_runtime" >/dev/null
  echo "Created $name simulator"
}

create_simulator "$snapshot_phone_device"
create_simulator "$snapshot_wide_device"
for device in "${screenshot_devices[@]}"; do
  create_simulator "$device"
done

echo "Setup complete. Next steps:"
echo "  1. Build with ./scripts/build.sh"
echo "  2. Build and run on a connected device or the simulator with ./scripts/run.sh -b"
echo "  3. Test with ./scripts/test.sh"
echo "  4. Verify snapshots with ./scripts/snapshots.sh verify"
echo "  5. Lint with ./scripts/lint.sh"
