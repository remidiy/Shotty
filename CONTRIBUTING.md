# Contributing

Thanks for helping. Shotty is small on purpose: one job, done fast.

- Build: `swift build`, or `scripts/build-app.sh` for a runnable `dist/Shotty.app`.
- Preview the UI without sending anything: `dist/Shotty.app/Contents/MacOS/Shotty --demo`.
- Keep the UI native: system materials, standard controls, SF Symbols, Apple's Human Interface Guidelines.
- New target apps go in `Target.presets` (`Sources/Shotty/Targets.swift`) with their bundle id and paste mode.
- Open an issue before large changes. Small PRs with a screenshot of any UI change are easiest to review.
