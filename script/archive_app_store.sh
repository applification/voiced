#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Voiced"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE_PATH="${VOICED_APP_STORE_ARCHIVE_PATH:-$ROOT_DIR/dist/app-store/Voiced.xcarchive}"

mkdir -p "$(dirname "$ARCHIVE_PATH")"

xcodebuild archive \
  -project "$ROOT_DIR/Voiced.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration AppStore \
  -archivePath "$ARCHIVE_PATH" \
  -destination "generic/platform=macOS" \
  POSTHOG_PROJECT_TOKEN="${POSTHOG_PROJECT_TOKEN:-}" \
  POSTHOG_HOST="${POSTHOG_HOST:-https://eu.i.posthog.com}"

echo "App Store archive complete:"
echo "  Archive: $ARCHIVE_PATH"
echo
echo "Upload using Xcode Organizer, Transporter, or xcodebuild -exportArchive with an App Store export options plist."
