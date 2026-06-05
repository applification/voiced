# Voiced Implementation Plan

## Goal

Build a fresh, private, macOS-only audio transcription app called Voiced.

The app should:

- Run locally on macOS.
- Use local transcription only.
- Record only during push-to-talk.
- Insert or copy text into the focused app.
- Keep a temporary last-capture recovery buffer.
- Avoid transcript history, notes, media libraries, AI cleanup, context capture, and cloud features.
- Be small enough that we can audit and understand it.

## Direction

Build a new Swift/Xcode app from scratch.

Use Pindrop as implementation inspiration and a reference point, not as a source base to fork or strip. We can inspect Pindrop to learn how it handles macOS-specific problems, but Voiced should have its own minimal project structure and only the features needed for audio transcription.

## Why Native Swift

The app is macOS-only, so native Swift is a better fit than Electron:

- Native microphone APIs.
- Native menu-bar lifecycle.
- Native global hotkey/event-tap APIs.
- Native pasteboard and keyboard event APIs.
- Native Accessibility/Input Monitoring permission checks.
- Native signing, entitlements, and Xcode build flow.
- WhisperKit gives a Swift/Core ML local transcription path.

## Non-Goals

Voiced should not include:

- Transcript history/library.
- Notes.
- Media ingestion beyond microphone push-to-talk.
- AI cleanup/enhancement.
- OpenAI/OpenRouter/Anthropic/custom endpoint configuration.
- API key storage.
- Prompt presets.
- Context capture.
- Workspace file indexing.
- Mention/path rewriting.
- Transcript editing workflows.
- Automatic update checks.
- Background network services.

## Keep

The product surface should stay intentionally small:

- Menu-bar app.
- Push-to-talk hotkey.
- Microphone selection if needed.
- Local WhisperKit transcription.
- Text insertion or copy mode.
- Small floating recording/transcribing indicator.
- Minimal settings.
- Permission status/help.
- Last capture recovery.
- Basic diagnostics with sensitive content redacted.

## Privacy Defaults

Default behavior:

- No cloud AI.
- No automatic update checks.
- No transcript history.
- No retained audio files.
- No model download without explicit confirmation.
- No network access after model download.
- Temporary last transcript stored in memory only.
- Clipboard insertion only unless direct insertion is explicitly enabled.
- Diagnostic logs must not include full transcript text or audio content.

## Last Capture Recovery

Keep a minimal recovery mechanism without turning it into a history feature:

- Store only the most recent transcript in memory.
- Expose "Copy Last Transcript" from the menu bar or diagnostics popover.
- Use it when paste/direct insertion fails or the user wants to retry.
- Do not persist it to disk by default.
- Clear it on app quit.
- Optionally auto-clear it after 10-30 minutes.

This is explicitly not a searchable transcript history, notes workflow, timeline, export feature, or stored audit log.

## Context Boundary

Do not implement context capture.

Allowed minimal target-app tracking:

- Remember which app/window was active before recording.
- Use that to return focus or insert text.
- Use focused display/window position to place the overlay.

Out of scope:

- Reading selected text.
- Reading document contents.
- Capturing clipboard contents except temporary pasteboard preservation.
- Indexing workspace files.
- App-specific semantic context.
- Prompt routing.
- Sending surrounding context to any AI service.

## Proposed Architecture

```text
VoicedApp
  ├─ App lifecycle
  ├─ Status bar/menu controller
  ├─ Settings store
  ├─ Permission manager
  ├─ Hotkey manager
  ├─ Audio recorder
  ├─ Transcription service
  │   └─ WhisperKit engine
  ├─ Output manager
  │   ├─ clipboard-preserving paste
  │   └─ optional direct insertion later
  ├─ Last capture store
  ├─ Floating indicator
  └─ Diagnostics logger
```

## Key Implementation Choices

### App Type

Use a SwiftUI macOS menu-bar app. Keep the dock hidden unless debugging requires a normal app window.

### Transcription

Use WhisperKit first. It is native Swift, Core ML-oriented, and better aligned with macOS-only goals than driving `whisper.cpp` from a desktop shell.

Keep `whisper.cpp` as a fallback idea only if WhisperKit performance, model quality, or model management disappoints.

### Audio

Use `AVAudioEngine` or another native audio capture path.

Record only while push-to-talk is active. Convert audio to the format expected by WhisperKit. Delete temporary audio immediately after transcription unless debug mode explicitly retains it.

### Hotkey

Use macOS-native global event handling:

- Start with a simple global hotkey.
- Support push-to-talk press/release.
- Expect Accessibility/Input Monitoring permissions depending on implementation.

Pindrop can be used as a reference for event-tap behavior.

### Output

Start with clipboard-preserving paste:

1. Save current pasteboard contents as well as practical.
2. Write transcript.
3. Send `Cmd+V`.
4. Restore prior pasteboard contents after a short delay.

Add direct insertion later only if clipboard paste is unreliable or annoying.

### Overlay

Use a small floating `NSPanel` or SwiftUI-backed window:

- Non-activating.
- Always on top.
- Recording/transcribing/error states.
- Minimal audio level/progress signal.

## Model Management

Keep this explicit and boring:

- No automatic model download without user confirmation.
- Store models under the app support directory.
- Show model name, size, and local path.
- Support deleting/re-downloading models.
- Verify downloads where practical.

Initial model target:

- Start with WhisperKit's recommended small/fast model for local dictation.
- Benchmark quality and latency before settling on default.

## Milestones

### Milestone 0: Reference Audit

Purpose: learn from Pindrop without inheriting its product surface.

Tasks:

- Inspect Pindrop's hotkey manager, audio recorder, WhisperKit integration, output manager, permission manager, and floating indicator.
- Record useful implementation notes.
- Avoid copying source code unless deliberately attributed and reviewed.

Exit criteria:

- We understand the native macOS patterns needed for Voiced.

### Milestone 1: Fresh Xcode App

Purpose: create the minimal native app foundation.

Tasks:

- Create a new Swift/Xcode macOS project.
- Configure menu-bar behavior.
- Add app name and bundle identifier.
- Add microphone permission string.
- Add basic settings storage.
- Add simple status menu.

Exit criteria:

- Voiced launches as a minimal menu-bar app.

### Milestone 2: Local Transcription Spike

Purpose: prove WhisperKit works locally in our own app.

Tasks:

- Add WhisperKit dependency.
- Download/select one local model explicitly.
- Record or load a short test audio file.
- Transcribe locally.
- Display/copy result.

Exit criteria:

- Local audio can be transcribed without cloud services.

### Milestone 3: Push-To-Talk Loop

Purpose: build the core user workflow.

Tasks:

- Add global hotkey press/release handling.
- Record mic audio only while held.
- Stop on release.
- Transcribe.
- Paste/copy result.
- Store last transcript in memory.

Exit criteria:

- Hold key, speak, release, text appears in the focused app.

### Milestone 4: Privacy And Recovery

Purpose: make the core loop trustworthy.

Tasks:

- Delete temp audio after transcription.
- Redact transcript/audio content from logs.
- Add "Copy Last Transcript".
- Add optional last-capture auto-clear.
- Confirm app works offline after model download.
- Confirm no unexpected network calls.

Exit criteria:

- App behavior matches local-only privacy defaults.

### Milestone 5: Daily-Driver Polish

Purpose: make it comfortable enough to replace SuperWhispr.

Tasks:

- Add floating recording/transcribing indicator.
- Add permission status/recovery UI.
- Add microphone/model settings.
- Add launch-at-login if desired.
- Improve pasteboard preservation.
- Tune default model and hotkey.

Exit criteria:

- App is reliable enough for daily use.

### Milestone 6: Local Build Packaging

Purpose: make a stable local app bundle.

Tasks:

- Configure signing for local development.
- Add required entitlements.
- Test permissions with a built app bundle.
- Document how to rebuild/install locally.

Exit criteria:

- Voiced can be built and run locally as a normal macOS app.

## Acceptance Criteria

The first useful version is complete when:

- It builds locally from source.
- It records only while push-to-talk is active.
- It transcribes locally.
- It inserts or copies text into the active app.
- It works offline after model download.
- It has no cloud AI configuration.
- It has no automatic update check.
- It does not persist transcript/audio history.
- It keeps only the most recent transcript in memory for recovery.
- Its permissions are understandable and limited to the app's purpose.
- It has no notes, context capture, media ingestion, prompt routing, or AI cleanup surface.

## Open Questions

- What should the default push-to-talk key be?
- Should the last-capture recovery buffer clear after 10, 20, or 30 minutes?
- Should v1 support direct insertion, or clipboard-preserving paste only?
- Should model download happen in-app, or should models be manually installed for maximum network clarity?
- Which WhisperKit model gives the best quality/latency balance on the user's Mac?

## Risks

- macOS permissions can differ between debug builds and built app bundles.
- Event-tap push-to-talk may require Accessibility/Input Monitoring and careful recovery logic.
- Clipboard preservation can be imperfect for rich clipboard contents.
- WhisperKit model download and storage behavior must be audited.
- A fresh implementation means more initial coding than stripping Pindrop, but the final app should be smaller and easier to trust.

## Recommended Next Step

After Xcode is installed:

1. Inspect Pindrop's relevant implementation files as reference.
2. Create a fresh Voiced Xcode project.
3. Add WhisperKit.
4. Build a minimal local transcription spike before adding hotkeys and insertion.

