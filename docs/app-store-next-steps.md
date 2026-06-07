# App Store And TestFlight Next Steps

This plan moves Voiced from direct DMG distribution to a Mac App Store release path, starting with TestFlight.

This machine, `rufus`, intentionally does not have Apple Developer signing/upload permissions. Use it for repo preparation, local App Store configuration work, and non-upload validation. Run signing, archive export, and TestFlight upload steps on an Apple-authorized machine, then copy the results or failure output back into this plan as needed.

## Current State

Voiced already has the important repo-side building blocks for App Store distribution:

- `AppStore` Xcode configuration in `project.yml`.
- Sandboxed App Store entitlements in `Config/Voiced-AppStore.entitlements`.
- App Store Connect export options in `Config/ExportOptions-AppStoreConnect.plist`.
- Archive and upload helpers in `script/archive_app_store.sh` and `script/upload_testflight.sh`.
- Clean-slate local App Store runner in `script/run_app_store.sh`.
- Review notes and local sandbox proofs in `docs/app-store-readiness.md` and `docs/app-store-testflight.md`.

The direct distribution path can remain available for now, but it should be treated as separate from the App Store path. Direct distribution can keep the signed/notarized DMG flow; the App Store build must be sandboxed and must receive updates only through the Mac App Store.

## Main Review Risks

1. Accessibility permission.
   Voiced needs to explain that Accessibility is used only for explicit push-to-talk detection while another app is focused and optional Auto Paste. Clipboard Only must remain a clear non-Accessibility fallback.

2. Model downloads.
   Voiced downloads WhisperKit/Core ML model assets after explicit user choice. App Review notes and privacy metadata must say that the network request is for model download only, while audio and transcripts remain local.

3. Telemetry disclosure.
   If `POSTHOG_PROJECT_TOKEN` is supplied for TestFlight or App Store builds, App Store privacy answers must disclose any collected diagnostics or analytics accurately. If telemetry is not needed for first TestFlight, keep the token empty.

   Current first-upload preference: leave `POSTHOG_PROJECT_TOKEN` empty unless TestFlight diagnostics are worth the extra privacy disclosure work.

4. Menu bar app reviewability.
   Because `LSUIElement` is true, review notes need a very direct test script so reviewers can find onboarding, Settings, model download, output mode, and TextEdit verification without guessing.

## Phase 1: Apple Account And App Store Connect Setup

- Confirm the Apple Developer team is `GY6Q9L4423`. Done.
- Create or confirm the App Store Connect app record for bundle ID `net.applification.voiced`.
- Reserve the App Store listing name, category `Productivity`, and supported platform `macOS`. The plain `Voiced` listing name is unavailable; use `Voiced Dictation` unless a better available listing name is chosen.
- On the Apple-authorized machine, confirm Xcode has access to App Store distribution signing for the team, or prepare App Store Connect API authentication for CI/release automation. Done: `./script/archive_app_store.sh` completed successfully on the authorized machine.
- Create internal TestFlight tester group with the core team.
- Prepare external TestFlight group only after the internal build has passed smoke testing.

Apple references:

- App Store Connect build upload and management: <https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/>
- TestFlight beta testing overview: <https://developer.apple.com/help/app-store-connect/test-a-beta-version/overview-of-testing-with-testflight/>

## Phase 2: Metadata, Privacy, And Review Package

- Draft App Store metadata:
  - Name: `Voiced`
  - Category: `Productivity`
  - macOS minimum version: `14.0`
  - Support URL and marketing URL.
  - Privacy policy URL.
- Add App Review notes from `docs/app-store-testflight.md`, including the TextEdit test flow.
- Prepare screenshots that show:
  - menu bar status/menu
  - onboarding model choice
  - download confirmation/progress
  - output mode choice
  - Settings > Models attribution and model management
  - successful dictation into TextEdit
- Complete App Privacy answers in App Store Connect.
  - Audio and transcripts should be disclosed as not collected if they stay local and are not sent off-device.
  - Model downloads should be explained as network access to download local transcription assets.
  - Telemetry must match the build configuration actually shipped.
- Confirm third-party notices cover WhisperKit, OpenAI Whisper model lineage, and PostHog if analytics is enabled.

## Phase 3: Local Release Candidate Validation

Run the clean-slate App Store build:

```sh
./script/run_app_store.sh reset-run
```

Validate the full first-run path:

- Onboarding appears for a fresh user.
- Model choices show approximate download sizes before network access starts.
- Selected model downloads only after explicit user action.
- Downloaded model integrity verification succeeds.
- Microphone permission prompt appears and recording works.
- Clipboard Only mode works without Accessibility permission.
- Auto Paste mode explains Accessibility before opening System Settings.
- Auto Paste works in TextEdit after Accessibility is granted to the exact built app.
- Escape cancels active capture.
- The app relaunches offline and uses the cached model.
- Logs do not include transcript text or audio content.

Also validate the built app artifact:

```sh
xcodebuild \
  -project Voiced.xcodeproj \
  -scheme Voiced \
  -configuration AppStore \
  -destination "generic/platform=macOS" \
  build
```

Then inspect the built app's entitlements before upload:

```sh
codesign -d --entitlements :- build-appstore/Build/Products/AppStore/Voiced.app
```

Expected App Store entitlements:

- `com.apple.security.app-sandbox`
- `com.apple.security.device.audio-input`
- `com.apple.security.network.client`

## Phase 4: First TestFlight Upload

Run this phase on the Apple-authorized machine, not on `rufus`.

Archive and upload:

```sh
./script/upload_testflight.sh
```

If a fresh archive already exists:

```sh
./script/upload_testflight.sh --skip-archive
```

After upload:

- Wait for App Store Connect processing.
- Confirm the processed build appears under TestFlight.
- Add export compliance answers if prompted.
- Attach internal testing notes with the review/test script.
- Release to internal testers first.
- Collect logs and feedback specifically around onboarding, model download, Accessibility, Auto Paste, and offline relaunch.
- Report any archive, export, upload, processing, signing, provisioning, or Beta App Review failures back into the repo so they can be fixed on `rufus` without adding Apple Developer credentials here.

Current upload attempt:

- `./script/upload_testflight.sh --skip-archive` reached `xcodebuild -exportArchive` on `rufus` but failed before upload with `exportArchive Failed to Use Accounts`.
- Xcode reported invalid keychain credentials for an Apple Developer account: `missing Xcode-Username`.
- Next step is to refresh or replace the Xcode account credentials on the machine used for upload, then retry `./script/upload_testflight.sh --skip-archive`.

## Phase 5: External TestFlight

Before external TestFlight:

- Fix any internal tester issues.
- Make sure the build number has advanced from the internal build if a new binary is needed.
- Submit the build for Beta App Review.
- Use the same review notes, with the clear TextEdit test path.
- Keep the external tester cohort small at first, then widen after permission and model-download behavior looks stable.

## Phase 6: App Store Submission

Before submitting for public App Review:

- Confirm privacy answers still match the exact binary.
- Confirm App Store screenshots and metadata match current onboarding and Settings UI.
- Confirm App Store update behavior does not include a self-updater.
- Confirm the App Store build still has only the expected sandbox entitlements.
- Confirm direct distribution docs and website do not imply the DMG is the only or preferred production channel once the App Store version is live.
- Submit with the review notes from `docs/app-store-testflight.md`.

## Repo Follow-Ups

- Add a release checklist script or Make target that runs the App Store build, archive, entitlement inspection, and upload steps in order.
- Consider adding a small `script/inspect_app_store_build.sh` helper for repeatable entitlement and bundle metadata checks.
- Consider adding a short "authorized machine handoff" checklist that lists the exact scripts to run elsewhere and the output to report back.
- Decide whether first TestFlight should include PostHog telemetry. If yes, update the privacy checklist with the exact events and properties collected.
- Add a versioning note for App Store build numbers, because App Store Connect requires every uploaded build number to be unique.
- Update `README.md` once App Store distribution is active so direct DMG distribution is no longer presented as the main release path.
