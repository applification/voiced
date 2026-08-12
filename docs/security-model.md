# Security Model

Voiced is a directly distributed, local-first macOS utility. It is intentionally unsandboxed because its core job requires global modifier gestures, Accessibility-selected text, source-application tracking, and controlled insertion into other applications. Release builds retain Hardened Runtime.

## Privileges

- Microphone: records only while Right Command or Shift + Right Command is held.
- Input Monitoring: listens for Right Command, Shift + Right Command, double Shift, Option-Space, and Escape through a listen-only CGEvent tap. An `NSEvent` monitor is the fallback when the tap cannot be created.
- Accessibility: reads the selected-text attribute when an application exposes it and posts an explicit Command-C or Command-V only for user-triggered capture/insertion operations.

Voiced exposes the permission state and recovery actions in onboarding, the shelf, Settings, and the menu bar. It does not reset TCC databases or change privacy settings.

## Local Data

Captures are stored at `~/Library/Application Support/Voiced/Captures.json` in a readable, versioned JSON document. Writes use Foundation's atomic file replacement. A corrupt document is copied to `Captures.corrupt-<timestamp>.json` before Voiced begins with an empty in-memory shelf.

Each item stores text, UUID, source type, Inbox/Next/Done status, timestamps, and the source application name/bundle identifier when available. A source URL is stored only when Accessibility exposes an HTTP, HTTPS, or file URL.

Downloaded Whisper models remain in Application Support and are verified against pinned byte counts and SHA-256 hashes before loading. Temporary audio is deleted by the transcription lifecycle.

## Clipboard And Insertion

Selection-copy fallback and automatic insertion snapshot every available pasteboard item and type. Restoration occurs only while the pasteboard change count still matches the transaction's expected value. If another application or the user changes the clipboard, Voiced leaves the newer clipboard untouched.

Insertion activates the remembered source/current destination application, writes the requested capture temporarily, posts Command-V, and marks the capture Done after success. Without Accessibility permission it reports a recoverable error and does not silently attempt insertion.

## Privacy Controls

- No account, analytics, telemetry, crash reporting service, cloud storage, or application server.
- No cloud transcription.
- No logs containing audio, captures, transcripts, clipboard contents, window titles, selected text, or source URLs.
- Network access only for explicit model downloads and any future direct-update mechanism that is separately documented.

The lack of App Sandbox increases the importance of code signing, Hardened Runtime, notarization, and narrow permission-sensitive services. See `docs/direct-distribution.md`.
