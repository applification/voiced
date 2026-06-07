#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Voiced"
BUNDLE_ID="net.applification.voiced"
INTRO_ONBOARDING_KEY="hasSeenIntroOnboarding"
OUTPUT_MODE_KEY="outputMode"
TRANSCRIPTION_MODEL_KEY="transcriptionModel"
MODEL_DOWNLOADS_APPROVED_KEY="modelDownloadsApproved"
LEGACY_TINY_MODEL_APPROVED_KEY="whisperTinyModelApproved"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build-appstore"
APP_BUNDLE="$BUILD_DIR/Build/Products/AppStore/$APP_NAME.app"
CONTAINER_PREFS="$HOME/Library/Containers/$BUNDLE_ID/Data/Library/Preferences/$BUNDLE_ID.plist"
CONTAINER_DOCUMENTS="$HOME/Library/Containers/$BUNDLE_ID/Data/Documents"

usage() {
  cat >&2 <<EOF
usage: $0 [run|reset-run|build|launch|stop|logs|reset-logs|reset-permissions|reset-onboarding|reset-app-state]

Builds and runs the sandboxed AppStore configuration for local App Store
compatibility testing. This is intentionally separate from build_and_run.sh,
which runs the direct-distribution Debug build.

Modes:
  run                Stop, build, and launch the AppStore build.
  reset-run          Stop, reset TCC/app state, build, and launch.
  build              Build the AppStore configuration only.
  launch             Launch the existing AppStore build.
  stop               Stop Voiced if it is running.
  logs               Stop, build, launch, then stream Voiced logs.
  reset-logs         Stop, reset TCC/app state, build, launch, then stream logs.
  reset-permissions  Reset Microphone and Accessibility permissions only.
  reset-onboarding   Reset the first-run intro onboarding flag only.
  reset-app-state    Reset local app state used by first-run visual tests.
EOF
}

build_app() {
  xcodebuild -quiet \
    -project "$ROOT_DIR/Voiced.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration AppStore \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$BUILD_DIR" \
    CODE_SIGN_STYLE=Automatic \
    POSTHOG_PROJECT_TOKEN="${POSTHOG_PROJECT_TOKEN:-}" \
    POSTHOG_HOST="${POSTHOG_HOST:-https://eu.i.posthog.com}" \
    build
}

stop_app() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
}

reset_permissions() {
  echo "Resetting Microphone and Accessibility permissions for $BUNDLE_ID"
  tccutil reset Microphone "$BUNDLE_ID" >/dev/null || true
  tccutil reset Accessibility "$BUNDLE_ID" >/dev/null || true
}

reset_onboarding() {
  echo "Resetting first-run onboarding state for $BUNDLE_ID"
  delete_default "$INTRO_ONBOARDING_KEY"
  killall cfprefsd >/dev/null 2>&1 || true
}

delete_default() {
  local key="$1"
  defaults delete "$BUNDLE_ID" "$key" >/dev/null 2>&1 || true
  if [[ -f "$CONTAINER_PREFS" ]]; then
    /usr/libexec/PlistBuddy -c "Delete :$key" "$CONTAINER_PREFS" >/dev/null 2>&1 || true
  fi
}

reset_app_state() {
  echo "Resetting local app state for $BUNDLE_ID"
  delete_default "$INTRO_ONBOARDING_KEY"
  delete_default "$OUTPUT_MODE_KEY"
  delete_default "$TRANSCRIPTION_MODEL_KEY"
  delete_default "$MODEL_DOWNLOADS_APPROVED_KEY"
  delete_default "$LEGACY_TINY_MODEL_APPROVED_KEY"
  rm -rf "$CONTAINER_DOCUMENTS/huggingface"
  killall cfprefsd >/dev/null 2>&1 || true
}

reset_for_first_run() {
  reset_permissions
  reset_app_state
}

launch_app() {
  if [[ ! -d "$APP_BUNDLE" ]]; then
    echo "App Store build not found at $APP_BUNDLE" >&2
    echo "Run: $0 build" >&2
    exit 1
  fi
  /System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f -R -trusted "$APP_BUNDLE"
  /usr/bin/open -n "$APP_BUNDLE"
}

mode="${1:-run}"
case "$mode" in
  run)
    stop_app
    build_app
    launch_app
    ;;
  reset-run)
    stop_app
    reset_for_first_run
    build_app
    launch_app
    ;;
  build)
    build_app
    ;;
  launch)
    launch_app
    ;;
  stop)
    stop_app
    ;;
  logs)
    stop_app
    build_app
    launch_app
    /usr/bin/log stream --debug --info --style compact --predicate "process == \"$APP_NAME\" AND subsystem == \"net.applification.voiced\""
    ;;
  reset-logs)
    stop_app
    reset_for_first_run
    build_app
    launch_app
    /usr/bin/log stream --debug --info --style compact --predicate "process == \"$APP_NAME\" AND subsystem == \"net.applification.voiced\""
    ;;
  reset-permissions)
    stop_app
    reset_permissions
    ;;
  reset-onboarding)
    stop_app
    reset_onboarding
    ;;
  reset-app-state)
    stop_app
    reset_app_state
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage
    exit 2
    ;;
esac
