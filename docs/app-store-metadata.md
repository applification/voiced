# App Store Metadata

Source-of-truth draft for App Store Connect metadata. Use this manually for the first TestFlight/App Review pass, then adapt it for App Store Connect API automation once the listing stabilizes.

## App Identity

- App Store listing name: `Voiced Dictation`
- Bundle ID: `net.applification.voiced`
- SKU: `voiced-macos`
- Primary language: `English`
- Primary category: `Productivity`
- Secondary category: none for first submission
- License agreement: Apple Standard License Agreement
- Initial availability: United Kingdom, United States, Canada, Australia, New Zealand
- EU availability: defer until Applification has a publish-safe trader address

## Subtitle

```text
Fast local speech to text
```

## Promotional Text

```text
Push-to-talk dictation for Mac, with local transcription and simple clipboard or paste output.
```

## Description

```text
Voiced Dictation is a quiet Mac menu bar app for turning speech into text without sending your recordings or transcripts to a cloud transcription service.

Hold your push-to-talk key, speak, and release. Voiced transcribes locally on your Mac using WhisperKit and Core ML speech recognition models, then copies the result to your clipboard or, with Accessibility permission, pastes it into the app you were already using.

Voiced is designed for quick capture while writing, coding, messaging, taking notes, or filling in text fields across macOS.

Features:

- Push-to-talk recording from the menu bar
- Local speech transcription on your Mac
- Explicit local model download during onboarding
- Clipboard Only mode for manual paste
- Optional Auto Paste mode with Accessibility permission
- Model management in Settings
- No cloud transcription upload
- No transcript or audio storage after processing

On first launch, Voiced asks you to choose and download a local transcription model. The model download uses the network, but speech recognition runs locally after the model is available.
```

## Keywords

```text
dictation,speech to text,transcription,voice typing,whisper,local,productivity,notes,writing
```

## What's New

```text
Initial TestFlight beta for Voiced Dictation, including first-run onboarding, local model download, push-to-talk recording, Clipboard Only output, and optional Auto Paste with Accessibility permission.
```

## Support URL

```text
https://voiced.applification.net/support
```

## Marketing URL

```text
https://voiced.applification.net
```

## Privacy Policy URL

```text
https://voiced.applification.net/privacy
```

## Copyright

```text
© 2026 Applification Ltd
```

## App Review Notes

```text
Voiced Dictation is a local-only macOS dictation utility. It records only while the user holds the configured push-to-talk key, transcribes locally, and inserts the transcript into the currently focused text field.

On first run, Voiced lets the user choose a local transcription model and shows the approximate download size before starting. The download is handled by WhisperKit/Hugging Face, stored in the app sandbox container, and verified against pinned byte counts and SHA-256 hashes before loading. The same local model choices remain available later in Settings.

The app requests Accessibility permission only for two user-initiated features:
1. Detecting the explicit global push-to-talk key while another app is focused.
2. Sending Cmd+V to paste the completed transcript into the focused app when Auto Paste mode is selected.

Voiced does not record arbitrary keystrokes, does not upload audio or transcript text, and offers Clipboard Only mode for users who do not want to grant Accessibility permission.

Suggested reviewer test:
1. Launch Voiced and complete onboarding.
2. Choose a model, press its download button, then allow Microphone access.
3. Choose either Auto Paste and grant Accessibility, or choose Clipboard Only.
4. Open TextEdit, hold Right Command, speak a short phrase, and release.
5. Confirm the transcript is pasted automatically in Auto Paste mode, or copied for manual paste in Clipboard Only mode.
```

## TestFlight Beta Description

```text
Voiced Dictation is a Mac menu bar app for local push-to-talk speech transcription. This beta is focused on onboarding, local model download, microphone permission, push-to-talk capture, Clipboard Only output, and optional Auto Paste with Accessibility permission.
```

## What To Test

```text
Test first-run onboarding, local model download, microphone permission, push-to-talk dictation, Clipboard Only output, and Auto Paste with Accessibility permission. In Auto Paste mode, open TextEdit, hold Right Command, speak a short phrase, release, and confirm the transcript is pasted into the focused document.
```

## Beta App Review Notes

Use the same text as App Review Notes for the first external TestFlight submission.

## App Privacy Draft

Current first TestFlight build includes PostHog. Basic diagnostics are enabled by default when `POSTHOG_PROJECT_TOKEN` is present and can be turned off in Settings.

- Audio: not collected; recorded only while push-to-talk is held, processed locally, and deleted after transcription.
- Transcripts/text: not collected; produced locally, copied or pasted according to user choice, and not uploaded.
- Diagnostics: collected through PostHog when basic diagnostics are enabled. This can include crash/error diagnostics, app version, build number, macOS version, processor count, architecture, broad error categories, and event names such as app opened, recording started, recording cancelled, transcription succeeded, transcription failed, model load started, model load succeeded, model load failed, output failed, and permission prompt shown.
- Analytics: collected through PostHog when basic diagnostics are enabled. This is limited to basic usage and reliability signals and is configured without screen capture, screen view tracking, feature flag events, or person profiles.
- Clipboard: used transiently for output in Clipboard Only and Auto Paste modes; not collected.
- Network: used for explicit model downloads after user selection.

PostHog redaction blocks audio, transcript text, clipboard contents, file paths, target application names, and related path/text fields before events are sent.

## Screenshot Checklist

- First-run onboarding with model choice.
- Model download confirmation or progress.
- Menu bar status menu.
- Output mode choice showing Clipboard Only and Auto Paste.
- Settings > Models with attribution and model management.
- Dictation result appearing in TextEdit.

## API Automation Notes

Later automation can use the official App Store Connect API for app metadata, or fastlane `deliver` as a convenience wrapper. Keep this file as the human-readable canonical copy and generate API payloads from it rather than making App Store Connect the only source of truth.
