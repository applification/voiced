# Direct Distribution

Voiced's supported release path is a Developer ID-signed, notarized direct download. The Release configuration is unsandboxed and keeps Hardened Runtime enabled.

## Prerequisites

- A `Developer ID Application` certificate in the signing keychain.
- The matching Apple Developer Team ID.
- For notarization, App Store Connect API credentials or an Apple ID app-specific password stored through `notarytool store-credentials`.

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
dist/release/Voiced.zip
```

Validate the package locally:

```sh
./script/package_release.sh verify
codesign -dvvv --entitlements :- dist/release/Voiced.app
```

Expected results:

- `codesign` reports `runtime` in the code directory flags.
- The entitlements do not contain `com.apple.security.app-sandbox`.
- The audio-input entitlement is present.
- Before notarization, `spctl` may reject an Apple Development-signed validation package. A Developer ID-signed and notarized production package should be accepted.

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

The script submits with `notarytool`, waits for the result, staples the ticket to `Voiced.app`, and validates the staple. Recreate the final ZIP after stapling before publishing it.

## Installation

1. Download and expand `Voiced.zip`.
2. Move `Voiced.app` to `/Applications`.
3. Open Voiced and complete Microphone, Accessibility, and Input Monitoring setup.
4. Keep the app at the same path so macOS permission grants remain stable.

No publish, upload, release, or notarization command is run during ordinary development or packaging.
