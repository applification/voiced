#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Voiced"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE_PATH="${VOICED_APP_STORE_ARCHIVE_PATH:-$ROOT_DIR/dist/app-store/Voiced.xcarchive}"
EXPORT_PATH="${VOICED_APP_STORE_EXPORT_PATH:-$ROOT_DIR/dist/app-store/export}"
EXPORT_OPTIONS="${VOICED_EXPORT_OPTIONS_PLIST:-$ROOT_DIR/Config/ExportOptions-AppStoreConnect.plist}"

usage() {
  cat >&2 <<EOF
usage: $0 [--skip-archive]

Archives Voiced with the AppStore configuration, then uploads it to App Store
Connect for TestFlight/App Store processing.

Requirements:
  - Apple Developer account added to Xcode, or App Store Connect API key
    arguments supplied through xcodebuild environment/flags.
  - App Store Connect app record for net.applification.voiced.
  - App Store distribution signing available for Apple Developer team GY6Q9L4423.

Environment overrides:
  VOICED_APP_STORE_ARCHIVE_PATH
  VOICED_APP_STORE_EXPORT_PATH
  VOICED_EXPORT_OPTIONS_PLIST
EOF
}

SKIP_ARCHIVE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-archive)
      SKIP_ARCHIVE=true
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

if [[ "$SKIP_ARCHIVE" != true ]]; then
  "$ROOT_DIR/script/archive_app_store.sh"
fi

rm -rf "$EXPORT_PATH"
mkdir -p "$EXPORT_PATH"

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -allowProvisioningUpdates

echo "Upload requested for $APP_NAME."
echo "Check App Store Connect > Voiced > TestFlight after Apple finishes processing the build."
