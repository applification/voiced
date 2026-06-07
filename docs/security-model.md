# Security Model

Voiced is a local macOS dictation utility. Its main security boundary is the local user session: audio is recorded locally, transcribed locally, and emitted either to the clipboard or into the focused app.

## Required Privileges

Voiced has two distribution profiles:

- Direct distribution remains Developer ID signed, hardened, notarized, and intentionally unsandboxed.
- App Store distribution uses the sandboxed `AppStore` configuration and `Config/Voiced-AppStore.entitlements`.

Voiced needs to:

- listen for a global push-to-talk hotkey
- listen for Escape to cancel an active capture
- record microphone audio while push-to-talk is held
- send Cmd+V to the focused app when paste output is enabled

Microphone access is protected by macOS TCC and, in the App Store build, the `com.apple.security.device.audio-input` entitlement. Synthetic paste requires Accessibility permission. The sandboxed App Store build uses an `NSEvent` global monitor fallback for push-to-talk because `CGEvent.tapCreate` is not viable in the sandbox.

## Compensating Controls

- Direct-distribution releases should be Developer ID signed, use Hardened Runtime, and be notarized before public distribution.
- App Store builds should remain sandboxed and limited to audio input plus outbound network access for explicit model downloads.
- The app has no cloud transcription path.
- Audio files are temporary and are deleted after transcription, cancellation, and error paths.
- Transcript text is not logged and is not persisted to disk.
- The last transcript recovery value is memory-only.
- Model downloads are explicit and user initiated. Onboarding lets the user choose a model and discloses the selected model size before the first download.
- Downloaded model files are verified against pinned SHA-256 manifests before WhisperKit loads them.
- The hotkey layer ignores non-Escape key-down events and does not forward them to the coordinator.
- Copy-only output mode is available for users who do not want Voiced to send synthetic keystrokes.

## Known Tradeoffs

Paste mode temporarily writes the transcript to the system clipboard and sends Cmd+V using Accessibility permission. To preserve user experience, Voiced snapshots the existing pasteboard in memory and restores it after paste when possible. This avoids clobbering the user's clipboard, but means Voiced briefly handles the previous clipboard contents in memory.

The direct distribution build is intentionally unsandboxed, so any vulnerability in the app or loaded runtime dependencies has more reach than it would in the App Store build. Keep dependencies pinned, keep model verification enabled, and treat release signing/notarization as mandatory for public direct-distribution builds.

The App Store build still relies on sensitive user-granted capabilities. Review notes and onboarding must clearly explain that Accessibility is used for explicit push-to-talk and optional Auto Paste, while Clipboard Only remains available without the paste permission path.
