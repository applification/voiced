#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Voiced"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_FILE="$ROOT_DIR/project.yml"
GITHUB_REPOSITORY="applification/voiced"
DOWNLOAD_URL="https://voiced.applification.net/download"
NOTARY_PROFILE="${VOICED_NOTARY_PROFILE:-VoicedNotary}"
IDENTITY="${VOICED_DEVELOPER_ID_IDENTITY:-}"
TEMP_ROOT=""
TEMP_WORKTREE=""

cleanup() {
  if [[ -n "$TEMP_WORKTREE" ]]; then
    git -C "$ROOT_DIR" worktree remove --force "$TEMP_WORKTREE" >/dev/null 2>&1 || true
  fi
  if [[ -n "$TEMP_ROOT" ]]; then
    rmdir "$TEMP_ROOT" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

fail() {
  echo "$1" >&2
  exit 1
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required tool: $1"
}

project_version() {
  awk '$1 == "MARKETING_VERSION:" { print $2; exit }' "$PROJECT_FILE"
}

resolve_distribution_identity() {
  if [[ -n "$IDENTITY" ]]; then
    case "$IDENTITY" in
      "Developer ID Application:"*) return ;;
      *) fail "VOICED_DEVELOPER_ID_IDENTITY must name a Developer ID Application identity." ;;
    esac
  fi

  local identities=()
  local discovered_identity
  while IFS= read -r discovered_identity; do
    identities+=("$discovered_identity")
  done < <(
    security find-identity -v -p codesigning \
      | sed -n 's/.*"\(Developer ID Application: .*\)".*/\1/p'
  )

  case "${#identities[@]}" in
    0)
      fail "No Developer ID Application identity is installed. Import one into Keychain Access before publishing."
      ;;
    1)
      IDENTITY="${identities[0]}"
      ;;
    *)
      printf '%s\n' "Multiple Developer ID Application identities are installed:" >&2
      printf '  %s\n' "${identities[@]}" >&2
      fail "Set VOICED_DEVELOPER_ID_IDENTITY to the identity to use."
      ;;
  esac
}

if (( $# > 1 )); then
  fail "usage: $0 [vMAJOR.MINOR.PATCH]"
fi

require_tool git
require_tool gh
require_tool security
require_tool xcodegen
require_tool xcodebuild
require_tool shasum
require_tool ditto

VERSION="$(project_version)"
[[ -n "$VERSION" ]] || fail "MARKETING_VERSION is missing from $PROJECT_FILE."

TAG="${1:-v$VERSION}"
EXPECTED_TAG="v$VERSION"
[[ "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] \
  || fail "Release tags must use vMAJOR.MINOR.PATCH, for example v0.1.6."
[[ "$TAG" == "$EXPECTED_TAG" ]] \
  || fail "Tag $TAG does not match MARKETING_VERSION $VERSION."

cd "$ROOT_DIR"

[[ -z "$(git status --porcelain --untracked-files=normal)" ]] \
  || fail "Commit or remove local changes before publishing a release."

gh auth status >/dev/null 2>&1 \
  || fail "GitHub CLI is not authenticated. Run: gh auth login"

if gh release view "$TAG" >/dev/null 2>&1; then
  fail "GitHub Release $TAG already exists."
fi

resolve_distribution_identity

REMOTE_TAG_OBJECT="$(git ls-remote --tags origin "refs/tags/$TAG" | awk 'NR == 1 { print $1 }')"
if [[ -n "$REMOTE_TAG_OBJECT" ]] && ! git rev-parse --verify --quiet "refs/tags/$TAG" >/dev/null; then
  git fetch origin "refs/tags/$TAG:refs/tags/$TAG"
fi

TAG_EXISTS=false
BUILD_ROOT="$ROOT_DIR"
if git rev-parse --verify --quiet "refs/tags/$TAG" >/dev/null; then
  TAG_EXISTS=true
  LOCAL_TAG_OBJECT="$(git rev-parse "refs/tags/$TAG")"
  if [[ -n "$REMOTE_TAG_OBJECT" && "$LOCAL_TAG_OBJECT" != "$REMOTE_TAG_OBJECT" ]]; then
    fail "Local and remote $TAG tags do not match. Resolve the tag mismatch before publishing."
  fi

  TAG_COMMIT="$(git rev-list -n 1 "$TAG")"
  HEAD_COMMIT="$(git rev-parse HEAD)"
  if [[ "$TAG_COMMIT" != "$HEAD_COMMIT" ]]; then
    TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/voiced-release.XXXXXX")"
    TEMP_WORKTREE="$TEMP_ROOT/source"
    git worktree add --detach "$TEMP_WORKTREE" "$TAG"
    BUILD_ROOT="$TEMP_WORKTREE"
    echo "Building the existing $TAG source in a temporary checkout."
  fi
fi

echo "Running release tests for $TAG."
xcodegen generate --spec "$BUILD_ROOT/project.yml"
xcodebuild \
  -project "$BUILD_ROOT/Voiced.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Debug \
  -derivedDataPath "$BUILD_ROOT/build/release-tests" \
  CODE_SIGNING_ALLOWED=NO \
  test

echo "Building, notarizing, and verifying $TAG with $IDENTITY."
VOICED_DEVELOPER_ID_IDENTITY="$IDENTITY" \
VOICED_NOTARY_PROFILE="$NOTARY_PROFILE" \
  "$BUILD_ROOT/script/package_release.sh" release

SOURCE_ARTIFACT="$BUILD_ROOT/dist/release/$APP_NAME-$VERSION.zip"
[[ -f "$SOURCE_ARTIFACT" ]] || fail "Expected release artifact was not created: $SOURCE_ARTIFACT"

PACKAGE_DIR="$ROOT_DIR/dist/release"
ARTIFACT_NAME="$APP_NAME-$VERSION.zip"
ARTIFACT="$PACKAGE_DIR/$ARTIFACT_NAME"
CHECKSUM="$ARTIFACT.sha256"
mkdir -p "$PACKAGE_DIR"
if [[ "$SOURCE_ARTIFACT" != "$ARTIFACT" ]]; then
  ditto "$SOURCE_ARTIFACT" "$ARTIFACT"
fi
(
  cd "$PACKAGE_DIR"
  shasum -a 256 "$ARTIFACT_NAME" > "$ARTIFACT_NAME.sha256"
)

if [[ "$TAG_EXISTS" == false ]]; then
  git tag -a "$TAG" -m "$APP_NAME $TAG"
fi

if [[ -z "$REMOTE_TAG_OBJECT" ]]; then
  git push origin "refs/tags/$TAG"
fi

gh release create "$TAG" \
  "$ARTIFACT" \
  "$CHECKSUM" \
  --verify-tag \
  --generate-notes \
  --latest \
  --notes "Download: $DOWNLOAD_URL" \
  --title "$APP_NAME $TAG"

LATEST_TAG="$(gh api "repos/$GITHUB_REPOSITORY/releases/latest" --jq '.tag_name')"
[[ "$LATEST_TAG" == "$TAG" ]] \
  || fail "Published $TAG, but GitHub reports $LATEST_TAG as the latest release."

echo "Published $APP_NAME $TAG."
echo "Download: $DOWNLOAD_URL"
echo "The download route refreshes its GitHub release lookup within five minutes."
