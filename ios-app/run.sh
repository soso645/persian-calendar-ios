#!/bin/sh
# Build, install and launch the app on the iOS simulator.
#
#   ./run.sh                 build, install, launch
#   ./run.sh --shot out.png  ...then capture a screenshot
#   DEVICE="iPhone Air" ./run.sh
#
# If DEVELOPER_DIR is unset or stale, the script uses an installed Xcode.
set -e
cd "$(dirname "$0")"

if [ -z "${DEVELOPER_DIR:-}" ] || [ ! -d "$DEVELOPER_DIR" ]; then
  for candidate in \
    /Applications/Xcode.app/Contents/Developer \
    /Applications/Xcode-beta.app/Contents/Developer \
    "$(xcode-select -p 2>/dev/null || true)"
  do
    if [ -n "$candidate" ] && [ -d "$candidate" ]; then
      export DEVELOPER_DIR="$candidate"
      break
    fi
  done
fi

if [ -z "${DEVELOPER_DIR:-}" ] || [ ! -d "$DEVELOPER_DIR" ]; then
  echo "Unable to find Xcode. Install Xcode or set DEVELOPER_DIR." >&2
  exit 1
fi

DEVICE="${DEVICE:-iPhone 17}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$PWD/build/DerivedData}"
BUNDLE_ID=com.byagowi.persiancalendar.ios

SHOT=""
if [ "$1" = "--shot" ]; then
    SHOT="${2:-screenshot.png}"
    shift 2
fi

echo "==> Building"
xcodebuild -scheme PersianCalendar \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -quiet build

echo "==> Booting $DEVICE"
xcrun simctl boot "$DEVICE" 2>/dev/null || true

# Show the simulator window if this install has one.
SIMULATOR="$DEVELOPER_DIR/Applications/Simulator.app"
if [ -d "$SIMULATOR" ]; then
    open -a "$SIMULATOR"
else
    echo "    (no Simulator.app in this Xcode install; running headlessly)"
fi

APP=$(xcodebuild -scheme PersianCalendar \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/ BUILT_PRODUCTS_DIR/ {d=$2} / FULL_PRODUCT_NAME/ {n=$2} END {print d "/" n}')

echo "==> Installing"
xcrun simctl install "$DEVICE" "$APP"

echo "==> Launching"
xcrun simctl launch "$DEVICE" "$BUNDLE_ID" "$@" >/dev/null
echo "    running on $DEVICE"

if [ -n "$SHOT" ]; then
    sleep 5
    xcrun simctl io "$DEVICE" screenshot "$SHOT" >/dev/null 2>&1
    echo "==> Screenshot: $SHOT"
fi
