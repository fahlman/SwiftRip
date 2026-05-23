#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TOOLS_DIR="$ROOT_DIR/SwiftRipTools"
MANIFEST_FILE="$TOOLS_DIR/Manifest/swiftrip-tools.json"
DOWNLOAD_DIR="$TOOLS_DIR/Packages"
ARTIFACTS_DIR="$TOOLS_DIR/Artifacts"
VERIFY_SCRIPT="$TOOLS_DIR/Scripts/verify-swiftrip-tools.zsh"

json_value() {
    local key="$1"
    /usr/bin/plutil -extract "$key" raw -o - "$MANIFEST_FILE"
}

if [[ ! -f "$MANIFEST_FILE" ]]; then
    echo "ERROR: Missing SwiftRipTools manifest:"
    echo "$MANIFEST_FILE"
    exit 1
fi

VERSION="$(json_value version)"
ARTIFACT_NAME="$(json_value artifactName)"
ARTIFACT_URL="$(json_value url)"
EXPECTED_SHA256="$(json_value sha256)"
PACKAGE_PATH="$DOWNLOAD_DIR/$ARTIFACT_NAME"

echo "SwiftRipTools fetch"
echo "Root:     $ROOT_DIR"
echo "Manifest: $MANIFEST_FILE"
echo "Version:  $VERSION"
echo "Package:  $PACKAGE_PATH"

mkdir -p "$DOWNLOAD_DIR"

if [[ ! -f "$PACKAGE_PATH" ]]; then
    echo ""
    echo "Downloading SwiftRipTools package..."
    curl -fL "$ARTIFACT_URL" -o "$PACKAGE_PATH"
else
    echo ""
    echo "Using existing package: $PACKAGE_PATH"
fi

echo ""
echo "Verifying package checksum..."
ACTUAL_SHA256="$(shasum -a 256 "$PACKAGE_PATH" | awk '{print $1}')"
if [[ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]]; then
    echo "ERROR: SwiftRipTools package checksum mismatch."
    echo "Expected: $EXPECTED_SHA256"
    echo "Actual:   $ACTUAL_SHA256"
    exit 1
fi

echo ""
echo "Extracting SwiftRipTools artifacts..."
rm -rf "$ARTIFACTS_DIR/macos-arm64"
mkdir -p "$ARTIFACTS_DIR"
tar -xzf "$PACKAGE_PATH" -C "$ARTIFACTS_DIR"

echo ""
"$VERIFY_SCRIPT"

echo ""
echo "SwiftRipTools fetch complete."
