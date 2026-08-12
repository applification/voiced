# SpeechAnalyzer Migration Plan

## Goal

Evaluate and migrate Voiced from its current WhisperKit/Core ML transcription path to Apple's native `SpeechAnalyzer` + `SpeechTranscriber` stack where it improves latency, memory use, power use, or reliability.

The migration should preserve Voiced's existing product constraints:

- Local-only transcription.
- Push-to-talk recording flow.
- Live transcript preview while recording.
- Final transcript review surface after release.
- No transcript or audio content in logs.
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

## Native Apple Options

Use:

- `SpeechAnalyzer`
- `SpeechTranscriber`
- `DictationTranscriber`
- `CaptureInputSequenceProvider`
- `AnalyzerInputConverter`
- `AssetInputSequenceProvider`
- `AssetInventory` for required speech asset availability/downloads

Target availability:

- macOS 26+ for `SpeechAnalyzer` / `SpeechTranscriber`.
- macOS 26+ for `DictationTranscriber`.
- macOS 27+ for the supported live microphone helpers:
  - `CaptureInputSequenceProvider`
  - `AnalyzerInputConverter`
- Keep WhisperKit for earlier macOS versions, unsupported locales, and any live-microphone use case below macOS 27.

The important product implication is that Apple Speech should be treated as a macOS 27+ live dictation backend. macOS 26 may still be useful for file-based experiments, asset readiness work, and offline transcription through the analyzer APIs, but the clean supported live microphone bridge lands in macOS 27.

WWDC26 generated subtitles are not the primary migration target. They are aimed at AVKit media subtitle generation and should only be considered for playback/captioning features, not Voiced's dictation pipeline.

## New Capabilities To Evaluate

Apple's beta Speech APIs unlock more than a like-for-like transcription engine swap. Evaluate these explicitly:

- `CaptureInputSequenceProvider`
  - Reads from `AVCaptureDevice` sources such as the default or external microphone.
  - Can configure a new `AVCaptureSession` or integrate with an app-provided session.
  - Produces analyzer-ready `AsyncSequence<AnalyzerInput>` values.
  - Reduces custom audio tap, buffer routing, and format-conversion code on macOS 27+.
- `AnalyzerInputConverter`
  - Converts app-owned `AVAudioBuffer` / `AVAudioPCMBuffer` streams into analyzer-ready input.
  - Preserves Voiced's existing capture/metering/recording pipeline while swapping the transcription engine.
  - Supports `flush()` at stop time so pending converted audio is finalized.
- `AssetInputSequenceProvider`
  - Reads audio files or specific `AVAssetTrack` values as analyzer-ready input.
  - Enables clean benchmarking against fixed audio fixtures.
  - Enables a possible "retry/reprocess with Apple Speech" path for the last captured recording.
- `SpeechTranscriber`
  - General-purpose speech-to-text model designed for long-form, conversational, distant, and live use cases.
  - Supports volatile and finalized result delivery.
  - Can provide audio time-range attributes for transcript/playback sync.
- `DictationTranscriber`
  - Provides dictation-specific presets such as progressive short/long dictation.
  - Supports content hints such as short-form, far-field, atypical speech, and customized language.
  - Can use `SFCustomLanguageModelData` / `SFSpeechLanguageModel` to bias recognition toward product and developer vocabulary.

For Voiced, the highest-value feature experiments are:

1. Apple live dictation on macOS 27 using `CaptureInputSequenceProvider`.
2. Apple live dictation on macOS 27 using Voiced's existing capture pipeline plus `AnalyzerInputConverter`.
3. Apple file transcription on macOS 26+ using `AssetInputSequenceProvider`.
4. `SpeechTranscriber` versus `DictationTranscriber` accuracy for developer vocabulary.
5. Custom language model data for terms such as "Voiced", "WhisperKit", "Contexture", "Applification", "SwiftUI", "Xcode", and other frequent technical terms.

## Phase 1: Compatibility Spike

Create a small isolated Apple transcription service before changing product defaults.

Tasks:

1. Add `AppleSpeechTranscriptionService` in `Voiced/Audio/`.
2. Gate live microphone support with `@available(macOS 27.0, *)`.
3. Keep it behind `AppTranscribing` or a new narrower internal protocol if the current protocol needs minor adjustments.
4. Implement model/asset readiness using Apple's supported-locale and asset inventory APIs.
5. Implement file transcription first on macOS 26+ using `AssetInputSequenceProvider` or `SpeechAnalyzer` file APIs.
6. Implement live transcription on macOS 27+ using `CaptureInputSequenceProvider`.
7. Add a second live prototype using Voiced's existing capture pipeline plus `AnalyzerInputConverter` if preserving audio metering/temp-file behavior is simpler than adopting `AVCaptureSession`.
8. Return `LiveTranscriptState` with:
   - finalized transcript text
   - volatile/current transcript text
   - audio level from Voiced's existing capture layer, unless the Apple provider path replaces that layer completely
   - optional segment timing metadata if the Apple result attributes prove useful

Acceptance criteria:

- The app builds on the current Xcode beta toolchain.
- The service can be selected in debug builds.
- File transcription works on macOS 26+ where Apple Speech assets and locales are available.
- Live recording starts and stops on macOS 27+ without changing `AppCoordinatorLive` behavior.
- Final text reaches the existing review surface.
- Unsupported OS and unsupported locale failures are explicit and recoverable.

## Phase 1b: Transcriber Comparison Spike

Compare `SpeechTranscriber` and `DictationTranscriber` before choosing the Apple backend shape.

Tasks:

1. Implement a `SpeechTranscriber` mode using progressive reporting where available.
2. Implement a `DictationTranscriber` mode using `progressiveLongDictation`.
3. Add optional `DictationTranscriber.ContentHint` variants for:
   - short-form dictation
   - far-field microphone input
   - atypical speech
   - customized language
4. Generate a small `SFCustomLanguageModelData` training fixture for Voiced/developer vocabulary.
5. Benchmark both Apple transcribers against the same audio fixtures and the current WhisperKit backend.

Acceptance criteria:

- The comparison can be run without changing production defaults.
- Results identify whether `SpeechTranscriber`, `DictationTranscriber`, or WhisperKit is best for:
  - short push-to-talk dictation
  - long notes
  - developer vocabulary
  - external microphone input
  - noisy/far-field laptop microphone input

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
  - Use Apple Speech live transcription on macOS 27+ when the selected locale is supported and required assets are available or downloadable.
  - Use Apple Speech file transcription only for explicit file/reprocess workflows on macOS 26+.
  - Fall back to WhisperKit otherwise.
- `appleSpeech`
  - Require Apple Speech.
  - Show an actionable error if unavailable for the requested mode.
- `whisperKit`
  - Preserve current behavior.

Tasks:

1. Add backend setting to `SettingsStore`.
2. Add a factory in `AppCoordinatorLive` or `AppServices` that constructs the selected `AppTranscribing`.
3. Keep user-facing naming simple:
   - "Automatic"
   - "Apple Speech"
   - "WhisperKit"
4. Hide Apple Speech live option on unsupported macOS versions, or show it disabled with a clear macOS 27+ requirement.
5. If a file/reprocess Apple Speech mode ships separately, label it distinctly from live dictation.

Acceptance criteria:

- Existing users keep their current WhisperKit behavior unless `automatic` is deliberately made the default in a later phase.
- Switching backend does not require restarting the app.
- Logs may identify a backend or broad failure class, never transcript/audio content.

## Phase 3: Asset And Onboarding UX

Replace WhisperKit-specific assumptions where Apple Speech is active.

Apple Speech path:

- Do not show Hugging Face/WhisperKit model download language.
- Check required speech assets through Apple APIs.
- Prompt before downloading Apple speech assets if a download is required.
- Explain that audio and transcript remain local.
- Explain when Apple Speech is unavailable because live microphone support requires macOS 27+.

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
   - file transcription available, live transcription requires macOS 27+
   - unavailable on this macOS version
   - failed
4. Update direct-distribution and privacy docs if Apple Speech becomes default.
5. Re-check network documentation if WhisperKit model downloads are no longer required.

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
- Accuracy with and without `DictationTranscriber` custom language data.
- Accuracy with content hints such as short-form, far-field, and atypical speech where relevant.
- Segment timing quality if audio time-range attributes are enabled.
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
- If `DictationTranscriber` custom language data is used, it measurably improves targeted terms without harming normal prose.
- Failure modes are clearer than WhisperKit or recover cleanly through fallback.

## Phase 5: Default Rollout

Roll out in layers.

1. Debug-only backend selector.
2. Internal backend selector.
3. `automatic` default for new installs on macOS 27+ if live benchmarks are favorable.
4. Prompt existing users to try Apple Speech if benchmarks are favorable.
5. Make Apple Speech default for all eligible users.
6. Consider removing WhisperKit only after:
   - Apple Speech covers required locales.
   - Older macOS support below 27 is no longer required, or WhisperKit remains as the legacy live backend.
   - Network/model-download tradeoffs are no longer worth maintaining.

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
if #available(macOS 27.0, *) {
    return AppleSpeechTranscriptionService(settings: settings)
} else {
    return WhisperKitTranscriptionService(settings: settings)
}
```

If file-only Apple Speech functionality is introduced, keep it separate from the live backend check:

```swift
if #available(macOS 26.0, *) {
    return AppleSpeechFileTranscriptionService(settings: settings)
}
```

Avoid changing `LiveTranscriptState` until the Apple implementation proves it needs extra fields. If confidence, timestamps, or segment metadata become useful, add them as optional fields and keep the UI tolerant of missing values.

When testing `DictationTranscriber`, keep custom language model assets small and explicit. The goal is targeted vocabulary bias, not a broad replacement language model.

## Risks

- Apple Speech language coverage may not match WhisperKit.
- APIs may still change across macOS 27 beta releases.
- The supported live microphone path is macOS 27+, not macOS 26+.
- Asset download and availability behavior may be less controllable than WhisperKit's explicit model store.
- `DictationTranscriber` custom vocabulary/context hints may help technical terms, but may also over-bias normal prose.
- Live transcript semantics may differ from WhisperKit's partial result behavior.
- `CaptureInputSequenceProvider` may conflict with Voiced's existing audio capture/metering assumptions if it replaces the current capture path.
- `AnalyzerInputConverter` may preserve the current capture path, but still requires macOS 27+ in the current SDK.
- Product copy must distinguish Apple-managed speech assets from third-party model downloads.

## Rollback Plan

The rollback path is to keep WhisperKit as a complete backend until Apple Speech has shipped successfully for at least one stable release.

Rollback triggers:

- Higher crash rate in Apple Speech sessions.
- Worse finalization latency after push-to-talk release.
- Accuracy regressions in common Voiced dictation.
- Custom language model regressions in ordinary prose.
- Asset download failures that users cannot recover from.
- macOS beta API breakage.

Rollback action:

- Change `automatic` to prefer WhisperKit.
- Leave explicit `appleSpeech` available only in debug/internal builds if needed.
- Keep all user data and settings compatible.

## Open Questions

- Which locales must Voiced support for vNext?
- Is `SpeechTranscriber` or `DictationTranscriber` better for Voiced's short push-to-talk dictation?
- Does `DictationTranscriber` custom language data materially improve developer vocabulary?
- Does Apple Speech's timing/segment data justify future transcript highlighting or editing features?
- Should Voiced adopt `CaptureInputSequenceProvider`, or keep the existing capture pipeline and use `AnalyzerInputConverter`?
- Can Voiced remove model-download network access if Apple Speech becomes the only production backend?
- Should Apple Speech be a Pro/default quality feature, or simply the default native path where available?

## Recommended Next Step

Build two debug-only spikes:

1. A macOS 26+ file-transcription spike using fixed audio fixtures and Apple Speech assets.
2. A macOS 27+ live-transcription spike comparing `SpeechTranscriber`, `DictationTranscriber`, `CaptureInputSequenceProvider`, and `AnalyzerInputConverter`.

Then run the small benchmark set before touching onboarding, release copy, or default behavior.
