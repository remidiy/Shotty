# Spec 0007: One logo, a full app window, and a welcome

Status: Implemented in v0.5.0 · 21 Nov 2026

## Problem

1. Shotty had three different marks: a round face on the app icon, a camera SF Symbol in the menu bar and a placeholder in the panel. The website uses a different logo again.
2. Everything lived in a 320 pt menu bar panel. History, targets and settings had no room, and there was no way to find Shotty except the menu bar.
3. A new user got a permission prompt and an icon in the menu bar, with nothing explaining what Shotty does or what to allow.

## Behaviour

### One logo everywhere

The website mark (`apps/shotty-site/public/logo.svg`) is the logo: a rounded square (corner radius 115/512 of the side) with a vertical gradient from `#5C9EFF` to `#335CF5`, and two white capsule eyes (67 × 123 on a 512 canvas, at x 172 and 273, y 179–302).

- **App icon**: `scripts/make-icon.swift` draws the mark on the macOS icon grid (824/1024 tile) with a soft drop shadow. No face circle, no shine. `logo-512.png` is the full-bleed version.
- **Assets**: `assets/logo.svg`, `assets/logo.png` and `assets/icon.png` match.
- **Menu bar**: an 18 × 18 template image of the rounded square with the eyes cut out. When paused it's an outline with filled eyes. Replaces the `camera.viewfinder` symbol.
- **In the UI**: `ShottyMark` (SwiftUI) draws the same mark from the same geometry (`Logo.swift`). It replaces `LogoPlaceholder` and `BotFace`.

### Full app window

A `Window` scene, "Shotty", with a `NavigationSplitView` sidebar:

| Section | Contents |
| --- | --- |
| **Home** | Logo, on/off switch with the watched folder, the current target (icon, follow mode, paste mode), Capture and Send Latest, permission and Floating Thumbnail callouts, the six most recent captures as draggable tiles |
| **History** | Every capture with larger thumbnails, search, drag into any app, send again, Show in Finder, context menu, Clear History |
| **Targets** | "Send to the app I was using", every app with its paste mode and a Use button, Add App…, remove custom apps, prompt and auto-send |
| **Settings** | The same form as the Settings window (⌘,) |

The sidebar footer shows Watching/Paused with a switch.

Open it from **Open Shotty** (⌘0) in the menu bar panel, from **File → Open Shotty Window**, or by finishing the welcome.

**Dock.** Shotty stays a menu bar app (`LSUIElement` unchanged). While the main, welcome or Settings window is open, it switches to `.regular` activation policy, so it has a Dock icon, ⌘-Tab and a main menu. When the last of those windows closes it switches back to `.accessory`. Panels (the menu bar popover, the fly-in overlay) don't count.

Style: system materials and the `.sidebar` list style, grouped forms, SF Pro, the system accent colour. No heavy glass.

### First-launch welcome

A 560 × 520 window, shown once. The flag is `hasSeenWelcome` in Shotty's defaults; it's set when the window closes. Reopen it from **Help → Show Welcome…** or **Settings → Show Welcome Guide…**.

1. **Welcome**: what Shotty does: capture → Shotty sends → it's in your agent.
2. **Where should shots go?** "The app I was using" (recommended) or any installed target, plus Other App….
3. **Allow Shotty to paste**: why Accessibility is needed, a button that opens the right System Settings pane, and a live check of `AXIsProcessTrusted` (every second) that turns into a green check.
4. **Your screenshot folder**: the watched folder and whether Shotty can read it; whether the Floating Thumbnail is off, with **Make Screenshots Instant** and the ⇧⌘5 → Options tip.
5. **Shortcuts**: ⇧⌘3, ⇧⌘4, ⇧⌘5 and Shotty's ⌃⇧4.

Skip on every page but the last, Back and Continue, page dots, and **Get Started** on the last page, which opens the main window.

SwiftUI doesn't present windows at launch when the first scene is a `MenuBarExtra`, so the menu bar label opens the welcome window on first launch.

### The logo says hello

When the welcome window, the main window or the menu bar panel opens, the logo's eyes play a ~2 s sequence once: a blink (eyes squash to 10 % height and back in ~0.15 s), a glance left, right and up (the eyes move 8 % of the mark's side, ease-in-out), then settle back to centre. While the welcome or main window is open, the eyes blink once every 8–12 s.

- One timeline (`EyeAnimation.hello` in `Logo.swift`) drives both the SwiftUI logo and the menu bar icon.
- **Click to blink**: clicking the logo anywhere it appears (welcome, main window, panel) makes it blink once (~0.17 s); rapid clicks blink again. Allowed under Reduce Motion, since the eyes don't travel.
- **Menu bar icon**: plays the same sequence at launch and when the panel opens, by swapping freshly drawn 18 pt template images about 30 times a second for 2 s. No idle blinks there.
- **Reduce Motion**: no movement. The window logos fade in; the menu bar icon stays still.
- **Rive**: the same mark and motion are authored as a Rive project in `design/rive/shotty-logo` (state machine `Eyes`: `intro`, `idle`, a `hello` trigger and a `reduceMotion` input). It isn't in the app yet because the Rive workspace's plan adds the Rive splash screen to published files. Once it can publish without it, the `.riv` goes in `Resources/` and is shown with RiveRuntime, with this SwiftUI animation kept for Reduce Motion and load failures.

### Screenshot helpers

`Shotty --demo-app` runs the normal app with sample captures. It doesn't watch, save history or send. `--open-main`, `--section <home|history|targets|settings>` and `--welcome-page <0–4>` open a given view. `--demo --snapshot <dir>` now also writes `menubar-icon.png` and `logo-animation-frames.png`.

## Out of scope

- A release. v0.5.0 is set in `Info.plist` but not published.
- Signing changes (spec 0006).
- Changing what counts as a target, or how sending works.

## Test plan

- `defaults delete com.remidiy.shotty hasSeenWelcome`, launch: the welcome opens and Shotty appears in the Dock. Skip closes it; it doesn't come back on the next launch.
- Help → Show Welcome… reopens it. Back/Continue move between pages.
- Page 3 with Accessibility off: the button opens Privacy & Security → Accessibility; turning Shotty on shows the green check within a second.
- Page 2: picking an app turns off "app I was using" and pins it; the menu bar panel shows the same.
- Open Shotty from the panel: the main window opens, Dock icon appears. Close it: the Dock icon goes away and the menu bar icon stays.
- History: drag a capture into Finder or a chat app; ↻ sends it again; search filters.
- Targets: change a paste mode; it shows in the panel. Use pins an app.
- Menu bar icon is the rounded square with eyes; turning Shotty off shows the outline.
- `scripts/build-app.sh`: the Dock icon is the website mark.
- Opening the welcome window, the main window and the menu bar panel each plays the eye animation once; with Reduce Motion on, the logo only fades in.

Screenshots: [assets/screenshots/v0.5.0](../../assets/screenshots/v0.5.0).
