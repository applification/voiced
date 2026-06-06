# Voiced

Voiced is a quiet, native macOS dictation companion for fast capture and clean transcription. It runs as a local menu bar app, records only while push-to-talk is held, transcribes speech locally with WhisperKit, and outputs the result either by copying it to the clipboard or pasting it into the focused app.

The project also includes a small Next.js website for the public product/download surface.

## What It Does

- Global push-to-talk capture for quick dictation from anywhere on macOS.
- Local speech transcription through WhisperKit and Argmax OSS models.
- Clipboard-only and paste modes, with paste mode preserving and restoring the previous clipboard when possible.
- Model download approval, progress reporting, and SHA-256 integrity verification before loading.
- Status menu controls for recording state, permissions, model selection, output behavior, and settings.
- Floating/cursor recording indicators and optional sound cues.
- Lightweight PostHog telemetry support when a public project token is supplied at build time.

## Repository Layout

- `*.swift` - the macOS app source.
- `Config/` - app entitlements, Info.plist, and asset catalogs.
- `Voiced.xcodeproj/` - generated Xcode project.
- `project.yml` - XcodeGen project definition.
- `script/` - build, run, model manifest, and release packaging scripts.
- `docs/` - local build, security, privacy, and release notes.
- `website/` - the Next.js marketing/download site.
- `DESIGN.md` - product and visual design system notes.

## Requirements

- macOS 14 or newer.
- Xcode with Swift 6 support.
- XcodeGen for regenerating the Xcode project from `project.yml`.
- An Apple Developer signing identity for the smoothest local Accessibility permission flow.

## Local Development

Generate the Xcode project after changing `project.yml`:

```sh
xcodegen generate
```

Build and launch the debug product:

```sh
./script/build_and_run.sh run
```

Install the built app to a stable local path and launch it:

```sh
./script/build_and_run.sh install-run
```

Running from `dist/Voiced.app` is recommended because macOS tracks Accessibility permissions by app identity and path. See [docs/local-build.md](docs/local-build.md) for signing and permission troubleshooting.

## Permissions

Voiced needs:

- Microphone access to record audio while push-to-talk is held.
- Accessibility access to send `Cmd+V` in paste mode.
- Input Monitoring on some systems for global event taps.

Copy-only mode is available for users who prefer not to grant Accessibility permission.

## Privacy And Security

Voiced is designed around local capture and local transcription. The app has no cloud transcription path, does not log transcript text, and deletes temporary audio files after transcription, cancellation, and error paths.

Downloaded transcription models are verified against pinned SHA-256 manifests before WhisperKit loads them. Public releases should be Developer ID signed, hardened, and notarized.

See [docs/security-model.md](docs/security-model.md) and [docs/privacy-checklist.md](docs/privacy-checklist.md) for more detail.

## Website

The public site lives in `website/`.

```sh
cd website
npm run dev
```

Then open `http://localhost:3000`.

## Release Packaging

Release packaging notes live in [docs/release-packaging.md](docs/release-packaging.md). The repository includes helper scripts for creating the local app bundle and release artifacts, but distribution builds should be signed and notarized before publication.

## License

Voiced is released under the [MIT License](LICENSE).
