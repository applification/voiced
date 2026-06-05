# Implementation Plan Completion

This maps `docs/implementation-plan.md` to the current Voiced implementation.

## Milestones

- Milestone 1: complete. Voiced launches as a menu bar app with settings, microphone permission text, and AppKit status menu.
- Milestone 2: complete. WhisperKit is integrated, the tiny model requires explicit approval, and local microphone audio transcribes.
- Milestone 3: complete. Right Command push-to-talk records on press, stops on release, transcribes, and copies or pastes into the focused app.
- Milestone 4: complete in code. Temp audio is deleted after transcription, logs redact transcript/audio content, the most recent transcript is recoverable from memory, and model/network expectations are documented.
- Milestone 5: complete for v1. Voiced has recording/transcribing/error indicators, permission recovery UI, model status controls, launch-at-login, pasteboard preservation, and output mode settings.
- Milestone 6: complete for local development. Signing guidance and stable `dist/Voiced.app` install/run workflow are documented.

## Manual Checks

These require local runtime confirmation:

- Accessibility trusted after signing and launching the stable installed app.
- Paste works in target apps you care about.
- Offline transcription works after the model has already downloaded.
- Launch-at-login registers successfully with the signed app bundle.

## Accepted Constraints

- WhisperKit currently stores its Hugging Face cache under `~/Documents/huggingface/models/...`; Voiced exposes the path, size, reveal, and delete controls instead of relocating the cache.
- Direct insertion is not implemented. Clipboard-preserving paste is the v1 insertion path, with copy fallback when Accessibility is not trusted.
- The default hotkey remains Right Command for now.
