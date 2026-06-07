# App Store Readiness

Voiced's direct distribution build remains Developer ID signed, hardened, notarized, and intentionally unsandboxed.

The App Store proof build uses the `AppStore` Xcode configuration and `Config/Voiced-AppStore.entitlements`.

## Current App Store Entitlements

- `com.apple.security.app-sandbox`
- `com.apple.security.device.audio-input`
- `com.apple.security.network.client`

The network entitlement is required for explicit WhisperKit model downloads. Local transcription does not upload audio or transcript text.

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
- create the global push-to-talk listener, or degrade clearly if Input Monitoring is required
- cancel active capture with Escape
- copy transcript text to the pasteboard
- paste transcript text only after Accessibility permission is granted
- download the selected model after explicit approval
- verify model SHA-256 integrity
- reload the downloaded model after relaunch while offline

## Global Push-To-Talk Proof

The App Store sandbox build cannot rely on `CGEvent.tapCreate`: local testing showed both `cgSessionEventTap` and `cghidEventTap` fail under the sandbox.

The `NSEvent` global monitor fallback can still receive the configured right-side modifier key after the app is granted the required privacy permissions. On 2026-06-07, the sandboxed `AppStore` build proved this path with Right Command:

- `NSEvent global modifier keyCode: 54 ... cgFlags: 1048576`
- coordinator received `flagsChanged keyCode=54`
- `handleKeyDown()` ran and recording started
- key release produced `handleKeyUp()`
- recording stopped and transcription began

This keeps global push-to-talk viable for App Store distribution, but review notes should clearly explain why Voiced asks for Accessibility/Input Monitoring: it needs to detect the user's explicit push-to-talk key while another app is focused.

## Auto Paste Proof

Auto paste has been proven in the App Store sandbox build when the user grants Accessibility permission to the exact app identity.

On 2026-06-07, the sandboxed `AppStore` build at `build-appstore/Build/Products/AppStore/Voiced.app` was added to Accessibility settings. With TextEdit focused, `Test Paste Permission` succeeded and inserted `Voiced paste test` into the document.

The confirming logs were:

- `Test Paste Permission selected; accessibilityEnabled=true`
- `Prepared transcript paste; target=none frontmost=TextEdit accessibilityTrusted=true wroteTranscript=true ...`
- `Posting synthetic Cmd+V; target=frontmost frontmost=TextEdit`
- `Posted synthetic Cmd+V to frontmost`
- `Restored previous pasteboard after transcript paste`

To repeat the proof:

1. Launch the `AppStore` build from `build-appstore/Build/Products/AppStore/Voiced.app`.
2. Grant Accessibility permission to that exact app identity.
3. Focus a blank TextEdit document or other editable text field.
4. Choose `Test Paste Permission` from the Voiced menu.
5. Confirm `Voiced paste test` appears in the focused text field.

After one successful transcription, the menu item `Paste Last Transcript` can repeat the same paste-path proof with real transcript text.

If `accessibilityTrusted=false`, Voiced is behaving correctly by leaving the transcript on the clipboard instead of attempting synthetic paste.
