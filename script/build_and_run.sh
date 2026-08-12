#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Voiced"
BUNDLE_ID="net.applification.voiced"
CONFIGURATION="${VOICED_CONFIGURATION:-Debug}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_BUNDLE="$BUILD_DIR/Build/Products/$CONFIGURATION/$APP_NAME.app"
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
  xcodegen generate --spec "$ROOT_DIR/project.yml"
  xcodebuild \
    -project "$ROOT_DIR/Voiced.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$BUILD_DIR" \
    build
}

sign_stable_app() {
  local identity="$1"

  while IFS= read -r -d '' executable; do
    if file "$executable" | grep -q 'Mach-O'; then
      codesign --force --sign "$identity" --options runtime --timestamp=none "$executable"
    fi
  done < <(find "$DIST_APP/Contents" -type f -print0)

  while IFS= read -r nested; do
    codesign --force --sign "$identity" --options runtime --timestamp=none "$nested"
  done < <(find "$DIST_APP/Contents" -type d \( -name '*.framework' -o -name '*.xpc' -o -name '*.app' \) -print | sort -r)
  codesign \
    --force \
    --sign "$identity" \
    --options runtime \
    --timestamp=none \
    --entitlements "$ROOT_DIR/Config/Voiced.entitlements" \
    "$DIST_APP"
}

sign_stable_app_adhoc() {
  while IFS= read -r -d '' executable; do
    if file "$executable" | grep -q 'Mach-O'; then
      codesign --force --sign - --options runtime "$executable"
    fi
  done < <(find "$DIST_APP/Contents" -type f -print0)

  while IFS= read -r nested; do
    codesign --force --sign - --options runtime "$nested"
  done < <(find "$DIST_APP/Contents" -type d \( -name '*.framework' -o -name '*.xpc' -o -name '*.app' \) -print | sort -r)

  codesign \
    --force \
    --sign - \
    --options runtime \
    --entitlements "$ROOT_DIR/Config/Voiced.entitlements" \
    "$DIST_APP"
}

install_app() {
  local identity
  identity="$(detect_signing_identity)"

  mkdir -p "$DIST_DIR"
  rm -rf "$DIST_APP"
  ditto "$APP_BUNDLE" "$DIST_APP"

  if [[ -n "$identity" ]]; then
    sign_stable_app "$identity"
    echo "Signed $DIST_APP with $identity"
  else
    sign_stable_app_adhoc
    echo "No Apple Development identity found; applied a local ad-hoc signature" >&2
  fi

  codesign --verify --deep --strict --verbose=2 "$DIST_APP"
  /System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f -R -trusted "$DIST_APP"
  echo "Installed $DIST_APP"
}

stop_app() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
}

build_and_install() {
  stop_app
  build_app
  install_app
}

open_installed_app() {
  /usr/bin/open -n "$DIST_APP"
}

case "$MODE" in
  run|install-run|--install-run)
    build_and_install
    open_installed_app
    ;;
  install)
    build_and_install
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
  --verify|verify)
    build_and_install
    open_installed_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|install|launch|stop|--debug|--logs|--verify]" >&2
    exit 2
    ;;
esac
