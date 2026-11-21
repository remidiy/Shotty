# Shotty logo (Rive)

The website mark with eyes that say hello, as a Rive project for the `rive` CLI.

- Artboard `Logo` (512 × 512): the gradient tile and an `Eyes` group (two capsules).
- State machine `Eyes` (default):
  - `intro` plays on load (2 s): blink, glance left, right, up, settle. Same timeline as `EyeAnimation.hello` in `Sources/Shotty/Logo.swift`.
  - then `idle`: a blink every 10 s, looping.
  - `hello` (trigger) replays the intro; `reduceMotion` (bool) holds the eyes still.

```bash
rive . --verify                                  # check
rive . --screenshot=out.png --advance=40         # a frame
rive . --publish                                 # writes build/shotty-logo.riv (needs `rive login`)
```

Not used by the app yet: the current Rive workspace's plan adds the Rive splash screen to published files. Once it publishes without it, copy the `.riv` to `Resources/` and show it with RiveRuntime; keep the SwiftUI animation as the Reduce Motion and load-failure fallback. See spec 0007.
