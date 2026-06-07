# App Store TestFlight

## Review Risk: Accessibility And Auto Paste

Apple can accept macOS apps that request Accessibility permission, but it is reviewer-sensitive. Voiced must be submitted with clear review notes because paste mode intentionally writes the transcript to the pasteboard and sends `Cmd+V` to the user's focused app after explicit Accessibility consent.

Suggested review notes:

```text
Voiced is a local-only macOS dictation utility. It records only while the user holds the configured push-to-talk key, transcribes locally, and inserts the transcript into the currently focused text field.

The app requests Accessibility permission only for two user-initiated features:
1. Detecting the explicit global push-to-talk key while another app is focused.
2. Sending Cmd+V to paste the completed transcript into the focused app when Paste mode is selected.

Voiced does not record arbitrary keystrokes, does not upload audio or transcript text, and offers Copy mode for users who do not want to grant Accessibility permission. The menu item "Test Paste Permission" lets reviewers verify the Accessibility-gated paste behavior in TextEdit.
```

This is not a guaranteed approval. It is a reasonable App Store argument because the app is sandboxed, the permission is user-granted, the behavior is core to the app, and the reviewer has a direct way to test it.

## Clean-Slate Local Visual Test

Quit running builds:

```sh
pkill -x Voiced || true
```

Remove local app bundles and build outputs from this repo:

```sh
rm -rf /Users/rufus/Apps/Voiced/dist/Voiced.app
rm -rf /Users/rufus/Apps/Voiced/dist/app-store
rm -rf /Users/rufus/Apps/Voiced/dist/release
rm -rf /Users/rufus/Apps/Voiced/build-appstore
rm -rf /Users/rufus/Apps/Voiced/build-appstore-devsign
```

Remove old installed direct-distribution copies if present:

```sh
rm -rf /Applications/Voiced.app
rm -rf "$HOME/Applications/Voiced.app"
```

Reset Voiced privacy permissions for a clean prompt cycle:

```sh
tccutil reset Microphone net.applification.voiced
tccutil reset Accessibility net.applification.voiced
```

If stale Voiced rows remain in System Settings > Privacy & Security > Accessibility, remove them manually with the minus button. macOS sometimes keeps separate rows for different build paths or code signatures until the user removes them.

## Upload To TestFlight

The repository includes:

- `Config/ExportOptions-AppStoreConnect.plist`
- `script/archive_app_store.sh`
- `script/upload_testflight.sh`

Upload command:

```sh
./script/upload_testflight.sh
```

If you already have a fresh archive:

```sh
./script/upload_testflight.sh --skip-archive
```

The upload requires an Apple Developer account in Xcode or App Store Connect API authentication, an App Store Connect app record for `net.applification.voiced`, and App Store distribution signing for team `L5H3AZQD66`.

After upload, Apple processes the build before it appears under App Store Connect > Voiced > TestFlight.
