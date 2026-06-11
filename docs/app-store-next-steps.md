# App Store And TestFlight Next Steps

This plan tracks Voiced's Xcode Cloud and App Store Connect release path.

This machine, `rufus`, intentionally does not have Apple Developer signing/upload permissions. Use it for repo preparation, local App Store configuration work, and non-upload validation. Xcode Cloud handles signing, archive export, and TestFlight upload.

## Current State

Voiced already has the important repo-side building blocks for App Store distribution:

- `AppStore` Xcode configuration in `project.yml`.
- Sandboxed App Store entitlements in `Config/Voiced-AppStore.entitlements`.
- App Store Connect export options in `Config/ExportOptions-AppStoreConnect.plist`.
- Clean-slate local App Store runner in `script/run_app_store.sh`.
- Review notes and local sandbox proofs in `docs/app-store-readiness.md` and `docs/app-store-testflight.md`.

The App Store build must be sandboxed and must receive updates only through the Mac App Store.

## Main Review Risks

1. Global push-to-talk privacy permission.
   Voiced needs to explain that Accessibility or Input Monitoring is used only for explicit push-to-talk detection while another app is focused. The app does not use these permissions to send paste keystrokes.

2. Model downloads.
   Voiced downloads WhisperKit/Core ML model assets after explicit user choice. App Review notes and privacy metadata must say that the network request is for model download only, while audio and transcripts remain local.

3. Telemetry disclosure.
   If `POSTHOG_PROJECT_TOKEN` is supplied for TestFlight or App Store builds, App Store privacy answers must disclose any collected diagnostics or analytics accurately. If telemetry is not needed for first TestFlight, keep the token empty.

   Current first-upload state: the TestFlight build should include PostHog diagnostics, so App Store privacy answers and public privacy copy must disclose the basic usage and crash diagnostics collected.

4. Menu bar app reviewability.
   Because `LSUIElement` is true, review notes need a very direct test script so reviewers can find onboarding, Settings, model download, transcript review, and TextEdit verification without guessing.

## Phase 1: Apple Account And App Store Connect Setup

- Confirm the Apple Developer team is `GY6Q9L4423`. Done.
- Create or confirm the App Store Connect app record for bundle ID `net.applification.voiced`.
- Reserve the App Store listing name, category `Productivity`, and supported platform `macOS`. The plain `Voiced` listing name is unavailable; use `Voiced Dictation` unless a better available listing name is chosen.
- Confirm Xcode Cloud has App Store distribution signing and upload access for the team.
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
  - transcript review/drag surface
  - Settings > Models attribution and model management
  - successful dictation copied, pasted, or dragged into TextEdit
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
- Completed transcript is copied to the clipboard.
- Transcript review/drag controls work in TextEdit.
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

Run this phase in Xcode Cloud.

After upload:

- Wait for App Store Connect processing.
- Confirm the processed build appears under TestFlight.
- Add export compliance answers if prompted.
- Attach internal testing notes with the review/test script.
- Release to internal testers first.
- Collect logs and feedback specifically around onboarding, model download, push-to-talk permissions, clipboard output, transcript drag/review, and offline relaunch.
- Report any archive, export, upload, processing, signing, provisioning, or Beta App Review failures back into the repo so they can be fixed on `rufus` without adding Apple Developer credentials here.

Previous local upload attempts failed on `rufus` because it does not have Apple
Developer upload credentials. Keep `rufus` as a repo/prep machine unless its
Xcode account credentials are intentionally refreshed later.

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
- Submit with the review notes from `docs/app-store-testflight.md`.

## Repo Follow-Ups

- Consider adding a small `script/inspect_app_store_build.sh` helper for repeatable entitlement and bundle metadata checks.
- Keep PostHog diagnostics disclosure aligned across App Store privacy answers, `docs/app-store-metadata.md`, the public privacy page, and in-app Settings copy.
- Add a versioning note for App Store build numbers, because App Store Connect requires every uploaded build number to be unique.
