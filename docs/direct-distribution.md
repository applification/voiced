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

Run packaging, notarization, and final Gatekeeper verification in one operation with:

```sh
VOICED_DEVELOPER_ID_IDENTITY="Developer ID Application: Company (TEAMID)" \
VOICED_NOTARY_PROFILE="VoicedNotary" \
  ./script/package_release.sh release
```

## GitHub Releases

Pushing a version tag runs `.github/workflows/release.yml`. The tag must match `MARKETING_VERSION` in `project.yml` exactly.

Configure these GitHub Actions repository secrets before publishing:

- `DEVELOPER_ID_CERTIFICATE_BASE64`: base64-encoded Developer ID Application `.p12` certificate and private key.
- `DEVELOPER_ID_CERTIFICATE_PASSWORD`: password used when exporting the `.p12`.
- `NOTARY_API_KEY_BASE64`: base64-encoded App Store Connect API `.p8` key.
- `NOTARY_API_KEY_ID`: App Store Connect API key ID.
- `NOTARY_API_ISSUER_ID`: App Store Connect API issuer ID.

For example, after setting `MARKETING_VERSION` to `0.1.6` and committing the release source:

```sh
git tag v0.1.6
git push origin v0.1.6
```

The workflow imports the certificate into a temporary keychain, creates a Developer ID-signed archive, notarizes and staples the app, verifies it with Gatekeeper, and publishes `Voiced-0.1.6.zip` plus its SHA-256 checksum to GitHub Releases.

## Installation

1. Download and expand `Voiced-<version>.zip`.
2. Move `Voiced.app` to `/Applications`.
3. Open Voiced and complete Microphone, Accessibility, and Input Monitoring setup.
4. Keep the app at the same path so macOS permission grants remain stable.

No publish, upload, release, or notarization command is run during ordinary development or packaging.
