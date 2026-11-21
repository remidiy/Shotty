# Spec 0003: Send to the app you were using, and capture history

Status: Implemented in v0.3.0 · 21 Nov 2026

## Problem

1. Picking a destination app in the panel is an extra step. Most of the time the right destination is simply the app you were working in when you took the screenshot.
2. Captures disappear from view once sent. There is no record, and no easy way to reuse an older capture in another app.

## Behaviour

### Auto destination

- Shotty tracks the last *regular* app that became frontmost (`NSWorkspace.didActivateApplicationNotification`).
- Ignored: Shotty, Finder, the screenshot UI (`com.apple.screencaptureui`), Dock, Control Center, Notification Center, Spotlight, login window.
- The destination is decided when the capture happens (before the ⌃⇧4 selection UI, or when the file appears for ⇧⌘4/⇧⌘5), so opening the Shotty panel afterwards doesn't change it.
- Paste mode per app: known terminals (Terminal, iTerm, Ghostty, Warp, kitty, Alacritty, WezTerm, Hyper) default to *File path*, everything else to *Attachment*. A per-app override is remembered.
- "Always send to…" is still available from the ⋯ menu and Settings; choosing it turns auto off.
- The big app-tile grid is removed. The panel shows one "Sends To" row with the app icon, name, paste mode and the ⋯ menu.

### History

- Every capture is saved (newest first, max 300) to `~/Library/Application Support/Shotty/history.json` with file URL, date, destination and any error.
- The panel lists the whole history in a scrolling list with cached thumbnails.
- Drag a row into any app to drop the file. Double-click opens it. Hover shows *Send again* and *Show in Finder*.
- Context menu: Send to current app, Copy, Open, Show in Finder, Remove from History, Clear History.
- Rows whose file was moved or deleted are dimmed and say so.

## Out of scope

- Thumbnails for screen recordings (shown with a video glyph).
- Search and filtering in history.
- Syncing history across Macs.

## Test plan

- Work in Cursor, press ⌃⇧4, select: pasted into Cursor. Switch to Ghostty, ⇧⌘4: path pasted into Ghostty.
- Click the Desktop (Finder) then capture: goes to the previous real app.
- Quit and relaunch Shotty: history is still there.
- Drag a history row into Claude, Messages and Finder: the file is dropped.
- Delete a screenshot file: its row dims and reads "File moved or deleted".
