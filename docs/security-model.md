# Security Model

Voiced is a local macOS dictation utility. Its main security boundary is the local user session: audio is recorded locally, transcribed locally, and emitted either to the clipboard or into the focused app.

## Required Privileges

Voiced is intentionally unsandboxed. App Sandbox is not a good fit for the current product behavior because Voiced needs to:

- listen for a global push-to-talk hotkey
- listen for Escape to cancel an active capture
- record microphone audio while push-to-talk is held
- send Cmd+V to the focused app when paste output is enabled

Microphone access is protected by macOS TCC and the `com.apple.security.device.audio-input` entitlement. Synthetic paste requires Accessibility permission. Some systems may also require Input Monitoring for the global event tap.

## Compensating Controls

- Releases should be Developer ID signed, use Hardened Runtime, and be notarized before public distribution.
- The app has no cloud transcription path.
- Audio files are temporary and are deleted after transcription, cancellation, and error paths.
- Transcript text is not logged and is not persisted to disk.
- The last transcript recovery value is memory-only.
- Model downloads are explicit and user initiated.
- Downloaded model files are verified against pinned SHA-256 manifests before WhisperKit loads them.
- The hotkey layer ignores non-Escape key-down events and does not forward them to the coordinator.
- Copy-only output mode is available for users who do not want Voiced to send synthetic keystrokes.

## Known Tradeoffs

Paste mode temporarily writes the transcript to the system clipboard and sends Cmd+V using Accessibility permission. To preserve user experience, Voiced snapshots the existing pasteboard in memory and restores it after paste when possible. This avoids clobbering the user's clipboard, but means Voiced briefly handles the previous clipboard contents in memory.

Because Voiced is unsandboxed, any vulnerability in the app or loaded runtime dependencies has more reach than it would in a sandboxed app. Keep dependencies pinned, keep model verification enabled, and treat release signing/notarization as mandatory for public builds.
