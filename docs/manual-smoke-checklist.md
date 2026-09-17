# Manual Smoke Checklist

Use a stable app path such as `/Applications/Voiced.app` or `dist/Voiced.app` throughout the test. Moving or rebuilding an app at a different path can cause macOS to treat it as a new permission subject.

1. Launch Voiced and complete model download, Microphone, Accessibility, and Input Monitoring setup. Confirm every denied permission has an **Open Settings** recovery action and that Voiced does not modify TCC itself.
2. Focus TextEdit, hold Control + Shift + Space, speak a short sentence, and release. Confirm the text is inserted into TextEdit, the capture appears in Done, and the previous clipboard value is restored when unchanged.
3. Hold Control + Option + Shift + Space, speak a short sentence, and release. Confirm the shelf stays closed, the notch reports **Saved to Inbox**, and Option-Space reveals the new Voice item. Confirm its detail pane can edit, preview and apply refinements, copy, drag, export reminders, and change status. Confirm a refinement can be kept or undone and no separate review panel appears.
4. Select text in TextEdit or Safari, press Shift twice, and confirm a Selection item appears with source application context.
5. Press Option-Space, type a capture in the shelf composer, and confirm a Typed item appears. Search for it, edit it, move it between Inbox and Done, then remove it and use the transient Undo action to restore it.
6. Quit and relaunch Voiced. Confirm the shelf and statuses persist from `~/Library/Application Support/Voiced/Captures.json`.
7. Put a unique marker on the clipboard, focus TextEdit, and insert a capture. Confirm the capture is pasted and the previous marker is restored. Repeat while changing the clipboard immediately after insertion; confirm Voiced does not overwrite the newer clipboard value.
8. Revoke Accessibility or Input Monitoring in System Settings and relaunch. Confirm the shelf remains usable for typed capture and clearly explains which global capture or insertion features are unavailable.
9. Revoke Accessibility, then dictate with Control + Shift + Space into an editor. Confirm the notch explains that insertion failed while the raw capture remains safely in Inbox. Revoke Microphone and confirm the notch reports that microphone access is needed.
10. Enable Reduce Motion and confirm the notch does not pulse or slide. Use keyboard navigation and VoiceOver to operate onboarding model choices, shelf status, search, capture text, Copy, Drag, and Undo.
11. Run `codesign --verify --deep --strict --verbose=2 dist/release/Voiced.app` and inspect entitlements. Confirm Hardened Runtime is enabled, audio input is present, and App Sandbox is absent.

Do not automate permission approval, reset TCC, or run the notarization upload as part of an ordinary smoke test.

## Focused personal dictation

- Select Parakeet v2 English in Models, download and wait for Loaded. Confirm the CTC vocabulary model is prepared too. Relaunch offline and dictate successfully.
- Hold Ctrl+Shift+Space for 3–15 seconds. Words appear near the caret without focusing Voiced; the provisional tail changes. Release: final recognition inserts once. Test a quick press/release and Escape during setup/finalization.
- Add names and phrases in Vocabulary, edit/delete them, Save and relaunch. Compare recordings with vocabulary present and empty. Check a 30–60 second dictation across preview windows.
- Preview: change the destination caret, type, or switch apps while speaking. The completed text stays in the panel/Inbox instead of going into a changed field.
- Direct: in a plain native text field, dictate within existing text and over a selection. Release with cleanup enabled: only the draft is replaced. Check emoji before the insertion point. Escape restores the original selection only if the field is unchanged.
- Direct: type, move the caret, switch apps, or use an unsupported rich editor. No unrelated text should be changed; Copy remains available. Do not expect Direct support in every app.
- Ctrl+Option+Shift+Space only saves to Inbox, in either mode. Verify normal Cmd shortcuts, Option+Space and typing spaces still work.
- Enable cleanup, dictate, then restore the original from the shelf after relaunch. Disable Apple Intelligence or test on macOS <26: raw transcription still inserts.
- Repeat the same 10–20 English samples on both M1 Max and M1 Pro (32 GB). Record release-to-insertion delay and corrections needed; compare with Whisper Large v3 Turbo. Synthetic audio checks are not a substitute for the owner's microphone and voice.
