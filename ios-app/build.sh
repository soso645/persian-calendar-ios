#!/bin/sh
# Build/test helper.
# Usage: ./build.sh [build|test]   (default: build)
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

exec xcodebuild -scheme PersianCalendar \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  "${1:-build}"
