# Security Model

Voiced is a local macOS dictation utility. Its main security boundary is the local user session: audio is recorded locally, transcribed locally, and emitted to the clipboard with an on-screen review/drag surface.

## Required Privileges

Voiced ships through Xcode Cloud and App Store Connect using the sandboxed
`AppStore` configuration and `Config/Voiced-AppStore.entitlements`.

Voiced needs to:

- listen for a global push-to-talk hotkey
- listen for Escape to cancel an active capture
- record microphone audio while push-to-talk is held

Microphone access is protected by macOS TCC and, in the App Store build, the `com.apple.security.device.audio-input` entitlement. Accessibility or Input Monitoring may be required by macOS for global push-to-talk while another app is focused. The sandboxed App Store build uses an `NSEvent` global monitor fallback for push-to-talk because `CGEvent.tapCreate` is not viable in the sandbox.

## Compensating Controls

- App Store builds should remain sandboxed and limited to audio input plus outbound network access for explicit model downloads.
- The app has no cloud transcription path.
- Audio files are temporary and are deleted after transcription, cancellation, and error paths.
- Transcript text is not logged and is not persisted to disk.
- The last transcript recovery value is memory-only.
- Model downloads are explicit and user initiated. Onboarding lets the user choose a model and discloses the selected model size before the first download.
- Downloaded model files are verified against pinned SHA-256 manifests before WhisperKit loads them.
- The hotkey layer ignores non-Escape key-down events and does not forward them to the coordinator.
- Voiced does not send synthetic paste keystrokes. Completed transcripts are copied to the clipboard and can be reviewed or dragged from the floating interface.

## Known Tradeoffs

Voiced writes the completed transcript to the system clipboard. This can replace the user's previous clipboard contents, so the app avoids logging clipboard data and treats clipboard contents as sensitive local-only data.

The App Store build still relies on sensitive user-granted capabilities. Review notes and onboarding must clearly explain that any Accessibility or Input Monitoring access is for explicit push-to-talk detection, not for automatic paste or arbitrary keystroke capture.
