#!/bin/sh
# Build an installable .ipa (arm64, iOS device build) from the Xcode project.
#
#   ./make-ipa.sh                  -> ../ipa/PersianCalendar.ipa
#   OUT_DIR=/tmp/out ./make-ipa.sh
#
# This machine has no code-signing identity installed, so the archive is built
# unsigned. Sideloadly / AltStore / Xcode re-sign it with your Apple ID on install.
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
: "${DEVELOPER_DIR:?Unable to find Xcode. Install Xcode or set DEVELOPER_DIR.}"

OUT_DIR="${OUT_DIR:-$(cd .. && pwd)/ipa}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$PWD/build/DerivedDataDevice}"
ARCHIVE_PATH="$PWD/build/PersianCalendar.xcarchive"
APP_NAME=PersianCalendar
IPA_PATH="$OUT_DIR/$APP_NAME.ipa"

echo "==> Archiving $APP_NAME (Release, iphoneos, unsigned)"
rm -rf "$ARCHIVE_PATH"
# Keep compiler caches inside the tree: this checkout can run under a file
# sandbox that denies ~/Library/Caches. Swift's plugin server also nested-
# sandboxes via sandbox-exec, which an outer sandbox rejects, hence
# -disable-sandbox.
mkdir -p build/tmp build/ModuleCache
TMPDIR="$PWD/build/tmp" \
CLANG_MODULE_CACHE_PATH="$PWD/build/ModuleCache" \
xcodebuild archive \
  -project PersianCalendar.xcodeproj \
  -scheme PersianCalendar \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_PATH" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  OTHER_SWIFT_FLAGS="-disable-sandbox" \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  -quiet

APP="$ARCHIVE_PATH/Products/Applications/$APP_NAME.app"
if [ ! -d "$APP" ]; then
  echo "Archive did not produce $APP" >&2
  exit 1
fi
codesign --force --sign - "$APP" >/dev/null 2>&1 || true

echo "==> Packaging $IPA_PATH"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/Payload"
cp -R "$APP" "$STAGE/Payload/"
mkdir -p "$OUT_DIR"
rm -f "$IPA_PATH"
# Keep the bundle's resource forks / permissions; no __MACOSX noise.
(cd "$STAGE" && COPYFILE_DISABLE=1 zip -qry "$IPA_PATH" Payload)

echo "==> Done"
echo "    $IPA_PATH ($(du -h "$IPA_PATH" | cut -f1))"
