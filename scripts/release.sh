#!/usr/bin/env bash
# Builds Shotty, packages Shotty.zip and Shotty.dmg, and publishes a GitHub release.
#
#   scripts/release.sh                 # version from Resources/Info.plist, ad-hoc signed
#   scripts/release.sh 0.4.0           # explicit version (must match Info.plist)
#   SIGN_ID="Developer ID Application: …" NOTARY_PROFILE=shotty-notary scripts/release.sh
#                                      # signed + notarized + stapled
#
# Assets uploaded: Shotty.zip and Shotty.dmg (stable names used by
# releases/latest/download/… links) plus Shotty-<version>.zip / .dmg.
set -euo pipefail
cd "$(dirname "$0")/.."

PLIST_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
VERSION="${1:-$PLIST_VERSION}"
if [ "$VERSION" != "$PLIST_VERSION" ]; then
  echo "Version $VERSION doesn't match Info.plist ($PLIST_VERSION). Bump Info.plist first." >&2
  exit 1
fi
if gh release view "v$VERSION" >/dev/null 2>&1; then
  echo "Release v$VERSION already exists." >&2
  exit 1
fi
if [ "$(git rev-parse --abbrev-ref HEAD)" != "main" ]; then
  echo "Release from main (currently on $(git rev-parse --abbrev-ref HEAD))." >&2
  exit 1
fi
git fetch -q origin main
if [ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]; then
  echo "Local main differs from origin/main. Pull or push first." >&2
  exit 1
fi
if [ -n "$(git status --porcelain)" ]; then
  echo "Working tree has uncommitted changes. Commit first." >&2
  exit 1
fi

SIGN_ID="${SIGN_ID:--}" scripts/build-app.sh

NOTARIZE=0
if [ "${SIGN_ID:--}" != "-" ] && [ -n "${NOTARY_PROFILE:-}" ]; then NOTARIZE=1; fi

if [ $NOTARIZE = 1 ]; then
  ditto -c -k --keepParent dist/Shotty.app dist/notarize.zip
  xcrun notarytool submit dist/notarize.zip --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple dist/Shotty.app
  rm dist/notarize.zip
fi

(cd dist && rm -f Shotty.zip && ditto -c -k --keepParent Shotty.app Shotty.zip)
SIGN_ID="${SIGN_ID:--}" scripts/make-dmg.sh

if [ $NOTARIZE = 1 ]; then
  xcrun notarytool submit dist/Shotty.dmg --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple dist/Shotty.dmg
fi

cp dist/Shotty.zip "dist/Shotty-$VERSION.zip"
cp dist/Shotty.dmg "dist/Shotty-$VERSION.dmg"
shasum -a 256 dist/Shotty-"$VERSION".* | tee dist/SHA256SUMS.txt

NOTES="docs/releases/v$VERSION.md"
if [ $NOTARIZE = 0 ]; then
  GATEKEEPER=$'\n\n> This build is not notarized. On first launch, right-click Shotty.app → **Open** → **Open**, or run `xattr -dr com.apple.quarantine /Applications/Shotty.app`.'
else
  GATEKEEPER=""
fi
if [ -f "$NOTES" ]; then BODY="$(cat "$NOTES")$GATEKEEPER"; else BODY="Shotty $VERSION$GATEKEEPER"; fi

gh release create "v$VERSION" \
  dist/Shotty.zip dist/Shotty.dmg "dist/Shotty-$VERSION.zip" "dist/Shotty-$VERSION.dmg" dist/SHA256SUMS.txt \
  --target "$(git rev-parse HEAD)" --title "Shotty $VERSION" --notes "$BODY"

echo "Released v$VERSION. For Homebrew, update packaging/homebrew/shotty.rb with:"
grep "Shotty-$VERSION.zip" dist/SHA256SUMS.txt
