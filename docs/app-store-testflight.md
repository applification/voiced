# App Store TestFlight

## Review Risk: Accessibility And Auto Paste

Apple can accept macOS apps that request Accessibility permission, but it is reviewer-sensitive. Voiced must be submitted with clear review notes because paste mode intentionally writes the transcript to the pasteboard and sends `Cmd+V` to the user's focused app after explicit Accessibility consent.

Suggested review notes:

```text
Voiced is a local-only macOS dictation utility. It records only while the user holds the configured push-to-talk key, transcribes locally, and inserts the transcript into the currently focused text field.

On first run, Voiced lets the user choose a local transcription model and shows the approximate download size before starting. The download is handled by WhisperKit/Hugging Face, stored in the app sandbox container, and verified against pinned byte counts and SHA-256 hashes before loading. The same local model choices remain available later in Settings.

The app requests Accessibility permission only for two user-initiated features:
1. Detecting the explicit global push-to-talk key while another app is focused.
2. Sending Cmd+V to paste the completed transcript into the focused app when Paste mode is selected.

Voiced does not record arbitrary keystrokes, does not upload audio or transcript text, and offers Clipboard Only mode for users who do not want to grant Accessibility permission.

Suggested reviewer test:
1. Launch Voiced and complete onboarding.
2. Choose a model, press its download button, then allow Microphone access.
3. Choose either Auto Paste and grant Accessibility, or choose Clipboard Only.
4. Open TextEdit, hold Right Command, speak a short phrase, and release.
5. Confirm the transcript is pasted automatically in Auto Paste mode, or copied for manual paste in Clipboard Only mode.
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

The repository includes:

- `Config/ExportOptions-AppStoreConnect.plist`
- `script/archive_app_store.sh`
- `script/upload_testflight.sh`

Upload command:

```sh
./script/upload_testflight.sh
```

If you already have a fresh archive:

```sh
./script/upload_testflight.sh --skip-archive
```

The upload requires an Apple Developer account in Xcode or App Store Connect API authentication, an App Store Connect app record for `net.applification.voiced`, and App Store distribution signing for Apple Developer team `GY6Q9L4423`.

After upload, Apple processes the build before it appears under App Store Connect > Voiced > TestFlight.
