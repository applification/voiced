#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-package}"
APP_NAME="Voiced"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DIR="$ROOT_DIR/build/release"
ARCHIVE_PATH="$RELEASE_DIR/$APP_NAME.xcarchive"
ARCHIVED_APP="$ARCHIVE_PATH/Products/Applications/$APP_NAME.app"
PACKAGE_DIR="$ROOT_DIR/dist/release"
PACKAGE_APP="$PACKAGE_DIR/$APP_NAME.app"
PACKAGE_ZIP="$PACKAGE_DIR/$APP_NAME.zip"
IDENTITY="${VOICED_DEVELOPER_ID_IDENTITY:-${VOICED_CODE_SIGN_IDENTITY:-}}"

require_identity() {
  if [[ -z "$IDENTITY" ]]; then
    echo "Set VOICED_DEVELOPER_ID_IDENTITY to a Developer ID Application identity." >&2
    echo "For local workflow validation only, VOICED_CODE_SIGN_IDENTITY may name an Apple Development identity." >&2
    exit 2
  fi
}

archive_app() {
  require_identity
  mkdir -p "$RELEASE_DIR"
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
  mkdir -p "$PACKAGE_DIR"
  rm -rf "$PACKAGE_APP" "$PACKAGE_ZIP"
  ditto "$ARCHIVED_APP" "$PACKAGE_APP"
  codesign --verify --deep --strict --verbose=2 "$PACKAGE_APP"
  ditto -c -k --keepParent "$PACKAGE_APP" "$PACKAGE_ZIP"
  echo "Created $PACKAGE_ZIP"
}

verify_package() {
  codesign -dvvv --entitlements :- "$PACKAGE_APP"
  codesign --verify --deep --strict --verbose=2 "$PACKAGE_APP"
  spctl -a -vv --type execute "$PACKAGE_APP"
}

notarize_package() {
  if [[ -z "${VOICED_NOTARY_PROFILE:-}" ]]; then
    echo "Set VOICED_NOTARY_PROFILE to a notarytool keychain profile." >&2
    exit 2
  fi
  xcrun notarytool submit "$PACKAGE_ZIP" --keychain-profile "$VOICED_NOTARY_PROFILE" --wait
  xcrun stapler staple "$PACKAGE_APP"
  xcrun stapler validate "$PACKAGE_APP"
}

case "$MODE" in
  archive)
    archive_app
    ;;
  package)
    package_app
    ;;
  verify)
    verify_package
    ;;
  notarize)
    echo "Notarization uploads the package to Apple. Continue only with explicit release approval." >&2
    notarize_package
    ;;
  *)
    echo "usage: $0 [archive|package|verify|notarize]" >&2
    exit 2
    ;;
esac
