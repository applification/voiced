# Implementation Plan Completion

This maps `docs/implementation-plan.md` to the current Voiced implementation.

## Milestones

- Milestone 1: complete. Voiced launches as a menu bar app with settings, microphone permission text, and AppKit status menu.
- Milestone 2: complete. WhisperKit is integrated, onboarding asks before downloading the selected model, and local microphone audio transcribes.
- Milestone 3: complete. Right Command push-to-talk records on press, stops on release, transcribes, copies the result, and exposes it through the review/drag interface.
- Milestone 4: complete in code. Temp audio is deleted after transcription, logs redact transcript/audio content, the most recent transcript is recoverable from memory, and model/network expectations are documented.
- Milestone 5: complete for v1. Voiced has recording/transcribing/error indicators, permission recovery UI, model status controls, launch-at-login, clipboard output, and review/drag controls.
- Milestone 6: complete for local development. Signing guidance and stable `dist/Voiced.app` install/run workflow are documented.

## Manual Checks

These require local runtime confirmation:

- Accessibility trusted after signing and launching the stable installed app.
- Clipboard output and transcript dragging work in target apps you care about.
- Offline transcription works after the model has already downloaded.
- Launch-at-login registers successfully with the signed app bundle.

## Accepted Constraints

- The App Store build stores WhisperKit's Hugging Face cache inside the sandbox container. Voiced exposes the path, size, reveal, and delete controls.
- Direct insertion is not implemented. Clipboard output plus the review/drag interface is the v1 insertion path.
- The default hotkey remains Right Command for now.
