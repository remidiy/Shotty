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
# 1. bump CFBundleShortVersionString / CFBundleVersion in Resources/Info.plist
# 2. write docs/releases/v<version>.md (release notes), merge to main via PR
# 3. on a clean main:
scripts/release.sh                                  # ad-hoc signed (current default)
SIGN_ID="Developer ID Application: Your Name (TEAMID)" NOTARY_PROFILE=shotty-notary \
  scripts/release.sh                                # signed + notarized
```

`scripts/release.sh`:

1. Checks the tree is clean, the version matches `Info.plist` and the tag doesn't exist.
2. Builds `dist/Shotty.app` (`scripts/build-app.sh`), and when signing, notarizes and staples it.
3. Packages `Shotty.zip` and `Shotty.dmg` (`scripts/make-dmg.sh`); notarizes and staples the DMG when signing.
4. Uploads `Shotty.zip`, `Shotty.dmg`, `Shotty-<version>.zip`, `Shotty-<version>.dmg` and `SHA256SUMS.txt` to a new `v<version>` GitHub release, using `docs/releases/v<version>.md` as notes.

The unversioned `Shotty.zip` / `Shotty.dmg` names keep `releases/latest/download/…` links (the install site, README) working for every new version.

Check a signed build before shipping:

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
