#!/usr/bin/env bash
# Builds Shotty.app into dist/ and zips it.
# Signing: $SIGN_ID if set; otherwise the "Shotty Local Signing" certificate from
# scripts/setup-signing.sh if present; otherwise ad-hoc (macOS forgets permissions on rebuild).
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

LOCAL_CERT="${SHOTTY_CERT_NAME:-Shotty Local Signing}"
if [ -z "${SIGN_ID:-}" ] || [ "${SIGN_ID}" = "-" ]; then
  if [ -z "${SIGN_ID:-}" ] && security find-certificate -c "$LOCAL_CERT" >/dev/null 2>&1; then
    SIGN_ID="$LOCAL_CERT"
  else
    SIGN_ID="-"
    echo "warning: ad-hoc signing. macOS will forget Shotty's permissions after each rebuild." >&2
    echo "         Run scripts/setup-signing.sh once to fix that." >&2
  fi
fi
codesign --force --options runtime --identifier com.remidiy.shotty --sign "$SIGN_ID" "$APP"
codesign -dr - "$APP" 2>&1 | sed -n 's/^# designated => /designated requirement: /p'

(cd dist && rm -f Shotty.zip && ditto -c -k --keepParent Shotty.app Shotty.zip)
echo "Built $APP"
