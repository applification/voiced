# Release packaging

Voiced ships as a signed macOS app packaged into a zip and DMG.

## Prerequisites

- Apple Developer Program membership.
- A `Developer ID Application` certificate installed in Keychain.
- Xcode command line tools available.
- Optional notarization profile stored with `notarytool`.

Create a notary profile once:

```sh
xcrun notarytool store-credentials voiced-notary
```

## Package without notarization

```sh
./script/package_release.sh
```

Outputs:

- `dist/release/archive/Voiced.app`
- `dist/release/Voiced-<version>.zip`
- `dist/release/Voiced-<version>.dmg`

## Package and notarize

```sh
VOICED_NOTARY_PROFILE=voiced-notary ./script/package_release.sh --notarize
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
