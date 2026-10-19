#!/bin/bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: ./scripts/screenshots.sh [-b|--build] [--dark] [-d|--device <name>]... [-o|--output <dir>]

Launches the app's demo projects (`-DebugDemoProjects YES`) in each App Store screenshot state
and saves a PNG of each, without the alpha channel App Store Connect rejects, to
<dir>/<device>/, `.build/screenshots` by default, emptying that folder first. Captures on
iPhone 18 Pro, iPad Pro 13-inch (M5) (16GB) and iPhone Duo unless `-d` names others. `-b`
builds first, and `--dark` captures in dark mode. Status bars read 9:41 with full signal and
battery. Afterward each simulator gets its appearance and a Duo its fold back, and status bar
overrides are cleared.

iPhone Duo is unfolded to its inner display in landscape, the way people hold it open, with
duoctl, which setup.sh installs. Other shots keep the simulator's orientation and an iPad's
multitasking mode, which simctl can't set: rotate it in Device Hub, and choose Full Screen Apps
in an iPad's Settings > Multitasking & Gestures to hide the window's resize handle.
USAGE
}

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

# shellcheck source=lib/screenshots.sh
source "$repo_root/scripts/lib/screenshots.sh"

build_first=0
appearance=light
devices=()
output_dir="$repo_root/.build/screenshots"
while [ $# -gt 0 ]; do
  case "$1" in
    -b|--build)
      build_first=1
      shift
      ;;
    --dark)
      appearance=dark
      shift
      ;;
    -d|--device|-o|--output)
      if [ $# -lt 2 ]; then
        echo "error: $1 needs a value" >&2
        usage >&2
        exit 1
      fi
      case "$1" in
        -d|--device) devices+=("$2") ;;
        *) output_dir=$2 ;;
      esac
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done
if [ ${#devices[@]} -eq 0 ]; then
  devices=("${screenshot_devices[@]}")
fi

bundle_id="com.afollestad.Carouline"
app_path="$repo_root/.build/xcode/Build/Products/Debug-iphonesimulator/Carouline.app"
duo_device_type="com.apple.CoreSimulator.SimDeviceType.iPhone-Duo"

# Apple's marketing time, 9:41 on the day it announced iPhone, in this Mac's time zone, which
# simulators show. A plain time leaves an iPad's date on today's, and simctl only takes an ISO
# date with fractional seconds and a colon in its offset. Simulators ignore the year, so an iPad
# reads Sun Jan 9 rather than Apple's Tue.
status_bar_time=$(date -j -f "%Y-%m-%d %H:%M:%S" "2007-01-09 09:41:00" "+%Y-%m-%dT%H:%M:%S.000%z")
status_bar_time="${status_bar_time%??}:${status_bar_time: -2}"

# Each state's file name, numbered in a suggested App Store order, and its launch arguments
# after `-DebugDemoProjects YES`. Project 0 is the demo's first, which shows off the most.
states=(
  "1-projects|"
  "2-project|-DebugOpenProject 0"
  "3-layout|-DebugOpenProject 0 -DebugSheet layout"
  "4-photo|-DebugOpenProject 0 -DebugSelectCell 1,1"
  "5-layers|-DebugOpenProject 0 -DebugSelectLayer 2,1 -DebugSheet layers"
  "6-panorama|-DebugOpenProject 0 -DebugSelectLayer 3,0"
  "7-export|-DebugOpenProject 0 -DebugSheet export"
  "8-new-project|-DebugSheet newProject"
)

if [ "$build_first" -eq 1 ]; then
  ./scripts/build.sh
elif [ ! -d "$app_path" ]; then
  echo "$(basename "$app_path") not found, building first..."
  ./scripts/build.sh
fi

scratch=$(mktemp -d -t carouline-screenshots.XXXXXX)
# What this run changed, to put back on exit: appearances as `<udid>=<appearance>`, the UDIDs
# whose status bar it overrode, and Duos it unfolded as `<udid>|<screen>|<orientation>`.
appearance_restores=()
status_bar_restores=()
fold_restores=()
restore() {
  local entry udid screen orientation
  for entry in ${fold_restores[@]+"${fold_restores[@]}"}; do
    IFS='|' read -r udid screen orientation <<<"$entry"
    if [ "$screen" = cover ]; then
      duoctl -d "$udid" close >/dev/null 2>&1 || true
    fi
    duoctl -d "$udid" rotate "$orientation" >/dev/null 2>&1 || true
  done
  for udid in ${status_bar_restores[@]+"${status_bar_restores[@]}"}; do
    xcrun simctl status_bar "$udid" clear >/dev/null 2>&1 || true
  done
  for entry in ${appearance_restores[@]+"${appearance_restores[@]}"}; do
    xcrun simctl ui "${entry%%=*}" appearance "${entry#*=}" >/dev/null 2>&1 || true
  done
  rm -rf "$scratch"
}
trap restore EXIT

# Stops the run when duoctl can't unfold Duo `$1`, which a simulator stuck mid-fold also causes
# until it reboots.
fold_failed() {
  echo "error: duoctl couldn't unfold '$1'. Shut it down with 'xcrun simctl shutdown $2', which this script boots again, and rerun." >&2
  exit 1
}

# Saves simulator `$1`'s display `$2`, or simctl's default when it's empty, to `$3` once the app
# stops moving: four seconds for it to launch, then until two frames a second apart match, so
# loading placeholders, the debug sheet's half-second delay and its slide in are all over. Gives
# up after twenty seconds. A warm launch stays blank until about two seconds in while it writes
# the demo store, and blank frames match each other, so a shorter wait could keep one.
capture_settled() {
  local udid=$1 display=$2 destination=$3
  local previous="$scratch/previous.png" current="$scratch/current.png"
  sleep 4
  xcrun simctl io "$udid" screenshot ${display:+"--display=$display"} "$previous" >/dev/null 2>&1
  for _ in $(seq 1 20); do
    sleep 1
    xcrun simctl io "$udid" screenshot ${display:+"--display=$display"} "$current" >/dev/null 2>&1
    if cmp -s "$previous" "$current"; then
      mv "$current" "$destination"
      return
    fi
    mv "$current" "$previous"
  done
  echo "warning: the screen never settled; kept its last frame" >&2
  mv "$previous" "$destination"
}

for device in "${devices[@]}"; do
  read -r udid device_type <<<"$(xcrun simctl list devices available --json |
    jq -r --arg device "$device" 'first(.devices[][] | select(.name == $device or .udid == $device) | "\(.udid) \(.deviceTypeIdentifier)") // empty')"
  if [ -z "$udid" ]; then
    echo "error: no available simulator named '$device'. Run ./scripts/setup.sh to create it." >&2
    exit 1
  fi
  xcrun simctl bootstatus "$udid" -b >/dev/null
  previous_appearance=$(xcrun simctl ui "$udid" appearance)
  if [ "$previous_appearance" != "$appearance" ]; then
    appearance_restores+=("$udid=$previous_appearance")
    xcrun simctl ui "$udid" appearance "$appearance"
  fi
  status_bar_restores+=("$udid")
  xcrun simctl status_bar "$udid" override --time "$status_bar_time" --dataNetwork wifi --wifiMode active \
    --wifiBars 3 --cellularMode active --cellularBars 4 --operatorName '' --batteryState discharging --batteryLevel 100
  # A Duo's screen that's off captures solid black, and simctl's default can be that one, so its
  # shots name the inner display duoctl reports.
  display=""
  if [ "$device_type" = "$duo_device_type" ]; then
    if ! command -v duoctl >/dev/null 2>&1; then
      echo "error: iPhone Duo needs duoctl to unfold it. Run ./scripts/setup.sh to install it." >&2
      exit 1
    fi
    fold=$(duoctl -d "$udid" state) || fold_failed "$device" "$udid"
    fold_restores+=("$udid|$(jq -r .activeScreen <<<"$fold")|$(jq -r .orientation <<<"$fold")")
    duoctl -d "$udid" open >/dev/null || fold_failed "$device" "$udid"
    duoctl -d "$udid" rotate landscape >/dev/null || fold_failed "$device" "$udid"
    display=$(duoctl -d "$udid" state | jq -r .displayId) || fold_failed "$device" "$udid"
  fi
  xcrun simctl terminate "$udid" "$bundle_id" >/dev/null 2>&1 || true
  xcrun simctl install "$udid" "$app_path"
  # A launch to throw away, since the first after an install is the slowest, and could still be
  # blank when the capture starts.
  xcrun simctl launch "$udid" "$bundle_id" -DebugDemoProjects YES >/dev/null
  capture_settled "$udid" "$display" "$scratch/warm-up.png"

  device_dir="$output_dir/$device"
  rm -rf "$device_dir"
  mkdir -p "$device_dir"
  for state in "${states[@]}"; do
    name=${state%%|*}
    read -r -a launch_args <<<"${state#*|}"
    xcrun simctl terminate "$udid" "$bundle_id" >/dev/null 2>&1 || true
    xcrun simctl launch "$udid" "$bundle_id" -DebugDemoProjects YES ${launch_args[@]+"${launch_args[@]}"} >/dev/null
    capture_settled "$udid" "$display" "$device_dir/$name.png"
    echo "Saved $device_dir/$name.png"
  done
  xcrun swift "$repo_root/scripts/lib/drop-alpha.swift" "$device_dir"/*.png
  xcrun simctl terminate "$udid" "$bundle_id" >/dev/null 2>&1 || true
done
