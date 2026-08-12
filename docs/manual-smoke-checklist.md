# Manual Smoke Checklist

Use a stable app path such as `/Applications/Voiced.app` or `dist/Voiced.app` throughout the test. Moving or rebuilding an app at a different path can cause macOS to treat it as a new permission subject.

1. Launch Voiced and complete model download, Microphone, Accessibility, and Input Monitoring setup. Confirm every denied permission has an **Open Settings** recovery action and that Voiced does not modify TCC itself.
2. Focus TextEdit, hold Right Command, speak a short sentence, and release. Confirm the text is inserted into TextEdit, the capture appears in Done, and the previous clipboard value is restored when unchanged.
3. Hold Shift + Right Command, speak a short sentence, and release. Confirm the shelf opens with the new Voice item selected and its detail pane can edit, process, copy, insert, drag, export reminders, and change status. Confirm no separate review panel appears.
4. Select text in TextEdit or Safari, press Shift twice, and confirm a Selection item appears with source application context.
5. Press Option-Space, type a capture in the shelf composer, and confirm a Typed item appears. Search for it, edit it, move it through Next and Done, then remove it through the confirmation dialog.
6. Quit and relaunch Voiced. Confirm the shelf and statuses persist from `~/Library/Application Support/Voiced/Captures.json`.
7. Put a unique marker on the clipboard, focus TextEdit, and insert a capture. Confirm the capture is pasted and the previous marker is restored. Repeat while changing the clipboard immediately after insertion; confirm Voiced does not overwrite the newer clipboard value.
8. Revoke Accessibility or Input Monitoring in System Settings and relaunch. Confirm the shelf remains usable for typed capture and clearly explains which global capture or insertion features are unavailable.
9. Run `codesign --verify --deep --strict --verbose=2 dist/release/Voiced.app` and inspect entitlements. Confirm Hardened Runtime is enabled, audio input is present, and App Sandbox is absent.

Do not automate permission approval, reset TCC, or run the notarization upload as part of an ordinary smoke test.
