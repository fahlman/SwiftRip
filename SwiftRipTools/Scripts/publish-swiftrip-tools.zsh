#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TOOLS_DIR="$ROOT_DIR/SwiftRipTools"
MANIFEST_FILE="$TOOLS_DIR/Manifest/swiftrip-tools.json"
PACKAGE_DIR="$TOOLS_DIR/Packages"

json_value() {
    local key="$1"
    /usr/bin/plutil -extract "$key" raw -o - "$MANIFEST_FILE"
}

if [[ ! -f "$MANIFEST_FILE" ]]; then
    echo "ERROR: Missing SwiftRipTools manifest:"
    echo "$MANIFEST_FILE"
    exit 1
fi

ARTIFACT_NAME="$(json_value artifactName)"
EXPECTED_SHA256="$(json_value sha256)"
PACKAGE_PATH="$PACKAGE_DIR/$ARTIFACT_NAME"
RELEASE_URL="$(json_value url)"
RELEASE_TAG="$(basename "$(dirname "$RELEASE_URL")")"
REPOSITORY="fahlman/SwiftRip"

if [[ ! -f "$PACKAGE_PATH" ]]; then
    echo "ERROR: Missing package:"
    echo "$PACKAGE_PATH"
    echo ""
    echo "Create it first with:"
    echo "$TOOLS_DIR/Scripts/package-swiftrip-tools.zsh"
    exit 1
fi

ACTUAL_SHA256="$(shasum -a 256 "$PACKAGE_PATH" | awk '{print $1}')"
if [[ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]]; then
    echo "ERROR: Package checksum does not match manifest."
    echo "Expected: $EXPECTED_SHA256"
    echo "Actual:   $ACTUAL_SHA256"
    exit 1
fi

echo "SwiftRipTools publish"
echo "Repository: $REPOSITORY"
echo "Tag:        $RELEASE_TAG"
echo "Package:    $PACKAGE_PATH"
echo "SHA-256:    $ACTUAL_SHA256"

if command -v gh >/dev/null 2>&1; then
    echo ""
    echo "Publishing with GitHub CLI..."
    gh release create "$RELEASE_TAG" "$PACKAGE_PATH" \
        --repo "$REPOSITORY" \
        --title "$RELEASE_TAG" \
        --notes "SwiftRip bundled tool package. SHA-256: $ACTUAL_SHA256"
    exit 0
fi

echo ""
echo "GitHub CLI was not found, so publish this package in the browser:"
echo "1. Open: https://github.com/$REPOSITORY/releases/new?tag=$RELEASE_TAG"
echo "2. Set Release title to: $RELEASE_TAG"
echo "3. Attach this file:"
echo "$PACKAGE_PATH"
echo "4. Publish the release."
echo ""
echo "Opening the release page and revealing the package in Finder..."
open "https://github.com/$REPOSITORY/releases/new?tag=$RELEASE_TAG"
open -R "$PACKAGE_PATH"
