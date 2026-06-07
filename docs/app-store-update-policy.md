# App Store Update Policy

Voiced's App Store build must use the Mac App Store for app updates. It should not include a self-updater that downloads, replaces, or installs a new app bundle.

Apple's Mac App Store review guidance says Mac App Store apps must distribute updates through the Mac App Store and must not download or install code or resources that add functionality or significantly change the app from what App Review saw.

## Recommended App Store Build Behavior

Use a lightweight update check only:

1. Read the current local app version from `CFBundleShortVersionString`.
2. Query Apple's public App Store lookup endpoint.
3. Compare the listed App Store version with the local version.
4. If a newer version exists, offer to open Voiced's App Store page.
5. Let the Mac App Store handle the download and installation.

Do not:

- Include Sparkle or another self-updater in the App Store build.
- Download a replacement `.app`, `.pkg`, executable, helper tool, or patch.
- Use downloaded data to unlock hidden app functionality that App Review did not see.
- Put App Store Connect API credentials in the app.

## Public Lookup Endpoint

Once Voiced has a public App Store listing, the app can check by bundle identifier:

```text
https://itunes.apple.com/lookup?bundleId=net.applification.voiced&country=gb
```

After the numeric Apple app ID is known, checking by ID is usually more stable:

```text
https://itunes.apple.com/lookup?id=APPLE_APP_ID
```

Useful response fields include:

- `version`
- `trackViewUrl`
- `releaseNotes`

During development, TestFlight, or before the public App Store listing exists, the lookup endpoint may return no results. Voiced should handle that gracefully, for example by showing `No App Store version found yet`.

## App Store Connect API

The App Store Connect API can read and manage version metadata, but it requires authenticated JWT requests using App Store Connect API keys. That makes it appropriate for backend or release automation, not for runtime checks inside Voiced.

Do not embed App Store Connect API keys or issuer IDs in the app bundle.

## Direct Distribution Build

This policy is for the App Store build. A separate direct-distribution build may use a normal self-update mechanism, such as Sparkle, if that build remains outside the Mac App Store and follows the direct-distribution signing and notarization path.

Keep any direct-distribution updater compiled out of the `AppStore` configuration.

## Model Downloads Are Separate

WhisperKit model downloads are data/model asset downloads, not app updates. They are acceptable only because they are explicitly user initiated, integrity checked, stored in the app's data area, and used for local transcription rather than executing code or bypassing App Review.
