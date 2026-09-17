# Security Model

Voiced is a directly distributed, local-first macOS utility. It is intentionally unsandboxed because its core job requires global modifier gestures, Accessibility-selected text, source-application tracking, and controlled insertion into other applications. Release builds retain Hardened Runtime.

## Privileges

- Microphone: records only while Command + Shift + Space or Command + Option + Shift + Space is held.
- Input Monitoring: listens for Command + Shift + Space, Command + Option + Shift + Space, double Shift, Option-Space, and Escape through a CGEvent tap. The dictation Space key events are consumed so the shortcut does not also reach the focused app; other events pass through unchanged. An `NSEvent` monitor is the fallback when the tap cannot be created.
- Accessibility: reads selection, focused field, value and caret bounds for user-triggered capture/insertion. Preview uses Command-V once. Experimental Direct mode uses writable text/value attributes and checks focus, complete expected text and selection before every update; it stops writing on any mismatch.

Voiced exposes the permission state and recovery actions in onboarding, the shelf, Settings, and the menu bar. It does not reset TCC databases or change privacy settings.

## Local Data

Captures are stored at `~/Library/Application Support/Voiced/Captures.json` in a readable, versioned JSON document. Writes use Foundation's atomic file replacement. A corrupt document is copied to `Captures.corrupt-<timestamp>.json` before Voiced begins with an empty in-memory shelf.

Each item stores text, an optional original transcript after automatic cleanup, UUID, source type, Inbox/Done status, timestamps, and the source application name/bundle identifier when available. Legacy Next items migrate to Inbox. A source URL is stored only when Accessibility exposes an HTTP, HTTPS, or file URL.

Whisper models remain under Voiced’s Application Support directory and use pinned byte counts and SHA-256 hashes. Parakeet v2 and its CTC vocabulary model use FluidAudio’s shared Application Support model cache and Core ML validation. Live audio is held in memory and released after transcription/cancellation. Vocabulary is stored in local preferences; neither audio nor vocabulary is uploaded.

## Clipboard And Insertion

Selection-copy fallback and automatic insertion snapshot every available pasteboard item and type. Restoration occurs only while the pasteboard change count still matches the transaction's expected value. If another application or the user changes the clipboard, Voiced leaves the newer clipboard untouched.

Insertion activates the remembered source/current destination application, writes the requested capture temporarily, posts Command-V, and marks the capture Done after success. Without Accessibility permission it reports a recoverable error and does not silently attempt insertion.

## Privacy Controls

- No account, analytics, telemetry, crash reporting service, cloud storage, or application server.
- No cloud transcription.
- Voiced’s own OSLog diagnostics exclude audio, captures, transcripts, clipboard contents, window titles, selected text and source URLs. FluidAudio 0.15.7 prints decoded content to stderr in Debug; the adapter redirects process stderr to `/dev/null` before loading it. This also suppresses other process console diagnostics. FluidAudio Release OSLog strings use private interpolation.
- Network access only for explicit model downloads and any future direct-update mechanism that is separately documented.

The lack of App Sandbox increases the importance of code signing, Hardened Runtime, notarization, and narrow permission-sensitive services. See `docs/direct-distribution.md`.
