# Direct Distribution

Voiced's supported release path is a Developer ID-signed, notarized direct download. The Release configuration is unsandboxed and keeps Hardened Runtime enabled.

## Prerequisites

- A `Developer ID Application` certificate in the signing keychain.
- The matching Apple Developer Team ID.
- An Apple ID app-specific password stored in the local Keychain through `notarytool store-credentials`.
- `xcodegen` and an authenticated GitHub CLI (`gh auth login`).

List available identities:

```sh
security find-identity -p codesigning -v
```

## Archive And Package

```sh
VOICED_DEVELOPER_ID_IDENTITY="Developer ID Application: Company (TEAMID)" \
  ./script/package_release.sh package
```

This regenerates the project, archives Release, verifies the signed app, and produces:

```text
build/release/Voiced.xcarchive
dist/release/Voiced.app
dist/release/Voiced-<version>.zip
```

Inspect the packaged app locally:

```sh
codesign -dvvv --entitlements :- dist/release/Voiced.app
```

Expected results:

- `codesign` reports `runtime` in the code directory flags.
- The entitlements do not contain `com.apple.security.app-sandbox`.
- The audio-input entitlement is present.
- Before notarization, `spctl` may reject the package even though its Developer ID signature is valid.

## Notarization

Store credentials once, outside the repository:

```sh
xcrun notarytool store-credentials "VoicedNotary" \
  --apple-id "developer@example.com" \
  --team-id "TEAMID" \
  --password "app-specific-password"
```

Notarization uploads the ZIP to Apple. Run this only with explicit release approval:

```sh
VOICED_NOTARY_PROFILE="VoicedNotary" ./script/package_release.sh notarize
```

The script submits with `notarytool`, waits for the result, staples the ticket to `Voiced.app`, validates the staple, and recreates the final ZIP so it contains the stapled app.

Run the final signature, staple, and Gatekeeper checks after notarization:

```sh
./script/package_release.sh verify
```

Run packaging, notarization, and final Gatekeeper verification without publishing with:

```sh
VOICED_DEVELOPER_ID_IDENTITY="Developer ID Application: Company (TEAMID)" \
VOICED_NOTARY_PROFILE="VoicedNotary" \
  ./script/package_release.sh release
```

## Publish A GitHub Release Locally

Set `MARKETING_VERSION` in `project.yml`, commit the release source, and run:

```sh
./script/publish_release.sh
```

You can also provide the expected tag explicitly:

```sh
./script/publish_release.sh v0.1.6
```

The publisher requires a clean checkout and a tag matching `MARKETING_VERSION`. It runs the tests, discovers the single installed Developer ID Application identity, packages and notarizes the tagged source, verifies the staple and Gatekeeper acceptance, creates and pushes the tag when it does not already exist, and publishes the ZIP plus its SHA-256 checksum to GitHub Releases.

If the version tag already exists at another commit, as with a retry after a failed release, the publisher builds that exact tagged source in a temporary checkout. Set `VOICED_DEVELOPER_ID_IDENTITY` only when more than one Developer ID Application identity is installed, or `VOICED_NOTARY_PROFILE` when using a profile name other than `VoicedNotary`.

The publisher explicitly marks the new GitHub Release as latest. `https://voiced.applification.net/download` resolves the latest release through GitHub's API and prefers its versioned ZIP asset, so no website deployment is needed for each app release. The route caches that lookup for up to five minutes.

## Installation

1. Download and expand `Voiced-<version>.zip`.
2. Move `Voiced.app` to `/Applications`.
3. Open Voiced and complete Microphone, Accessibility, and Input Monitoring setup.
4. Keep the app at the same path so macOS permission grants remain stable.

No publish, upload, release, or notarization command is run during ordinary development or packaging. Publishing occurs only when `script/publish_release.sh` is invoked explicitly.
