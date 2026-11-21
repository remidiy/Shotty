# Releasing Shotty

How to ship a signed, notarized build that opens on any Mac without warnings, and publish it as open source.

## One-time setup

1. **Apple Developer Program** ($99/year): https://developer.apple.com/programs/. Required for a Developer ID certificate. Without it, users must right-click → Open, or run `xattr -dr com.apple.quarantine Shotty.app`.
2. **Developer ID Application certificate**: Xcode → Settings → Accounts → Manage Certificates → + → *Developer ID Application*. Check it with:
   ```bash
   security find-identity -v -p codesigning
   ```
3. **Notarization credentials** stored in the keychain (uses an app-specific password from https://account.apple.com):
   ```bash
   xcrun notarytool store-credentials shotty-notary --apple-id YOU@example.com --team-id TEAMID
   ```

## Each release

```bash
# 1. bump CFBundleShortVersionString / CFBundleVersion in Resources/Info.plist, commit
# 2. build, sign, notarize, staple, zip, and create the GitHub release
SIGN_ID="Developer ID Application: Your Name (TEAMID)" NOTARY_PROFILE=shotty-notary \
  scripts/release.sh 0.2.0
```

`scripts/release.sh` does:

1. `scripts/build-app.sh` with your Developer ID and the hardened runtime.
2. `xcrun notarytool submit … --wait` to have Apple scan it.
3. `xcrun stapler staple` so Gatekeeper works offline.
4. Zips `dist/Shotty-<version>.zip` and prints its SHA-256.
5. `gh release create v<version>` with the zip attached.

Check a build before shipping:

```bash
spctl -a -vvv -t exec dist/Shotty.app     # should say: accepted, source=Notarized Developer ID
codesign -dv --verbose=2 dist/Shotty.app
```

## Homebrew

Once there is a notarized release, users can install with Homebrew:

1. Create a tap repo named `remidiy/homebrew-tap`.
2. Copy `packaging/homebrew/shotty.rb` to `Casks/shotty.rb` in that repo, fill in `version` and `sha256` from the release output.
3. Users install with `brew install --cask remidiy/tap/shotty`.

After it has some users (Homebrew asks for notability), it can go to the main `homebrew/cask` repo.

## Open source checklist

- [x] MIT `LICENSE`
- [x] README with install, permissions and build-from-source steps
- [x] `CONTRIBUTING.md`
- [ ] Turn on GitHub Releases and add the repo description and topics
- [ ] Turn on private vulnerability reporting (Settings → Security)
- [ ] Optional: GitHub Sponsors, a landing page linking to the latest release

## Permissions users will see

| Permission | Why | Where |
| --- | --- | --- |
| Accessibility | Press ⌘V and Return in the target app | Privacy & Security → Accessibility |
| Screen Recording | Only for Shotty's own ⌃⇧4 capture | Privacy & Security → Screen & System Audio Recording |
| Desktop / folder | See new files in the screenshot folder | Prompted on first launch |

Ad-hoc builds get a new code identity every rebuild, so macOS forgets these grants. Developer ID builds keep them across updates.
