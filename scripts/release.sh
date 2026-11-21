#!/usr/bin/env bash
# Build, sign with Developer ID, notarize, staple and publish a GitHub release.
# Usage: SIGN_ID="Developer ID Application: …" NOTARY_PROFILE=shotty-notary scripts/release.sh 0.2.0
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: scripts/release.sh <version>}"
: "${SIGN_ID:?set SIGN_ID to your Developer ID Application identity}"
: "${NOTARY_PROFILE:?set NOTARY_PROFILE to your notarytool keychain profile}"

SIGN_ID="$SIGN_ID" scripts/build-app.sh

ZIP="dist/Shotty-$VERSION.zip"
ditto -c -k --keepParent dist/Shotty.app "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple dist/Shotty.app
rm "$ZIP" && ditto -c -k --keepParent dist/Shotty.app "$ZIP"
spctl -a -vvv -t exec dist/Shotty.app

SHA=$(shasum -a 256 "$ZIP" | cut -d' ' -f1)
echo "sha256: $SHA"

gh release create "v$VERSION" "$ZIP" --title "Shotty $VERSION" --generate-notes
echo "Update packaging/homebrew/shotty.rb with version $VERSION and sha256 $SHA"
