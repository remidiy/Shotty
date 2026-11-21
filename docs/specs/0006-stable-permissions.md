# Spec 0006: Permissions that stick

Status: Implemented in v0.4.1 · 21 Nov 2026

## Problem

Shotty kept asking for privacy permissions the user had already granted.

**Root cause.** Builds were signed ad hoc. An ad-hoc signature's designated requirement is the exact code hash (`cdhash H"…"`), and macOS stores Accessibility, Screen Recording and Desktop-folder grants against that requirement. Every rebuild and every release has a new hash, so macOS treated each one as a new app and the old grants silently stopped applying. On top of that, `Sender` called the Accessibility prompt on *every* failed send, so a stale grant turned into a prompt per screenshot.

## Behaviour

### Stable identity

- `scripts/setup-signing.sh` creates a self-signed code-signing certificate, "Shotty Local Signing", in the login keychain (one time).
- `scripts/build-app.sh` signs with, in order: `$SIGN_ID`, the local certificate if present, else ad hoc (with a warning). It always sets the identifier `com.remidiy.shotty`.
- The designated requirement becomes `identifier "com.remidiy.shotty" and certificate leaf = H"…"`, which stays the same across rebuilds and versions, so grants persist.
- `scripts/release.sh` refuses to publish an ad-hoc build.
- `scripts/install.sh` installs to `/Applications/Shotty.app` and restarts it, so the app always runs from one place.

### No nagging

- Permission checks are silent (`AXIsProcessTrusted`, `CGPreflightScreenCaptureAccess`).
- The system prompt is shown at most once per launch. After that, buttons open the exact System Settings pane.
- A failed send because Accessibility is off shows a status message, not a dialog.
- Settings shows Accessibility and Screen Recording status, and warns when the running copy is ad-hoc signed.

### One-time cleanup

Grants recorded for old ad-hoc builds don't apply to the new signature. Reset them once, then allow Shotty again:

```bash
tccutil reset Accessibility com.remidiy.shotty
tccutil reset ScreenCapture com.remidiy.shotty
```

## Out of scope

- Apple Developer ID signing and notarization (needs a paid account; see docs/RELEASING.md). The self-signed certificate fixes permissions but not Gatekeeper's first-launch warning.

## Test plan

- Build twice with the local certificate: `codesign -dr -` shows the same requirement both times. *(Verified in a throwaway keychain.)*
- Grant Accessibility, rebuild, reinstall: no prompt, sends work.
- Revoke Accessibility: one prompt at most, then the banner's button opens System Settings.
