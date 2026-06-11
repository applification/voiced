# App Store TestFlight

## Review Risk: Global Push-To-Talk Permissions

Apple can accept macOS apps that request Accessibility or Input Monitoring permission, but these permissions are reviewer-sensitive. Voiced must be submitted with clear review notes because global push-to-talk needs to detect the user's explicit hotkey while another app is focused.

Suggested review notes:

```text
Voiced is a local-only macOS dictation utility. It records only while the user holds the configured push-to-talk key, transcribes locally, copies the completed transcript to the clipboard, and shows a review surface that can be dragged into another app.

On first run, Voiced lets the user choose a local transcription model and shows the approximate download size before starting. The download is handled by WhisperKit/Hugging Face, stored in the app sandbox container, and verified against pinned byte counts and SHA-256 hashes before loading. The same local model choices remain available later in Settings.

The app requests Accessibility or Input Monitoring permission only to detect the explicit global push-to-talk key while another app is focused.

Voiced does not record arbitrary keystrokes, does not send synthetic paste commands, and does not upload audio or transcript text.

Suggested reviewer test:
1. Launch Voiced and complete onboarding.
2. Choose a model, press its download button, then allow Microphone access.
3. Allow any requested push-to-talk privacy permission.
4. Open TextEdit, hold Right Command, speak a short phrase, and release.
5. Confirm the transcript is copied to the clipboard and appears in Voiced's review surface; paste or drag it into TextEdit.
```

This is not a guaranteed approval. It is a reasonable App Store argument because the app is sandboxed, the permission is user-granted, the behavior is core to the app, and the reviewer has a direct way to test it.

## Apple Review References

Refreshed on 2026-06-07:

- Apple documents App Sandbox as required for Mac App Store distribution: <https://developer.apple.com/documentation/security/app-sandbox>
- App Store Connect may ask for sandbox entitlement usage information, especially temporary exceptions. Voiced currently uses standard sandbox, audio input, and network client entitlements, not temporary exception entitlements: <https://developer.apple.com/help/app-store-connect/reference/app-sandbox-information/>
- App Review Guideline 2.1 requires complete, testable submissions. Review notes should include the onboarding steps and TextEdit verification flow above: <https://developer.apple.com/app-store/review/guidelines/>
- App Review Guideline 5.1 and Apple's privacy guidance require accurate privacy disclosure and purpose strings. Voiced's review notes and metadata should state that model downloads contact Hugging Face/WhisperKit, while audio and transcripts stay local: <https://developer.apple.com/app-store/user-privacy-and-data-use/>

## Clean-Slate Local Visual Test

Use the App Store run helper for local clean-slate testing:

```sh
./script/run_app_store.sh reset-run
```

The helper quits Voiced, resets Microphone and Accessibility TCC entries for `net.applification.voiced`, clears onboarding/output/model preferences, removes the sandboxed Hugging Face model cache, builds the `AppStore` configuration, and launches the sandboxed app.

If stale Voiced rows remain in System Settings > Privacy & Security > Accessibility, remove them manually with the minus button. macOS sometimes keeps separate rows for different build paths or code signatures until the user removes them.

## Upload To TestFlight

Xcode Cloud archives, signs, exports, and uploads distribution builds to App
Store Connect. Keep local validation focused on the clean-slate App Store run
helper above, then use the Xcode Cloud build result for TestFlight.

The App Store Connect app record uses bundle ID `net.applification.voiced` and
Apple Developer team `GY6Q9L4423`. After Xcode Cloud uploads a build, Apple
processes it before it appears under App Store Connect > Voiced > TestFlight.
