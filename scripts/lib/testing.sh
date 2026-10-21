# shellcheck shell=bash
# Shared by setup.sh, test.sh and snapshots.sh, which source it after `cd`-ing to the repo root.

# Snapshot baselines only hold on the device they were recorded on, and fail anywhere else, so
# each suite runs only on its own device. Matches `SnapshotDevice`.
snapshot_phone_device="iPhone 18 Pro"
snapshot_wide_device="iPad mini (A17 Pro)"
snapshot_suites=(CaroulineTests/SnapshotTests CaroulineTests/WideSnapshotTests)

# Prints the device a snapshot test identifier runs on, or nothing for any other identifier.
snapshot_device() {
  case "$1" in
    CaroulineTests/SnapshotTests|CaroulineTests/SnapshotTests/*)
      echo "$snapshot_phone_device"
      ;;
    CaroulineTests/WideSnapshotTests|CaroulineTests/WideSnapshotTests/*)
      echo "$snapshot_wide_device"
      ;;
  esac
}

# Failed snapshot comparisons write the new image here, and a run's images replace the last
# run's, so they always describe its failures. A custom SNAPSHOT_ARTIFACTS is left alone.
# The simulator doesn't inherit this shell's environment; xcodebuild forwards `TEST_RUNNER_`
# variables with the prefix stripped. The path is absolute, since the test host resolves a
# relative one against its own directory.
prepare_snapshot_artifacts() {
  local default_artifacts="$PWD/.build/snapshot-failures"
  local artifacts=${SNAPSHOT_ARTIFACTS:-$default_artifacts}
  if [ "$artifacts" = "$default_artifacts" ]; then
    rm -rf "$artifacts"
  fi
  mkdir -p "$artifacts"
  TEST_RUNNER_SNAPSHOT_ARTIFACTS=$(cd "$artifacts" && pwd)
  export TEST_RUNNER_SNAPSHOT_ARTIFACTS
}

# A simulator whose SpringBoard crashes as it boots, as one does on every boot once its wallpaper
# state goes bad, leaves the test host without a window scene, and every snapshot then fails
# with "Snapshots need the host app's window scene". Names the crash reports for the simulator
# named `$1` since `$2`, in seconds since the epoch, and the erase that clears it.
warn_about_springboard_crashes() {
  local device=$1
  local since=$2
  local udid
  # A lookup that fails says nothing about the run, so it never fails one.
  udid=$(xcrun simctl list devices available -j |
    jq -r --arg name "$device" '[.devices[][] | select(.name == $name)] | (map(select(.state == "Booted")) + .)[0].udid // empty') || return 0
  if [ -z "$udid" ]; then
    return 0
  fi
  local reports
  # A date string, since macOS's `find` reads no `@` epoch.
  reports=$(find "$HOME/Library/Logs/DiagnosticReports" -name 'SpringBoard-*.ips' \
    -newermt "$(date -r "$since" '+%Y-%m-%d %H:%M:%S')" -exec grep -l "SimDevice.$udid" {} + 2>/dev/null || true)
  if [ -n "$reports" ]; then
    echo "warning: SpringBoard crashed on $device during this run, so its results can't be trusted:" >&2
    echo "$reports" >&2
    echo "Run again. If it keeps crashing, erase the simulator: xcrun simctl erase $udid" >&2
  fi
}

# xcodebuild exits 0 when an identifier matches nothing or a test is skipped, which would
# read as a pass. Matches Swift Testing's own console lines in the raw log, which xcodebuild
# prints with parallel testing off.
require_every_test_ran() {
  local raw_log=$1
  if grep -Eq "^➜ Test .+ skipped" "$raw_log"; then
    echo "error: some tests were skipped:" >&2
    grep -E "^➜ Test .+ skipped" "$raw_log" >&2
    exit 1
  fi
  if ! grep -Eq "^✔ Test run with [1-9][0-9]* tests? " "$raw_log"; then
    echo "error: no tests ran. Check the test identifiers." >&2
    exit 1
  fi
}
