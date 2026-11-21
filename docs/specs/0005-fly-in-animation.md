# Spec 0005: Capture flies into the app

Status: Implemented in v0.4.0 · 21 Nov 2026

## Problem

Shotty assumes every screenshot is meant for an agent, but nothing on screen shows that. The capture vanishes and text appears in another app a moment later. The user wants to *see* the screenshot go into the app, like the loop on the install site, so it feels like one gesture.

## Feasibility

Yes, with public AppKit and Core Animation APIs and no extra permissions:

- A borderless, transparent, click-through overlay window (`NSPanel`, non-activating, `ignoresMouseEvents`) above all windows can draw the capture anywhere on screen without stealing focus or clicks.
- The target app's front window frame comes from `CGWindowListCopyWindowInfo` (bounds and owner PID only, which needs no Screen Recording permission).
- The motion is one `CAAnimationGroup` on a layer: GPU-driven and smooth at 120 Hz. It runs in parallel with the paste, so sends don't get slower.

## Behaviour

1. **Start.** The card appears where the capture was taken:
   - Full-screen captures (⇧⌘3) start as the whole screen.
   - Area or window captures start at their real size, anchored where the pointer was released (the selection's bottom-right corner), clamped to the screen.
   - "Send again" from History starts small at the pointer.
2. **Lift (0.12 s).** The card scales to 96 % with a soft shadow, like the macOS thumbnail.
3. **Fly (0.5 s).** It travels on a gentle arc to the lower-middle of the target app's front window (where chat inputs live). On the way it shrinks to a ~72 pt chip with rounded corners, and the ease accelerates into the window.
4. **Land (0.25 s).** The chip fades and scales into the window, and a soft ring in the accent colour ripples out at the landing point.
5. If the target app has no visible window (not running yet), it lands at the bottom-centre of the screen with the Dock.
6. **Reduce Motion** (System Settings → Accessibility → Display): the card just fades in place, with no travel.
7. Setting: **Settings → Sending → Animate captures into the app** (on by default).

The overlay never takes focus and is removed when the animation ends. Recordings use their first frame as the card image.

## Out of scope

- Knowing the exact on-screen selection rectangle for ⇧⌘4 (macOS doesn't expose it). The pointer heuristic is close for drag selections.
- Animating into a specific text field inside the target window.

## Test plan

- ⌃⇧4 a small area in the top-left while Claude is open on the right: the card arcs into Claude's window, then the paste appears.
- ⇧⌘3: the full screen shrinks into the target window.
- Target app not running: the card lands near the Dock, then the app launches and receives the paste.
- Turn on Reduce Motion: fade only.
- Turn off the setting: no overlay at all.
- Clicking and typing during the animation is never blocked.
