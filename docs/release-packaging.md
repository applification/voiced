# Release packaging

Voiced ships as a signed macOS app packaged into a zip and DMG.

## Prerequisites

- Apple Developer Program membership.
- A `Developer ID Application` certificate installed in Keychain.
- Xcode command line tools available.
- Optional notarization profile stored with `notarytool`.

Create a notary profile once:

```sh
xcrun notarytool store-credentials voiced-notary \
  --key /path/to/AuthKey_XXXXXXXXXX.p8 \
  --key-id XXXXXXXXXX \
  --issuer xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

Use a Team API key from App Store Connect. The Key ID, Issuer ID, and `.p8` private key file are shown when generating the key under Users and Access > Integrations > App Store Connect API.

## Package without notarization

```sh
./script/package_release.sh
```

To include basic diagnostics in a release build, provide the public PostHog
project token at build time:

```sh
POSTHOG_PROJECT_TOKEN="phc_..." ./script/package_release.sh
```

The PostHog project token is embedded in the app and is not a secret. If
`POSTHOG_PROJECT_TOKEN` is omitted, the app builds normally and diagnostics stay
disabled because there is no destination project. Keep personal API keys, CI
credentials, and App Store Connect `.p8` keys out of the app bundle and
repository.

Outputs:

- `dist/release/archive/Voiced.app`
- `dist/release/Voiced-<version>.zip`
- `dist/release/Voiced-<version>.dmg`

Upload the versioned DMG to the GitHub release. The website `/download` route
asks the GitHub releases API for the first `.dmg` asset and redirects to it. If
no DMG is attached yet, it falls back to the latest release page.

## Package and notarize

```sh
POSTHOG_PROJECT_TOKEN="phc_..." VOICED_NOTARY_PROFILE=voiced-notary ./script/package_release.sh --notarize
```

The script submits the DMG, waits for notarization, staples the ticket, and validates the staple.

## Signing identity override

By default the script uses the first `Developer ID Application` identity in Keychain. To choose one explicitly:

```sh
VOICED_DEVELOPER_ID_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./script/package_release.sh
```

## Validation

The script runs:

```sh
codesign --verify --deep --strict --verbose=2 dist/release/archive/Voiced.app
spctl --assess --type execute --verbose dist/release/archive/Voiced.app
```

After changing the bundle identifier or signing identity, macOS may ask for Microphone and Accessibility permissions again.
