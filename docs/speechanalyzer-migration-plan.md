# SpeechAnalyzer Migration Plan

## Goal

Evaluate and migrate Voiced from its current WhisperKit/Core ML transcription path to Apple's native `SpeechAnalyzer` + `SpeechTranscriber` stack where it improves latency, memory use, power use, reliability, or App Store fit.

The migration should preserve Voiced's existing product constraints:

- Local-only transcription.
- Push-to-talk recording flow.
- Live transcript preview while recording.
- Final transcript review surface after release.
- No transcript or audio content in logs or diagnostics.
- Temporary audio cleanup after processing.
- A fallback path for unsupported OS versions, languages, devices, and model-asset failures.

## Current Architecture

Relevant existing seams:

- `Voiced/App/ServiceProtocols.swift`
  - `AppTranscribing` defines the app-facing transcription interface.
- `Voiced/App/AppCoordinatorLive.swift`
  - Owns capture state and calls `startLiveTranscription`, `stopLiveTranscription`, `loadModelIfNeeded`, and model readiness state.
- `Voiced/Audio/TranscriptionService.swift`
  - Current `WhisperKitTranscriptionService` implementation.
- `Voiced/Audio/LiveTranscriptState.swift`
  - Live transcript state passed to UI.
- `Voiced/Audio/TranscriptionModel.swift`
  - Current model selection and WhisperKit model configuration.
- `Voiced/Models/ModelStore.swift`
  - Current WhisperKit model storage/download assumptions.
- `Voiced/UI/IntroOnboardingPresenter.swift` and `Voiced/UI/SettingsView.swift`
  - User-facing model choice, download, and status UI.

The existing protocol is the right migration boundary. Avoid spreading Apple Speech framework calls into the coordinator or UI.

## Native Apple Option

Use:

- `SpeechAnalyzer`
- `SpeechTranscriber`
- `AssetInventory` for required speech asset availability/downloads
- `DictationTranscriber` only as a compatibility fallback if it satisfies product requirements

Target availability:

- macOS 26+ for `SpeechAnalyzer` / `SpeechTranscriber`.
- Keep WhisperKit for earlier macOS versions and unsupported locales.

WWDC26 generated subtitles are not the primary migration target. They are aimed at AVKit media subtitle generation and should only be considered for playback/captioning features, not Voiced's dictation pipeline.

## Phase 1: Compatibility Spike

Create a small isolated Apple transcription service before changing product defaults.

Tasks:

1. Add `AppleSpeechTranscriptionService` in `Voiced/Audio/`.
2. Gate the implementation with `@available(macOS 26.0, *)`.
3. Keep it behind `AppTranscribing` or a new narrower internal protocol if the current protocol needs minor adjustments.
4. Implement model/asset readiness using Apple's supported-locale and asset inventory APIs.
5. Implement live transcription from microphone audio using the same push-to-talk lifecycle as the current service.
6. Implement file transcription if still needed for tests, recovery, or fallback flows.
7. Return `LiveTranscriptState` with:
   - finalized transcript text
   - volatile/current transcript text
   - audio level if Apple APIs expose enough signal, otherwise keep the existing audio-level calculation in Voiced's capture layer

Acceptance criteria:

- The app builds on the current Xcode 26 toolchain.
- The service can be selected in debug builds.
- Recording starts and stops without changing `AppCoordinatorLive` behavior.
- Final text reaches the existing review surface.
- Unsupported OS and unsupported locale failures are explicit and recoverable.

## Phase 2: Backend Selection

Introduce a transcription backend setting without removing WhisperKit.

Recommended model:

```swift
enum TranscriptionBackend: String, Codable, CaseIterable {
    case automatic
    case appleSpeech
    case whisperKit
}
```

Selection behavior:

- `automatic`
  - Use Apple Speech on macOS 26+ when the selected locale is supported and required assets are available or downloadable.
  - Fall back to WhisperKit otherwise.
- `appleSpeech`
  - Require Apple Speech.
  - Show an actionable error if unavailable.
- `whisperKit`
  - Preserve current behavior.

Tasks:

1. Add backend setting to `SettingsStore`.
2. Add a factory in `AppCoordinatorLive` or `AppServices` that constructs the selected `AppTranscribing`.
3. Keep user-facing naming simple:
   - "Automatic"
   - "Apple Speech"
   - "WhisperKit"
4. Hide Apple Speech option on unsupported macOS versions, or show it disabled with a clear macOS 26+ requirement.

Acceptance criteria:

- Existing users keep their current WhisperKit behavior unless `automatic` is deliberately made the default in a later phase.
- Switching backend does not require restarting the app.
- Telemetry records backend identifiers only, never transcript/audio content.

## Phase 3: Asset And Onboarding UX

Replace WhisperKit-specific assumptions where Apple Speech is active.

Apple Speech path:

- Do not show Hugging Face/WhisperKit model download language.
- Check required speech assets through Apple APIs.
- Prompt before downloading Apple speech assets if a download is required.
- Explain that audio and transcript remain local.

WhisperKit path:

- Keep current model download disclosure and storage behavior.

Tasks:

1. Split onboarding copy by backend.
2. Split settings model status by backend.
3. Add asset status states:
   - available
   - needs download
   - downloading
   - unsupported locale
   - unavailable on this macOS version
   - failed
4. Update App Store metadata and privacy docs if Apple Speech becomes default.
5. Re-check sandbox entitlements:
   - Apple Speech may reduce or remove the need for network access if WhisperKit downloads are no longer default.
   - Keep network entitlement if WhisperKit fallback remains user-accessible and downloads models.

Acceptance criteria:

- First-run copy accurately describes the active backend.
- Users are never told a WhisperKit model is downloading when Apple speech assets are being prepared.
- Privacy documentation remains accurate for both backends.

## Phase 4: Benchmarking

Do not switch defaults until Apple Speech beats or matches WhisperKit on Voiced's actual workload.

Create a benchmark harness that runs both backends on the same audio set.

Measure:

- Time to first volatile text.
- Time from key release to final transcript.
- Real-time factor for short, medium, and long clips.
- Memory peak.
- CPU/GPU/ANE utilization where observable.
- Energy impact.
- Word error rate against hand-corrected samples.
- Punctuation and capitalization quality.
- Behavior with silence, false starts, room noise, accents, and technical vocabulary.
- Stability over repeated push-to-talk sessions.

Suggested fixture set:

- 5 seconds: short command.
- 15 seconds: normal dictation.
- 60 seconds: paragraph dictation.
- 5 minutes: long-form notes.
- Noisy background sample.
- Quiet built-in microphone sample.
- External microphone sample.
- Product vocabulary sample for "Voiced", "WhisperKit", "Contexture", "Applification", and common developer terms.

Acceptance criteria for making Apple Speech the default:

- First text latency is equal or better for short dictation.
- Finalization latency after release is equal or better.
- Memory and energy are materially better, or accuracy is materially better.
- Accuracy is not worse on product vocabulary and developer dictation.
- Failure modes are clearer than WhisperKit or recover cleanly through fallback.

## Phase 5: Default Rollout

Roll out in layers.

1. Debug-only backend selector.
2. Internal/TestFlight backend selector.
3. `automatic` default for new installs on macOS 26+.
4. Prompt existing users to try Apple Speech if benchmarks are favorable.
5. Make Apple Speech default for all eligible users.
6. Consider removing WhisperKit only after:
   - Apple Speech covers required locales.
   - Older macOS support is no longer required.
   - App Store/network/model-download tradeoffs are no longer worth maintaining.

Acceptance criteria:

- Existing users are not forced into a worse backend.
- Support docs can explain which backend is active.
- Error reports include backend, OS version, locale, and asset state, but not transcript/audio content.

## Implementation Notes

Keep `AppCoordinatorLive` mostly unchanged. It should not know whether transcription comes from WhisperKit or Apple Speech.

Prefer a structure like:

```swift
protocol TranscriptionServiceFactory {
    func makeTranscriber(settings: SettingsStore) -> any AppTranscribing
}
```

Use `@available` wrappers to prevent accidental runtime crashes:

```swift
if #available(macOS 26.0, *) {
    return AppleSpeechTranscriptionService(settings: settings)
} else {
    return WhisperKitTranscriptionService(settings: settings)
}
```

Avoid changing `LiveTranscriptState` until the Apple implementation proves it needs extra fields. If confidence, timestamps, or segment metadata become useful, add them as optional fields and keep the UI tolerant of missing values.

## Risks

- Apple Speech language coverage may not match WhisperKit.
- APIs may still change across macOS 26 beta releases.
- Asset download and availability behavior may be less controllable than WhisperKit's explicit model store.
- Custom vocabulary/contextual biasing may be weaker or unavailable compared with current or future WhisperKit tuning.
- Live transcript semantics may differ from WhisperKit's partial result behavior.
- App Store review copy must distinguish Apple-managed speech assets from third-party model downloads.

## Rollback Plan

The rollback path is to keep WhisperKit as a complete backend until Apple Speech has shipped successfully for at least one stable release.

Rollback triggers:

- Higher crash rate in Apple Speech sessions.
- Worse finalization latency after push-to-talk release.
- Accuracy regressions in common Voiced dictation.
- Asset download failures that users cannot recover from.
- macOS beta API breakage.

Rollback action:

- Change `automatic` to prefer WhisperKit.
- Leave explicit `appleSpeech` available only in debug/internal builds if needed.
- Keep all user data and settings compatible.

## Open Questions

- Which locales must Voiced support for vNext?
- Does Apple Speech expose enough timing/segment data for future transcript highlighting or editing features?
- Does Apple Speech support custom vocabulary or contextual strings comparable to legacy `SFSpeechRecognizer` hints?
- Can Voiced remove the network entitlement if Apple Speech becomes the only production backend?
- Should Apple Speech be a Pro/default quality feature, or simply the default native path where available?

## Recommended Next Step

Build the macOS 26-gated `AppleSpeechTranscriptionService` spike and wire it into a debug-only backend selector. Then run a small benchmark set before touching onboarding, App Store copy, or default behavior.
