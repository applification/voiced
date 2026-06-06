#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Voiced"
BUNDLE_ID="net.applification.voiced"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_BUNDLE="$BUILD_DIR/Build/Products/Debug/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
DIST_DIR="$ROOT_DIR/dist"
DIST_APP="$DIST_DIR/$APP_NAME.app"

detect_signing_identity() {
  if [[ -n "${VOICED_CODE_SIGN_IDENTITY:-}" ]]; then
    echo "$VOICED_CODE_SIGN_IDENTITY"
    return
  fi

  security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/^[[:space:]]*[0-9]*)[[:space:]]*\([A-F0-9][A-F0-9]*\)[[:space:]]*"Apple Development: .*".*/\1/p' \
    | head -n 1
}

build_app() {
  xcodebuild \
    -project "$ROOT_DIR/Voiced.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Debug \
    -derivedDataPath "$BUILD_DIR" \
    POSTHOG_PROJECT_TOKEN="${POSTHOG_PROJECT_TOKEN:-}" \
    POSTHOG_HOST="${POSTHOG_HOST:-https://eu.i.posthog.com}" \
    build
}

install_app() {
  local identity
  identity="$(detect_signing_identity)"

  mkdir -p "$DIST_DIR"
  rm -rf "$DIST_APP"
  ditto "$APP_BUNDLE" "$DIST_APP"

  if [[ -n "$identity" ]]; then
    codesign --force --deep --sign "$identity" --entitlements "$ROOT_DIR/Config/Voiced.entitlements" "$DIST_APP"
    echo "Signed $DIST_APP with $identity"
  else
    echo "No Apple Development signing identity found; leaving $DIST_APP ad-hoc signed" >&2
  fi

  /System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f -R -trusted "$DIST_APP"
  echo "Installed $DIST_APP"
}

open_app() {
  /usr/bin/open "$APP_BUNDLE"
}

open_installed_app() {
  /usr/bin/open "$DIST_APP"
}

stop_app() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
}

build_and_install() {
  stop_app
  build_app
  install_app
}

case "$MODE" in
  run)
    build_and_install
    open_installed_app
    ;;
  install)
    build_and_install
    ;;
  install-run|--install-run)
    build_and_install
    open_installed_app
    ;;
  launch|--launch)
    open_installed_app
    ;;
  stop|--stop)
    stop_app
    ;;
  --debug|debug)
    stop_app
    build_app
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    build_and_install
    open_installed_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    build_and_install
    open_installed_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  telemetry-live|--telemetry-live)
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    build_and_install
    open_installed_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|install|install-run|launch|stop|--debug|--logs|--telemetry|telemetry-live|--verify]" >&2
    exit 2
    ;;
esac
