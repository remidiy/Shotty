#!/usr/bin/env bash
# Builds Shotty.app into dist/ (release, ad-hoc signed) and zips it.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Shotty"

swift scripts/make-icon.swift build/icon >/dev/null
iconutil -c icns build/icon/AppIcon.iconset -o build/icon/AppIcon.icns

APP=dist/Shotty.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Shotty"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp build/icon/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc signature. Sign with your Developer ID for distribution:
#   SIGN_ID="Developer ID Application: …" scripts/build-app.sh
codesign --force --options runtime --sign "${SIGN_ID:--}" "$APP"

(cd dist && rm -f Shotty.zip && ditto -c -k --keepParent Shotty.app Shotty.zip)
echo "Built $APP"
