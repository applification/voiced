# Privacy Checklist

## Local Capture Data

- Voice, selection, and typed input use `CaptureItem` and `CaptureStore`.
- `~/Library/Application Support/Voiced/Captures.json` is the only capture database.
- Writes are atomic and corrupt input is preserved as a timestamped recovery file.
- Capture text, selected text, clipboard contents, window titles, source URLs, and transcript contents never appear in application logs.
- Temporary recording data is removed after transcription and cancellation.

## Network

Expected:

- WhisperKit/Hugging Face access only after the user explicitly chooses to download a model.

Not expected:

- telemetry, analytics, or crash-report uploads
- account or authentication traffic
- cloud transcription, capture upload, or remote storage
- automatic update checks unless a direct-update mechanism is added and documented separately

## Clipboard

- Copy is an explicit user action.
- Selection fallback snapshots the clipboard before Command-C.
- Insertion snapshots the clipboard before Command-V.
- Restoration is guarded by pasteboard change count and never overwrites a newer clipboard value.

## Verification

1. Search source, dependency configuration, Settings, docs, and website for telemetry vendors and diagnostics copy.
2. Exercise voice, selected-text, and typed capture without a network connection after the model is installed.
3. Confirm `Captures.json` survives relaunch and contains no unexpected fields.
4. Confirm application logs contain state/error metadata only, never captured content.
5. Confirm the Release signature contains no `com.apple.security.app-sandbox` entitlement and has Hardened Runtime flags.
