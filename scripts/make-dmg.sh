#!/usr/bin/env bash
# Packages dist/Shotty.app into dist/Shotty.dmg (drag-to-Applications disk image).
# Usage: scripts/make-dmg.sh            (run scripts/build-app.sh first)
set -euo pipefail
cd "$(dirname "$0")/.."

APP=dist/Shotty.app
DMG=dist/Shotty.dmg
[ -d "$APP" ] || { echo "Missing $APP. Run scripts/build-app.sh first." >&2; exit 1; }

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/Shotty.app"
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG"
hdiutil create -quiet -volname "Shotty" -srcfolder "$STAGE" -fs HFS+ -format UDZO -imagekey zlib-level=9 -ov "$DMG" 2>/dev/null

if [ -n "${SIGN_ID:-}" ] && [ "${SIGN_ID}" != "-" ]; then
  codesign --force --sign "$SIGN_ID" "$DMG"
fi
echo "Built $DMG"
