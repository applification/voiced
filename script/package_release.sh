#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Voiced"
BUNDLE_ID="net.applification.voiced"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build-release"
DIST_DIR="$ROOT_DIR/dist/release"
ARCHIVE_DIR="$DIST_DIR/archive"
STAGING_DIR="$DIST_DIR/dmg-staging"
APP_BUNDLE="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"
RELEASE_APP="$ARCHIVE_DIR/$APP_NAME.app"
ENTITLEMENTS="$ROOT_DIR/Config/Voiced.entitlements"

NOTARIZE=false
SKIP_BUILD=false

usage() {
  cat >&2 <<EOF
usage: $0 [--notarize] [--skip-build]

Builds, signs, verifies, and packages Voiced for distribution.

Required for distribution signing:
  VOICED_DEVELOPER_ID_IDENTITY  Optional explicit identity, otherwise the first
                                "Developer ID Application" identity is used.

Optional notarization:
  --notarize                    Submit and staple the DMG.
  VOICED_NOTARY_PROFILE         Keychain profile created by:
                                xcrun notarytool store-credentials <profile>

Outputs:
  dist/release/archive/Voiced.app
  dist/release/Voiced-<version>.zip
  dist/release/Voiced-<version>.dmg
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --notarize)
      NOTARIZE=true
      ;;
    --skip-build)
      SKIP_BUILD=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
  shift
done

detect_developer_id_identity() {
  if [[ -n "${VOICED_DEVELOPER_ID_IDENTITY:-}" ]]; then
    echo "$VOICED_DEVELOPER_ID_IDENTITY"
    return
  fi

  security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/^[[:space:]]*[0-9]*)[[:space:]]*\([A-F0-9][A-F0-9]*\)[[:space:]]*"Developer ID Application: .*".*/\1/p' \
    | head -n 1
}

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required tool: $1" >&2
    exit 1
  fi
}

build_release() {
  xcodebuild \
    -project "$ROOT_DIR/Voiced.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="-" \
    build
}

app_version() {
  /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$RELEASE_APP/Contents/Info.plist"
}

sign_app() {
  local identity="$1"

  codesign \
    --force \
    --deep \
    --options runtime \
    --timestamp \
    --entitlements "$ENTITLEMENTS" \
    --sign "$identity" \
    "$RELEASE_APP"
}

verify_app() {
  codesign --verify --deep --strict --verbose=2 "$RELEASE_APP"
  spctl --assess --type execute --verbose "$RELEASE_APP"
}

create_zip() {
  local zip_path="$1"
  rm -f "$zip_path"
  (cd "$ARCHIVE_DIR" && ditto -c -k --keepParent "$APP_NAME.app" "$zip_path")
}

create_dmg() {
  local dmg_path="$1"

  rm -rf "$STAGING_DIR"
  mkdir -p "$STAGING_DIR"
  ditto "$RELEASE_APP" "$STAGING_DIR/$APP_NAME.app"
  ln -s /Applications "$STAGING_DIR/Applications"

  rm -f "$dmg_path"
  hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$dmg_path" >/dev/null
}

notarize_dmg() {
  local dmg_path="$1"

  if [[ -z "${VOICED_NOTARY_PROFILE:-}" ]]; then
    echo "Set VOICED_NOTARY_PROFILE to a notarytool keychain profile before using --notarize." >&2
    echo "Create one with: xcrun notarytool store-credentials <profile-name>" >&2
    exit 1
  fi

  xcrun notarytool submit "$dmg_path" \
    --keychain-profile "$VOICED_NOTARY_PROFILE" \
    --wait

  xcrun stapler staple "$dmg_path"
  xcrun stapler validate "$dmg_path"
}

require_tool xcodebuild
require_tool codesign
require_tool hdiutil
require_tool ditto
require_tool spctl

identity="$(detect_developer_id_identity)"
if [[ -z "$identity" ]]; then
  echo "No Developer ID Application signing identity found." >&2
  echo "Install a Developer ID Application certificate, or set VOICED_DEVELOPER_ID_IDENTITY." >&2
  echo "Current identities:" >&2
  security find-identity -v -p codesigning >&2 || true
  exit 1
fi

if [[ "$SKIP_BUILD" != true ]]; then
  build_release
fi

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "Release app not found at $APP_BUNDLE" >&2
  exit 1
fi

rm -rf "$DIST_DIR"
mkdir -p "$ARCHIVE_DIR"
ditto "$APP_BUNDLE" "$RELEASE_APP"

sign_app "$identity"
verify_app

version="$(app_version)"
zip_path="$DIST_DIR/$APP_NAME-$version.zip"
dmg_path="$DIST_DIR/$APP_NAME-$version.dmg"

create_zip "$zip_path"
create_dmg "$dmg_path"

if [[ "$NOTARIZE" == true ]]; then
  notarize_dmg "$dmg_path"
fi

echo "Release packaging complete:"
echo "  App: $RELEASE_APP"
echo "  Zip: $zip_path"
echo "  DMG: $dmg_path"
if [[ "$NOTARIZE" != true ]]; then
  echo "Notarization skipped. Run with --notarize after setting VOICED_NOTARY_PROFILE."
fi
