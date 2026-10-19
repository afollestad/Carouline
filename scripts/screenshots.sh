#!/bin/bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: ./scripts/screenshots.sh [-b|--build] [--dark] [-d|--device <name>]... [-o|--output <dir>]

Launches the app's demo projects (`-DebugDemoProjects YES`) in each App Store screenshot state
and saves a PNG of each to <dir>/<device>/, `.build/screenshots` by default, emptying that
folder first. Captures on iPhone 18 Pro, iPad Pro 13-inch (M5) (16GB) and iPhone Duo unless
`-d` names others. `-b` builds first, and `--dark` captures in dark mode, restoring each
simulator's appearance afterward.

Shots keep each simulator's orientation, an iPad's multitasking mode, and iPhone Duo's fold,
which simctl can't set: rotate it in Device Hub, choose Full Screen Apps in an iPad's Settings >
Multitasking & Gestures to hide the window's resize handle, and unfold the Duo there to shoot
its larger inner display rather than the outer. App Store Connect takes either display's size.
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
# Simulators whose appearance this run changed, as `<udid>=<appearance>`, to put back on exit.
restores=()
restore() {
  for entry in ${restores[@]+"${restores[@]}"}; do
    xcrun simctl ui "${entry%%=*}" appearance "${entry#*=}" >/dev/null 2>&1 || true
  done
  rm -rf "$scratch"
}
trap restore EXIT

# Saves display `$2` to `$3` once the app on simulator `$1` stops moving: four seconds for it
# to launch, then until two frames a second apart match, so loading placeholders, the debug
# sheet's half-second delay and its slide in are all over. Gives up after twenty seconds. A
# warm launch stays blank until about two seconds in while it writes the demo store, and blank
# frames match each other, so a shorter wait could keep one.
capture_settled() {
  local udid=$1 display=$2 destination=$3
  local previous="$scratch/previous.png" current="$scratch/current.png"
  sleep 4
  xcrun simctl io "$udid" screenshot --display="$display" "$previous" >/dev/null 2>&1
  for _ in $(seq 1 20); do
    sleep 1
    xcrun simctl io "$udid" screenshot --display="$display" "$current" >/dev/null 2>&1
    if cmp -s "$previous" "$current"; then
      mv "$current" "$destination"
      return
    fi
    mv "$current" "$previous"
  done
  echo "warning: the screen never settled; kept its last frame" >&2
  mv "$previous" "$destination"
}

# Prints the `simctl io` name of each of simulator `$1`'s built-in displays: one, or a
# foldable's two. simctl's default can be the one that's off, so shots name theirs.
built_in_displays() {
  xcrun simctl io "$1" enumerate | awk '/Device Name:/ { name = $3 } /Screen Type: Integrated/ { print name }'
}

for device in "${devices[@]}"; do
  udid=$(xcrun simctl list devices available --json |
    jq -r --arg device "$device" 'first(.devices[][] | select(.name == $device or .udid == $device) | .udid) // empty')
  if [ -z "$udid" ]; then
    echo "error: no available simulator named '$device'. Run ./scripts/setup.sh to create it." >&2
    exit 1
  fi
  xcrun simctl bootstatus "$udid" -b >/dev/null
  previous_appearance=$(xcrun simctl ui "$udid" appearance)
  if [ "$previous_appearance" != "$appearance" ]; then
    restores+=("$udid=$previous_appearance")
    xcrun simctl ui "$udid" appearance "$appearance"
  fi
  xcrun simctl terminate "$udid" "$bundle_id" >/dev/null 2>&1 || true
  xcrun simctl install "$udid" "$app_path"
  displays=()
  while IFS= read -r listed; do
    displays+=("$listed")
  done < <(built_in_displays "$udid")
  if [ ${#displays[@]} -eq 0 ]; then
    echo "error: found no built-in display on '$device'" >&2
    exit 1
  fi
  # A launch to throw away, since the first after an install is the slowest, and could still be
  # blank when the capture starts.
  xcrun simctl launch "$udid" "$bundle_id" -DebugDemoProjects YES >/dev/null
  for candidate in "${displays[@]}"; do
    capture_settled "$udid" "$candidate" "$scratch/warm-up.png"
  done
  # Shoots a foldable's lit display. Once the app has settled, the one that's off captures solid
  # black, whose PNG is a fraction of a lit one's size. A blank launch frame is nearly as small,
  # so the frames to compare come after every display has settled.
  display=${displays[0]}
  if [ ${#displays[@]} -gt 1 ]; then
    largest=-1
    for candidate in "${displays[@]}"; do
      xcrun simctl io "$udid" screenshot --display="$candidate" "$scratch/display.png" >/dev/null 2>&1
      size=$(stat -f %z "$scratch/display.png")
      if [ "$size" -gt "$largest" ]; then
        display=$candidate
        largest=$size
      fi
    done
  fi

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
  xcrun simctl terminate "$udid" "$bundle_id" >/dev/null 2>&1 || true
done
