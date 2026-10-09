#!/usr/bin/env bash
# Capture the store screenshots on one device and sort them into place.
#
#   tools/screenshots.sh <target>      e.g. iphone-69, ipad-13, android-phone, android-fold
#   tools/screenshots.sh all-ios       iphone-69, iphone-63, ipad-13 in turn
#   tools/screenshots.sh all-android   android-phone, android-fold in turn
#
# It boots the device (an iOS Simulator, or an Android emulator AVD), runs the shot flow in
# app/integration_test/shots.dart with `flutter drive`, which saves one PNG per shot to
# app/build/screenshots/raw/<target>/, then runs tools/screenshots.py to check the sizes and copy
# them to the store folders. The app runs with an in-memory database, so Megrim dev's own data on
# the device is never touched.
#
# Device names differ between Xcode and SDK versions; override them with these if needed:
#   MEGRIM_SIM_IPHONE_69  (default "iPhone 17 Pro Max")    MEGRIM_SIM_IPHONE_63 ("iPhone 17 Pro")
#   MEGRIM_SIM_IPAD_13    (default "iPad Pro 13-inch")      MEGRIM_SIM_DUO (no default yet)
#   MEGRIM_AVD_PHONE      (default "megrim_phone")         MEGRIM_AVD_FOLD ("megrim_fold")
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/app"

die() { echo "screenshots: $*" >&2; exit 1; }

# --- iOS Simulator -----------------------------------------------------------------------------

sim_udid() { # $1 = name prefix; prints the UDID of the first available Simulator that matches
  xcrun simctl list devices available -j | python3 -c '
import json, sys
want = sys.argv[1]
for runtime, devs in json.load(sys.stdin)["devices"].items():
    if "iOS" not in runtime:
        continue
    for d in devs:
        if d["name"] == want or d["name"].startswith(want):
            print(d["udid"]); sys.exit(0)
sys.exit(1)' "$1"
}

boot_sim() { # $1 = name; prints the UDID once booted
  local udid
  udid="$(sim_udid "$1")" || die "no Simulator named \"$1\" (see: xcrun simctl list devices available)"
  xcrun simctl boot "$udid" 2>/dev/null || true # already booted is fine
  open -a Simulator
  xcrun simctl bootstatus "$udid" -b >/dev/null
  echo "$udid"
}

# --- Android emulator --------------------------------------------------------------------------

avd_serial() { # $1 = AVD name; prints the serial of a running emulator with that AVD, if any
  local s
  for s in $(adb devices | awk '/^emulator-/{print $1}'); do
    if [ "$(adb -s "$s" emu avd name 2>/dev/null | head -1 | tr -d '\r')" = "$1" ]; then
      echo "$s"; return 0
    fi
  done
  return 1
}

boot_avd() { # $1 = AVD name; prints the serial once booted
  local serial
  if ! serial="$(avd_serial "$1")"; then
    emulator -list-avds | grep -qx "$1" || die "no AVD named \"$1\" (see the AVD setup in .claude/test-store-screenshots.md)"
    nohup emulator -avd "$1" -no-snapshot-save >/dev/null 2>&1 &
    for _ in $(seq 1 90); do serial="$(avd_serial "$1")" && break; sleep 2; done
    [ -n "${serial:-}" ] || die "emulator \"$1\" didn't start"
  fi
  adb -s "$serial" wait-for-device
  until [ "$(adb -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do sleep 2; done
  echo "$serial"
}

# --- one target --------------------------------------------------------------------------------

run_target() {
  local target="$1" device
  case "$target" in
    iphone-69) device="$(boot_sim "${MEGRIM_SIM_IPHONE_69:-iPhone 17 Pro Max}")" ;;
    iphone-63) device="$(boot_sim "${MEGRIM_SIM_IPHONE_63:-iPhone 17 Pro}")" ;;
    ipad-13) device="$(boot_sim "${MEGRIM_SIM_IPAD_13:-iPad Pro 13-inch}")" ;;
    duo-inner | duo-outer)
      [ -n "${MEGRIM_SIM_DUO:-}" ] || die "set MEGRIM_SIM_DUO to the iPhone Duo Simulator's name (none known yet)"
      device="$(boot_sim "$MEGRIM_SIM_DUO")" ;;
    android-phone) device="$(boot_avd "${MEGRIM_AVD_PHONE:-megrim_phone}")" ;;
    android-fold)
      device="$(boot_avd "${MEGRIM_AVD_FOLD:-megrim_fold}")"
      adb -s "$device" emu unfold >/dev/null 2>&1 || true # inner (unfolded) screen
      sleep 2 ;;
    *) die "unknown target \"$target\" (run tools/screenshots.py --list)" ;;
  esac

  echo "== $target on $device"
  rm -rf "$APP/build/screenshots/raw/$target"
  (cd "$APP" && MEGRIM_SHOTS_DIR="build/screenshots/raw/$target" flutter drive \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/screenshots_test.dart \
    -d "$device")
  python3 "$ROOT/tools/screenshots.py" "$target"
}

[ $# -ge 1 ] || die "usage: tools/screenshots.sh <target>|all-ios|all-android (targets: tools/screenshots.py --list)"
case "$1" in
  all-ios) for t in iphone-69 iphone-63 ipad-13; do run_target "$t"; done ;;
  all-android) for t in android-phone android-fold; do run_target "$t"; done ;;
  *) for t in "$@"; do run_target "$t"; done ;;
esac
