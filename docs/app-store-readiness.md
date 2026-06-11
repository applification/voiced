# App Store Readiness

Voiced ships through Xcode Cloud and App Store Connect using the `AppStore`
Xcode configuration and `Config/Voiced-AppStore.entitlements`. It is sandboxed
and has a runtime path for global push-to-talk and model storage that is
compatible with App Store distribution.

## Current App Store Entitlements

- `com.apple.security.app-sandbox`
- `com.apple.security.device.audio-input`
- `com.apple.security.network.client`

The network entitlement is required for explicit WhisperKit model downloads. On first run, onboarding lets the user choose a model and discloses the approximate size before starting. Local transcription does not upload audio or transcript text.

## Build

Regenerate the Xcode project after changing `project.yml`:

```sh
xcodegen generate
```

Build the sandboxed App Store configuration:

```sh
xcodebuild \
  -project Voiced.xcodeproj \
  -scheme Voiced \
  -configuration AppStore \
  -destination "generic/platform=macOS" \
  build
```

Archive and upload are handled by Xcode Cloud.

## Runtime Compatibility Checks

Before submitting, verify the sandboxed build can still:

- request and receive Microphone permission
- download the selected model after explicit approval in onboarding
- verify model byte counts and SHA-256 integrity before loading
- reload the downloaded model after relaunch while offline
- receive global push-to-talk via the sandbox-compatible `NSEvent` fallback
- cancel active capture with Escape
- copy transcript text to the pasteboard
- show completed transcript text in the review/drag interface

## Global Push-To-Talk Proof

The App Store sandbox build cannot rely on `CGEvent.tapCreate`: local testing showed both `cgSessionEventTap` and `cghidEventTap` fail under the sandbox.

The `NSEvent` global monitor fallback can still receive the configured right-side modifier key after the app is granted the required privacy permissions. On 2026-06-07, the sandboxed `AppStore` build proved this path with Right Command:

- `NSEvent global modifier keyCode: 54 ... cgFlags: 1048576`
- coordinator received `flagsChanged keyCode=54`
- `handleKeyDown()` ran and recording started
- key release produced `handleKeyUp()`
- recording stopped and transcription began

This keeps global push-to-talk viable for App Store distribution. Review notes should clearly explain why Voiced asks for Accessibility or Input Monitoring: it needs to detect the user's explicit push-to-talk key while another app is focused. Voiced does not use that consent to send paste keystrokes.

## Model Download Proof

The App Store build stores WhisperKit model files inside the app sandbox:

```text
~/Library/Containers/net.applification.voiced/Data/Documents/huggingface/models/argmaxinc/whisperkit-coreml
```

Onboarding offers Tiny, Base, Small, and Large v3 before first use. It shows each model's approximate download size and waits for the user to press the selected model's download button before network access begins. Downloaded files are checked against pinned manifests before WhisperKit loads them.

The same model choices remain available later from Settings > Models.

Settings > Models includes visible attribution for WhisperKit and OpenAI Whisper. The repository also includes `THIRD_PARTY_NOTICES.md` with MIT license notices for the WhisperKit dependency and OpenAI Whisper model lineage.

## Clipboard And Review Proof

Current builds copy completed transcripts to the clipboard and show them in the floating review surface. Users can paste manually or drag the transcript into another app.

To verify the current output path:

1. Launch the `AppStore` build from `build-appstore/Build/Products/AppStore/Voiced.app`.
2. Complete onboarding: choose and download a model, then allow Microphone access.
3. Grant any requested push-to-talk privacy permission to that exact app identity.
4. Focus a blank TextEdit document or other editable text field.
5. Hold Right Command, speak a short phrase, and release.
6. Confirm the transcript is copied to the clipboard and appears in Voiced's review surface.
7. Paste manually or drag the transcript into the focused text field.

If push-to-talk permission is unavailable, Voiced should still avoid attempting synthetic paste.
