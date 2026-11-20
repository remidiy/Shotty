<p align="center"><img src="assets/icon.png" width="128" alt="Shotty icon"></p>

<h1 align="center">Shotty</h1>

<p align="center">A tiny macOS menu bar app that sends every new screenshot or screen recording straight into Claude, Claude Code, Codex, Cursor or any app you pick.</p>

## What it does

1. Watches the folder macOS saves screenshots to (`defaults read com.apple.screencapture location`, or the Desktop).
2. When a new screenshot (⇧⌘3 / ⇧⌘4) or recording (⇧⌘5) finishes writing, Shotty brings your chosen app forward and pastes it in.
3. Optionally adds a prompt ("What's wrong in this screenshot?") and presses Return for you.

Two paste modes, picked per app:

| Mode | What gets pasted | Good for |
| --- | --- | --- |
| Attachment | The image/file itself (⌘V) | Claude, Codex, ChatGPT, Cursor |
| File path | The quoted file path as text | Claude Code or Codex CLI in Terminal, Ghostty, iTerm, Warp |

Your clipboard is restored afterwards. The UI is SwiftUI with Liquid Glass (macOS 26+).

## Install

```bash
git clone https://github.com/remidiy/Shotty.git
cd Shotty
./scripts/build-app.sh
open dist/Shotty.app
```

Requires macOS 26 or later and Xcode 26+ (Swift 6). Move `dist/Shotty.app` to `/Applications` if you want it to stay.

On first use macOS asks for:

- **Accessibility**: needed to press ⌘V and Return in the target app (System Settings → Privacy & Security → Accessibility).
- **Desktop / folder access**: to see new files in your screenshot folder.

The build is ad-hoc signed, so macOS treats each rebuild as a new app; re-enable Accessibility after rebuilding.

**Tip:** turn off *Show Floating Thumbnail* in the ⇧⌘5 Options menu. With it on, macOS waits about 5 seconds before writing the file.

## Could Shortcuts or Folder Actions do this?

Partly. A Folder Action (Automator) on the screenshot folder can run an AppleScript that copies the new file, activates an app and sends ⌘V via System Events. It works, but:

- Folder Actions are slow to fire and occasionally silently stop running.
- They see the hidden temporary file and partially written recordings unless you add waits.
- Each target app, prompt and paste style needs its own script edit; there's no quick switcher.
- Shortcuts has no "new file in folder" trigger on macOS, so it can only be run by hand or by a hotkey.

Shotty is the same idea with reliable file watching, a one-click target switcher, per-app paste modes, an optional prompt, and clipboard restore.

## Develop

```bash
swift build          # debug build
swift run Shotty     # run without bundling (some permissions behave better from the .app)
swift scripts/make-icon.swift build/icon   # regenerate icon PNGs
```

Code lives in `Sources/Shotty/`: `FolderWatcher` (new-file detection), `Sender` (activate + paste), `AppModel` (settings and state), `MenuView` (Liquid Glass UI).

## License

MIT
