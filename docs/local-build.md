# Voiced Local Build

Voiced is a local macOS menu bar app. For reliable Accessibility permissions, run a signed app bundle from a stable path.

## Build

Generate the Xcode project after changing `project.yml`:

```sh
xcodegen generate
```

Build and launch the debug product:

```sh
./script/build_and_run.sh run
```

Install the built app to `dist/Voiced.app` and launch it from that stable path:

```sh
./script/build_and_run.sh install-run
```

## Signing

Synthetic paste requires Accessibility permission. macOS TCC tracks that permission by app identity, so ad-hoc debug builds may not stay trusted.

Recommended local setup:

1. Sign in to Xcode with an Apple Developer account.
2. Select the `Voiced` target.
3. Set `Signing & Capabilities` to your team.
4. Build once.
5. Run `./script/build_and_run.sh install-run`.
6. In the Voiced menu, open Accessibility settings and enable Voiced.
7. Quit and relaunch `dist/Voiced.app`.

The telemetry log should show `accessibilityTrusted=true` before paste is attempted.

`script/build_and_run.sh` builds normally, copies the app to `dist/Voiced.app`, and auto-detects the first available `Apple Development` signing identity to sign that stable copy. To force a specific identity:

```sh
VOICED_CODE_SIGN_IDENTITY="Apple Development: Your Name (TEAMID)" ./script/build_and_run.sh install-run
```

## Permissions

Voiced needs:

- Microphone: record only while push-to-talk is held.
- Accessibility: post `Cmd+V` into the focused app for paste mode.

Input Monitoring may be needed on some systems for event taps. Voiced falls back to `NSEvent` monitors when event taps are unavailable.

## Reset Permissions

If macOS appears to trust the wrong copy of the app:

```sh
tccutil reset Accessibility net.applification.voiced
tccutil reset Microphone net.applification.voiced
```

Then rerun `./script/build_and_run.sh install-run` and grant permissions again.
