# Voiced Privacy Checklist

Voiced is intentionally local-only after the approved model download.

## Runtime Data

- Audio files are written to the system temporary directory while recording.
- Temp audio is deleted after transcription, including transcription error paths.
- The most recent transcript is kept in memory only for recovery.
- The last transcript is not persisted to disk.
- The last transcript can be copied or cleared from the menu.
- Logs use file existence, character counts, and state transitions; transcript text and audio content are not logged.

## Model Download

Voiced uses WhisperKit with explicitly selected local models.

On first run, onboarding lets the user choose a local model and discloses the approximate size before network access begins. Later model changes are explicit from Settings > Models.

In the App Store sandbox build, WhisperKit caches downloaded model files under:

```text
~/Library/Containers/net.applification.voiced/Data/Documents/huggingface/models/argmaxinc/whisperkit-coreml
```

In the direct distribution build, WhisperKit may cache downloaded model files under:

```text
~/Documents/huggingface/models/argmaxinc/whisperkit-coreml
```

The Voiced menu shows the model name, local cache size, and lets you reveal or delete that model folder. Downloaded model files are verified against pinned SHA-256 manifests before WhisperKit loads them.

After the model is downloaded, WhisperKit should resolve from the local cache before attempting a download. To test offline behavior:

1. Download the selected model once while online.
2. Quit Voiced.
3. Disable network access.
4. Relaunch Voiced.
5. Transcribe a short phrase.

Expected result: transcription works without new model download traffic.

## Network Expectations

Expected:

- Hugging Face/WhisperKit model download only after the user presses a model download button in onboarding or `Download now` in Settings > Models.

Not expected:

- Cloud transcription.
- AI cleanup/enhancement calls.
- Automatic update checks.
- Transcript upload.
- Audio upload.

## Useful Logs

Telemetry-only logs:

```sh
./script/build_and_run.sh --telemetry
```

Broad process logs:

```sh
./script/build_and_run.sh --logs
```

When reviewing logs, transcript text should not appear. Character counts are acceptable.
