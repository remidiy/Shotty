<p align="center"><img src="assets/logo.png" width="96" alt="Shotty logo"></p>

<h1 align="center">Shotty</h1>

<p align="center"><b>Screenshot → your AI agent, instantly.</b><br>
A small macOS app that lives in your menu bar and drops every new screenshot or screen recording straight into Claude, Claude Code, Codex, Cursor or any app you choose.</p>

<p align="center">
  <img src="assets/screenshots/panel.png" width="320" alt="Shotty menu bar panel">
  &nbsp;&nbsp;
  <img src="assets/screenshots/settings.png" width="400" alt="Shotty settings">
</p>

<p align="center">
  <img src="assets/screenshots/v0.5.0/main-home.png" width="640" alt="Shotty app window">
</p>

## Why

Showing an agent what you see usually takes five steps: screenshot, find the file, switch apps, drag it in, type a question. Shotty does it in one. Take the shot and it's already in the chat, with your prompt if you want one.

## Features

- **Watch it fly in**: the screenshot lifts off and arcs into the window of the app it's going to, then a soft ripple marks where it landed. Respects Reduce Motion; can be turned off in Settings.
- **Instant capture**: press **⌃⇧4**, select an area (or Space for a window), and it's pasted the moment you let go.
- **Works with normal screenshots too**: ⇧⌘3, ⇧⌘4 and ⇧⌘5 recordings are picked up from your screenshot folder.
- **Goes to the app you were using**: work in Cursor, take a screenshot, it lands in Cursor. Switch to Ghostty, it lands there. Or pin one app ("Always send to…").
- **A full app when you want it**: Open Shotty from the menu bar for a window with Home, History, Targets and Settings. It shows in the Dock while the window is open and goes back to the menu bar when you close it.
- **A short welcome on first launch**: what Shotty does, where shots go, Accessibility (with a live check), the screenshot folder and the shortcuts. Reopen it from Help → Show Welcome….
- **History you can drag from**: every capture is kept in the menu bar panel and the History section. Drag one into any app, send it again, or reveal it in Finder.
- **Two paste modes**: *Attachment* pastes the image itself (chat apps). *File path* pastes the path, which is what Claude Code and Codex CLI read in a terminal.
- **Optional prompt** pasted with the shot, and optional **send automatically** (presses Return).
- **Leaves your clipboard alone**: what you had copied is restored after the paste.
- Native SwiftUI with the standard macOS translucent materials. No account, no network, no tracking.

## Install

### Download (recommended)

1. Download **[Shotty.dmg](https://github.com/remidiy/Shotty/releases/latest/download/Shotty.dmg)** from the [latest release](https://github.com/remidiy/Shotty/releases/latest). Prefer a zip? Use [Shotty.zip](https://github.com/remidiy/Shotty/releases/latest/download/Shotty.zip).
2. Open the DMG and drag **Shotty** onto **Applications**.
3. Open Shotty from Applications. A short welcome walks you through setup, and Shotty stays in the menu bar (the blue square with two eyes).

Current builds are not notarized by Apple yet, so macOS blocks the first launch. Either right-click Shotty.app → **Open** → **Open**, or run:

```bash
xattr -dr com.apple.quarantine /Applications/Shotty.app
```

Older versions are on the [releases page](https://github.com/remidiy/Shotty/releases), each with a versioned DMG, zip and SHA-256 checksums.

### Homebrew

```bash
brew install --cask remidiy/tap/shotty
```

(Available once the first notarized release is out; see [docs/RELEASING.md](docs/RELEASING.md).)

### Build from source

Needs macOS 26 or later and Xcode 26 or later.

```bash
git clone https://github.com/remidiy/Shotty.git
cd Shotty
./scripts/build-app.sh        # builds dist/Shotty.app (and dist/Shotty.zip)
open dist/Shotty.app
```

### Keep permissions across rebuilds

macOS remembers privacy permissions by code signature. Run this once so every build you make is signed with the same local certificate:

```bash
./scripts/setup-signing.sh    # one time: creates "Shotty Local Signing" in your login keychain
./scripts/build-app.sh
./scripts/install.sh          # copies to /Applications and restarts Shotty
```

### Build a DMG

```bash
./scripts/build-app.sh
./scripts/make-dmg.sh         # creates dist/Shotty.dmg with an Applications shortcut
```

Set `SIGN_ID="Developer ID Application: …"` on both commands to sign with your own certificate.

## First run

The welcome window explains each step. Shotty lives in the menu bar (rounded square with two eyes). macOS will ask for:

| Permission | Why |
| --- | --- |
| **Accessibility** | To press ⌘V (and Return) in the app you picked |
| **Screen Recording** | Only for Shotty's own ⌃⇧4 capture |
| **Desktop / folder access** | To notice new files in your screenshot folder |

## Shotty keeps asking for permissions?

Builds before 0.4.1 were signed ad hoc, so macOS treated every update as a new app and forgot what you allowed. From 0.4.1 Shotty is signed with a stable certificate. Clear the old entries once, then allow Shotty again when asked:

```bash
tccutil reset Accessibility com.remidiy.shotty
tccutil reset ScreenCapture com.remidiy.shotty
```

If you build Shotty yourself, run `scripts/setup-signing.sh` once (see above).

## Why normal screenshots can feel slow

By default macOS shows a floating thumbnail for about 5 seconds after ⇧⌘4 and only writes the file when it disappears. Nothing can send it before then. Fix it either way:

- Use Shotty's **⌃⇧4** shortcut, which never shows the thumbnail, or
- Click **Make Instant** in Shotty (or untick *Show Floating Thumbnail* in the ⇧⌘5 Options menu).

After that, Shotty usually pastes in well under half a second. It shows the time for each send.

## Could Shortcuts or Folder Actions do this?

Mostly, with glue. On macOS 26, Shortcuts automations can trigger when a file is added to a folder, and so can Folder Actions. The paste itself still needs a "Run AppleScript" step sending keystrokes. You'd also have to handle partly written recordings, separate logic for chat apps vs terminals, switching targets by editing the shortcut, and losing your clipboard. Shotty packages all of that.

## Releases

Every version is published on [GitHub Releases](https://github.com/remidiy/Shotty/releases) with `Shotty.dmg`, `Shotty.zip`, versioned copies and checksums. To cut one:

1. Bump `CFBundleShortVersionString` and `CFBundleVersion` in `Resources/Info.plist` and write `docs/releases/v<version>.md`.
2. Merge to `main` through a pull request.
3. On a clean `main`, run:

```bash
./scripts/release.sh
```

For a signed and notarized release, set `SIGN_ID` and `NOTARY_PROFILE` first; see [docs/RELEASING.md](docs/RELEASING.md).

## Develop

```bash
swift build                                       # debug build
dist/Shotty.app/Contents/MacOS/Shotty --demo      # preview the UI with sample data, sends nothing
dist/Shotty.app/Contents/MacOS/Shotty --demo-app --open-main   # the full app with sample data
defaults delete com.remidiy.shotty hasSeenWelcome # show the welcome again on next launch
```

| File | What it does |
| --- | --- |
| `FolderWatcher.swift` | Notices new captures and waits until they're fully written |
| `InstantCapture.swift` | The ⌃⇧4 shortcut and `screencapture` call |
| `Sender.swift` | Brings the target app forward and pastes |
| `AppModel.swift` | Settings, state, and tracking the app you were using |
| `History.swift` | Saved capture history and thumbnails |
| `FlyInAnimation.swift` | The capture-flies-into-the-app overlay animation |
| `MenuView.swift`, `SettingsView.swift` | The menu bar panel and settings |
| `MainWindow.swift` | The app window: Home, History, Targets, Settings |
| `Onboarding.swift` | The first-launch welcome |
| `Logo.swift` | The logo as a SwiftUI view and the menu bar icon |

Feature specs: [docs/specs](docs/specs). Releasing, signing and notarization: [docs/RELEASING.md](docs/RELEASING.md). Contributions: [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT
