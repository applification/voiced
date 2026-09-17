<p align="center">
  <img src="Config/Assets.xcassets/VoicedHeaderIcon.imageset/voiced-icon.png" alt="Voiced logo" width="128">
</p>

# Voiced

Voiced is a local capture layer for macOS: speak it, select it, or type it, then paste it, queue it, or keep it. It combines local Parakeet v2 English and Whisper transcription with selected-text capture, typed prompts, a native review surface, and a persistent shelf.

## Capture

- Hold **Control + Shift + Space** to see a live transcript beside the caret (or mouse pointer). Release to finish and insert into the same field. Successful insertion moves the capture to Done.
- Add **Option** to that shortcut to save to Inbox instead. Escape cancels.
- Press Shift twice to capture the current selection.
- Press Option-Space to open or close the shelf.
- Type directly into the shelf to add a capture.
- Edit, search, preview transcript refinements, export reminders, copy, drag, move, or remove captures in the shelf detail pane. Shelf refinements can be reviewed before applying. Optional automatic cleanup preserves an original transcript that can be restored.
- Inbox and Done persist across launches. Removed captures offer an immediate Undo action.
- Automatic insertion restores the previous clipboard when it has not changed during the operation.

Voice, selection, and typed input all produce the same `CaptureItem`. Captures are stored as readable JSON at:

```text
~/Library/Application Support/Voiced/Captures.json
```

Writes are atomic. If the file is corrupt, Voiced preserves a timestamped recovery copy before starting an empty shelf.

## Personal dictation settings

- **Models:** choose Parakeet v2 English (FluidAudio 0.15.7) or an existing Whisper model. The Parakeet download includes a CTC vocabulary model. Model weights use Core ML locally; no NVIDIA GPU is needed. Existing model selections are preserved.
- **Vocabulary:** add, edit or remove names and phrases, one per line, then Save. The list persists and applies from the next dictation. Whisper receives bounded prompt tokens; Parakeet uses acoustic vocabulary rescoring for final recognition.
- **General → Live dictation:** Preview is the default. Direct (experimental) writes drafts into writable Accessibility text fields. It replaces only the dictated span on finalization. If text, caret or focus changes, Voiced preserves the field and leaves the completed transcript in the panel and Inbox for copying. Rich editors may use Preview.
- **AI → Clean up after dictation:** optional local removal of fillers before insertion. If unavailable or processing fails, use raw recognition. The shelf retains the original and offers **Restore original transcript**.

Parakeet refreshes a provisional transcript from the growing recording, then decodes the complete recording with vocabulary on release. Preview cadence includes inference time, so longer recordings update less frequently. The final text can differ from the draft. Parakeet models live under `~/Library/Application Support/FluidAudio/Models/`; Whisper models remain under `~/Library/Application Support/Voiced/huggingface/`. Deleting Parakeet removes its speech model; the shared vocabulary model remains cached.

## Privacy

Voiced has no account, telemetry, analytics, cloud storage, server, or cloud transcription path. Capture text, transcript text, clipboard contents, application window titles, and other sensitive material are not logged.

Network access is used for approved local speech-model downloads. Live audio is held in memory and released after transcription or cancellation. Whisper downloads use pinned SHA-256 manifests; FluidAudio downloads and loads the Parakeet Core ML bundles. No audio or transcript is uploaded.

## Requirements

- macOS 14 or newer; Apple Silicon for Parakeet (including M1 Pro and M1 Max with 32 GB RAM).
- Optional automatic cleanup uses Apple Intelligence on macOS 26 or newer, when available.
- Microphone access for voice capture.
- Accessibility for selected-text access and automatic insertion.
- Input Monitoring for global modifier gestures and shortcuts.
- Xcode with Swift 6 support and XcodeGen for development.

The onboarding flow, shelf, settings, and menu all expose recoverable permission actions. Voiced never resets TCC or changes privacy settings itself.

## Development

`project.yml` is the source of truth for the generated Xcode project.

```sh
xcodegen generate
xcodebuild -project Voiced.xcodeproj -scheme Voiced -configuration Debug build
xcodebuild -project Voiced.xcodeproj -scheme Voiced -configuration Release build
xcodebuild -project Voiced.xcodeproj -scheme Voiced -configuration Debug test
```

Build, install to the stable `dist/Voiced.app` path, sign with a local Apple Development identity when available, and launch:

```sh
./script/build_and_run.sh
```

See [docs/local-build.md](docs/local-build.md) for local permission testing and [docs/manual-smoke-checklist.md](docs/manual-smoke-checklist.md) for end-to-end verification.

## Direct Distribution

The Mac App Store is not a supported distribution target. Release builds are unsandboxed and use Hardened Runtime so global capture, Accessibility selection, and insertion can work reliably.

Publish a signed, notarized GitHub Release from the local Mac:

```sh
./script/publish_release.sh
```

The publisher validates the version and checkout, runs tests, uses credentials stored in the local Keychain, signs and notarizes the DMG, creates the version tag when needed, and uploads the DMG and checksum. No GitHub Actions signing secrets are required. See [docs/direct-distribution.md](docs/direct-distribution.md).

## Repository Layout

- `Voiced/Capture/`: capture model, persistence, source application tracking, and selected-text capture.
- `Voiced/Output/`: clipboard transactions and automatic insertion.
- `Voiced/Permissions/`: global event tap, gesture recognition, and permission state.
- `Voiced/UI/`: shelf, generic review surface, settings, onboarding, and menu bar UI.
- `Voiced/Audio/` and `Voiced/Models/`: Parakeet/Whisper transcription, vocabulary hints and model management.
- `VoicedTests/`: persistence, recovery, gesture, and clipboard-safety tests.
- `script/`: local run and direct Release packaging workflows.
- `website/`: public product site.

## License

Voiced is released under the [MIT License](LICENSE).
