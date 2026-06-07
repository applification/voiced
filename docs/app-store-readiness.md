# App Store Readiness

Voiced's direct distribution build remains Developer ID signed, hardened, notarized, and intentionally unsandboxed.

The App Store build uses the `AppStore` Xcode configuration and `Config/Voiced-AppStore.entitlements`. It is sandboxed and has a separate runtime path for global push-to-talk and model storage.

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

Archive for App Store Connect:

```sh
./script/archive_app_store.sh
```

## Runtime Compatibility Checks

Before submitting, verify the sandboxed build can still:

- request and receive Microphone permission
- download the selected model after explicit approval in onboarding
- verify model byte counts and SHA-256 integrity before loading
- reload the downloaded model after relaunch while offline
- receive global push-to-talk via the sandbox-compatible `NSEvent` fallback
- cancel active capture with Escape
- copy transcript text to the pasteboard
- paste transcript text only after Accessibility permission is granted

## Global Push-To-Talk Proof

The App Store sandbox build cannot rely on `CGEvent.tapCreate`: local testing showed both `cgSessionEventTap` and `cghidEventTap` fail under the sandbox.

The `NSEvent` global monitor fallback can still receive the configured right-side modifier key after the app is granted the required privacy permissions. On 2026-06-07, the sandboxed `AppStore` build proved this path with Right Command:

- `NSEvent global modifier keyCode: 54 ... cgFlags: 1048576`
- coordinator received `flagsChanged keyCode=54`
- `handleKeyDown()` ran and recording started
- key release produced `handleKeyUp()`
- recording stopped and transcription began

This keeps global push-to-talk viable for App Store distribution. Review notes should clearly explain why Voiced asks for Accessibility: it needs to detect the user's explicit push-to-talk key while another app is focused, and Auto Paste uses the same consent to send `Cmd+V` after transcription.

## Model Download Proof

The App Store build stores WhisperKit model files inside the app sandbox:

```text
~/Library/Containers/net.applification.voiced/Data/Documents/huggingface/models/argmaxinc/whisperkit-coreml
```

Onboarding offers Tiny, Base, Small, and Large v3 before first use. It shows each model's approximate download size and waits for the user to press the selected model's download button before network access begins. Downloaded files are checked against pinned manifests before WhisperKit loads them.

The same model choices remain available later from Settings > Models.

Settings > Models includes visible attribution for WhisperKit and OpenAI Whisper. The repository also includes `THIRD_PARTY_NOTICES.md` with MIT license notices for the WhisperKit dependency and OpenAI Whisper model lineage.

## Auto Paste Proof

Auto paste has been proven in the App Store sandbox build when the user grants Accessibility permission to the exact app identity.

On 2026-06-07, the sandboxed `AppStore` build at `build-appstore/Build/Products/AppStore/Voiced.app` was added to Accessibility settings. With TextEdit focused, real dictated transcripts pasted into the document after release of the push-to-talk key.

The confirming logs were:

- `Prepared transcript paste; target=none frontmost=TextEdit accessibilityTrusted=true wroteTranscript=true ...`
- `Posting synthetic Cmd+V; target=frontmost frontmost=TextEdit`
- `Posted synthetic Cmd+V to frontmost`
- `Restored previous pasteboard after transcript paste`

To repeat the proof:

1. Launch the `AppStore` build from `build-appstore/Build/Products/AppStore/Voiced.app`.
2. Complete onboarding: choose and download a model, allow Microphone, and choose Auto Paste.
3. Grant Accessibility permission to that exact app identity when prompted by the Auto Paste instructions.
4. Focus a blank TextEdit document or other editable text field.
5. Hold Right Command, speak a short phrase, and release.
6. Confirm the transcript appears in the focused text field.

After one successful transcription, the menu item `Paste Last Transcript` can repeat the same paste-path proof with real transcript text.

If `accessibilityTrusted=false`, Voiced is behaving correctly by leaving the transcript on the clipboard instead of attempting synthetic paste.
