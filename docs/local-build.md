# Local Development Build

Voiced is a directly distributed macOS app. Use a stable signed bundle path while testing Accessibility and Input Monitoring because macOS associates these grants with the app's identity and location.

## Build And Run

```sh
./script/build_and_run.sh
```

The script regenerates `Voiced.xcodeproj`, builds Debug by default, copies the app to `dist/Voiced.app`, signs it with the first available Apple Development identity, verifies the signature, registers the stable path, and launches it.

Choose a signing identity or build configuration explicitly:

```sh
VOICED_CODE_SIGN_IDENTITY="Apple Development: Your Name (TEAMID)" \
  ./script/build_and_run.sh install

VOICED_CONFIGURATION=Release ./script/build_and_run.sh --verify
```

## Permissions

Grant Microphone, Accessibility, and Input Monitoring from the onboarding flow, shelf, Settings, or menu bar. Quit and relaunch `dist/Voiced.app` after changing Input Monitoring if macOS requests it.

Do not reset TCC as part of normal testing. If the system has stale grants, reset only with explicit user approval and only for `net.applification.voiced`.

## Tests

```sh
xcodegen generate
xcodebuild \
  -project Voiced.xcodeproj \
  -scheme Voiced \
  -configuration Debug \
  -derivedDataPath build \
  test
```

## Logs

```sh
./script/build_and_run.sh --logs
```

Logs must never contain capture text, transcript text, selected text, clipboard contents, source URLs, application window titles, or other sensitive material.
