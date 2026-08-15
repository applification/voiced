#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-package}"
APP_NAME="Voiced"
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="${VOICED_RELEASE_ROOT:-$SCRIPT_ROOT}"
RELEASE_DIR="$ROOT_DIR/build/release"
ARCHIVE_PATH="$RELEASE_DIR/$APP_NAME.xcarchive"
ARCHIVED_APP="$ARCHIVE_PATH/Products/Applications/$APP_NAME.app"
PACKAGE_DIR="$ROOT_DIR/dist/release"
PACKAGE_APP="$PACKAGE_DIR/$APP_NAME.app"
DMG_STAGING_DIR="$RELEASE_DIR/dmg-staging"
LEGACY_PACKAGE_ZIP="$PACKAGE_DIR/$APP_NAME.zip"
IDENTITY="${VOICED_DEVELOPER_ID_IDENTITY:-}"

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required tool: $1" >&2
    exit 1
  fi
}

require_distribution_identity() {
  if [[ -z "$IDENTITY" ]]; then
    echo "Set VOICED_DEVELOPER_ID_IDENTITY to a Developer ID Application identity." >&2
    exit 2
  fi

  case "$IDENTITY" in
    "Developer ID Application:"*) ;;
    *)
      echo "VOICED_DEVELOPER_ID_IDENTITY must name a Developer ID Application identity." >&2
      echo "Refusing to create a release package with: $IDENTITY" >&2
      exit 2
      ;;
  esac
}

require_package_app() {
  if [[ ! -d "$PACKAGE_APP" ]]; then
    echo "Release app not found at $PACKAGE_APP. Run package mode first." >&2
    exit 2
  fi
}

release_version() {
  require_package_app
  /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PACKAGE_APP/Contents/Info.plist"
}

package_zip_path() {
  echo "$PACKAGE_DIR/$APP_NAME-$(release_version).zip"
}

package_dmg_path() {
  echo "$PACKAGE_DIR/$APP_NAME-$(release_version).dmg"
}

verify_distribution_signature() {
  require_package_app

  local signing_details
  signing_details="$(codesign -dvvv "$PACKAGE_APP" 2>&1)"
  if [[ "$signing_details" != *"Authority=Developer ID Application:"* ]]; then
    echo "Release app is not signed with a Developer ID Application certificate." >&2
    echo "$signing_details" >&2
    exit 1
  fi
  if [[ "$signing_details" != *"flags="*"runtime"* ]]; then
    echo "Release app is not signed with Hardened Runtime enabled." >&2
    echo "$signing_details" >&2
    exit 1
  fi

  codesign --verify --deep --strict --verbose=2 "$PACKAGE_APP"
}

create_zip() {
  local zip_path="$1"
  rm -f "$zip_path"
  ditto -c -k --keepParent "$PACKAGE_APP" "$zip_path"
  echo "Created $zip_path"
}

create_dmg() {
  local dmg_path="$1"
  require_tool hdiutil

  rm -rf "$DMG_STAGING_DIR"
  mkdir -p "$DMG_STAGING_DIR"
  ditto "$PACKAGE_APP" "$DMG_STAGING_DIR/$APP_NAME.app"
  ln -s /Applications "$DMG_STAGING_DIR/Applications"

  rm -f "$dmg_path"
  hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING_DIR" \
    -ov \
    -format UDZO \
    "$dmg_path" >/dev/null
  echo "Created $dmg_path"
}

archive_app() {
  require_distribution_identity
  require_tool xcodegen
  require_tool xcodebuild

  mkdir -p "$RELEASE_DIR"
  rm -rf "$ARCHIVE_PATH"
  xcodegen generate --spec "$ROOT_DIR/project.yml"
  xcodebuild \
    -project "$ROOT_DIR/Voiced.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$IDENTITY" \
    archive
}

package_app() {
  archive_app
  require_tool codesign
  require_tool ditto

  mkdir -p "$PACKAGE_DIR"
  rm -rf "$PACKAGE_APP"
  rm -f "$LEGACY_PACKAGE_ZIP"
  ditto "$ARCHIVED_APP" "$PACKAGE_APP"
  verify_distribution_signature
  create_zip "$(package_zip_path)"
  create_dmg "$(package_dmg_path)"
}

notarize_package() {
  require_package_app
  require_tool xcrun

  local dmg_path
  dmg_path="$(package_dmg_path)"
  if [[ ! -f "$dmg_path" ]]; then
    echo "Release DMG not found at $dmg_path. Run package mode first." >&2
    exit 2
  fi

  if [[ -n "${VOICED_NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$dmg_path" \
      --keychain-profile "$VOICED_NOTARY_PROFILE" \
      --wait
  elif [[ -n "${VOICED_NOTARY_API_KEY_PATH:-}" && -n "${VOICED_NOTARY_KEY_ID:-}" && -n "${VOICED_NOTARY_ISSUER_ID:-}" ]]; then
    xcrun notarytool submit "$dmg_path" \
      --key "$VOICED_NOTARY_API_KEY_PATH" \
      --key-id "$VOICED_NOTARY_KEY_ID" \
      --issuer "$VOICED_NOTARY_ISSUER_ID" \
      --wait
  else
    echo "Configure VOICED_NOTARY_PROFILE or the three VOICED_NOTARY_API_* credentials." >&2
    exit 2
  fi

  xcrun stapler staple "$dmg_path"
  xcrun stapler validate "$dmg_path"
}

verify_package() {
  require_tool codesign
  require_tool hdiutil
  require_tool spctl
  require_tool xcrun
  verify_distribution_signature
  xcrun stapler validate "$(package_dmg_path)"
  spctl -a -vv --type execute "$PACKAGE_APP"
  hdiutil verify "$(package_dmg_path)"
}

case "$MODE" in
  archive)
    archive_app
    ;;
  package)
    package_app
    ;;
  notarize)
    echo "Submitting the release package to Apple's notarization service." >&2
    notarize_package
    ;;
  verify)
    verify_package
    ;;
  release)
    package_app
    notarize_package
    verify_package
    ;;
  *)
    echo "usage: $0 [archive|package|notarize|verify|release]" >&2
    exit 2
    ;;
esac
