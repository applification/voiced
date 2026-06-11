# Voiced Local Development Build

Voiced is a local macOS menu bar app. This note is for development and
permission testing only; distribution builds are produced by Xcode Cloud and
delivered through App Store Connect.

For reliable macOS privacy permissions during local testing, run a signed app
bundle from a stable path.

## Build

Generate the Xcode project after changing `project.yml`:

```sh
xcodegen generate
```

Build and launch the debug product:

```sh
./script/build_and_run.sh run
```

To test analytics locally, pass the public PostHog project token at build time:

```sh
POSTHOG_PROJECT_TOKEN="phc_..." ./script/build_and_run.sh run
```

The token is embedded in the built app and is not a secret. Do not use PostHog
personal API keys or any other secret key here.

Install the built app to `dist/Voiced.app` and launch it from that stable path:

```sh
./script/build_and_run.sh install-run
```

## Signing

Global push-to-talk may require Accessibility or Input Monitoring permission. macOS TCC tracks those permissions by app identity, so ad-hoc debug builds may not stay trusted.

Recommended local setup:

1. Sign in to Xcode with an Apple Developer account.
2. Select the `Voiced` target.
3. Set `Signing & Capabilities` to your team.
4. Build once.
5. Run `./script/build_and_run.sh install-run`.
6. In the Voiced menu, open the relevant privacy settings and enable Voiced if prompted.
7. Quit and relaunch `dist/Voiced.app`.

The telemetry log should show the expected push-to-talk permission state before global capture is tested.

`script/build_and_run.sh` builds normally, copies the app to `dist/Voiced.app`, and auto-detects the first available `Apple Development` signing identity to sign that stable copy. To force a specific identity:

```sh
VOICED_CODE_SIGN_IDENTITY="Apple Development: Your Name (TEAMID)" ./script/build_and_run.sh install-run
```

## Permissions

Voiced needs:

- Microphone: record only while push-to-talk is held.
- Accessibility/Input Monitoring: detect the explicit push-to-talk key while another app is focused, where macOS requires it.

Input Monitoring may be needed on some systems for event taps. Voiced falls back to `NSEvent` monitors when event taps are unavailable.

## Reset Permissions

If macOS appears to trust the wrong copy of the app:

```sh
tccutil reset Accessibility net.applification.voiced
tccutil reset Microphone net.applification.voiced
```

Then rerun `./script/build_and_run.sh install-run` and grant permissions again.
