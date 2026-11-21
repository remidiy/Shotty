# Spec 0004: DMG packaging and versioned GitHub releases

Status: Implemented · 21 Nov 2026

## Problem

Users need a normal Mac install: a disk image they open and drag to Applications. The install site links to `releases/latest/download/Shotty.zip`, so every release must carry an asset with that exact name.

## Behaviour

- `scripts/make-dmg.sh` turns `dist/Shotty.app` into `dist/Shotty.dmg`: a compressed (UDZO) image named "Shotty" holding the app and an Applications shortcut. Signed when `SIGN_ID` is a real identity.
- `scripts/release.sh [version]`:
  - Refuses to run with uncommitted changes, an existing tag, or a version that doesn't match `Info.plist`.
  - Builds the app, optionally notarizes and staples it (when `SIGN_ID` and `NOTARY_PROFILE` are set), packages `Shotty.zip` and `Shotty.dmg`, and notarizes the DMG too.
  - Uploads `Shotty.zip`, `Shotty.dmg` (stable names for `latest/download` links), `Shotty-<version>.zip`, `Shotty-<version>.dmg` and `SHA256SUMS.txt`.
  - Uses `docs/releases/v<version>.md` as the release notes, adding Gatekeeper instructions when the build isn't notarized.
- The README documents installing (DMG, zip, Homebrew, source), building a DMG, and cutting a release.

## Release flow

1. Feature work lands through a PR with its spec.
2. Bump `CFBundleShortVersionString` / `CFBundleVersion` and add `docs/releases/v<version>.md` in the same or a follow-up PR.
3. After merge, on `main`: `scripts/release.sh`.

## Test plan

- `scripts/build-app.sh && scripts/make-dmg.sh` produces a DMG that mounts with Shotty.app and Applications side by side.
- `scripts/release.sh` on a clean `main` creates the release with all five assets.
- `https://github.com/remidiy/Shotty/releases/latest/download/Shotty.zip` and `…/Shotty.dmg` download.
