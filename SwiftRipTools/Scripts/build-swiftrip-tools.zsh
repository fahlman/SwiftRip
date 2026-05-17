#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TOOLS_DIR="$ROOT_DIR/SwiftRipTools"
SCRIPTS_DIR="$TOOLS_DIR/Scripts"
ARTIFACTS_DIR="$TOOLS_DIR/Artifacts/macos-arm64"

echo "SwiftRipTools build"
echo "Root:      $ROOT_DIR"
echo "Tools:     $TOOLS_DIR"
echo "Scripts:   $SCRIPTS_DIR"
echo "Artifacts: $ARTIFACTS_DIR"
echo "Arch:      arm64"

mkdir -p "$ARTIFACTS_DIR"

echo ""
echo "Building libdvdcss..."
"$SCRIPTS_DIR/build-libdvdcss.zsh"

echo ""
echo "Building HandBrakeCLI..."
"$SCRIPTS_DIR/build-handbrakecli.zsh"

echo ""
echo "Final artifact check:"
ls -lh "$ARTIFACTS_DIR"

echo ""
echo "HandBrakeCLI:"
file "$ARTIFACTS_DIR/HandBrakeCLI"
if ! file "$ARTIFACTS_DIR/HandBrakeCLI" | grep -q "arm64"; then
    echo "ERROR: HandBrakeCLI is not arm64."
    exit 1
fi
if otool -L "$ARTIFACTS_DIR/HandBrakeCLI" | grep -q "/opt/local"; then
    echo "ERROR: HandBrakeCLI links against /opt/local libraries."
    exit 1
fi

echo ""
echo "libdvdcss.2.dylib:"
file "$ARTIFACTS_DIR/libdvdcss.2.dylib"
if ! file "$ARTIFACTS_DIR/libdvdcss.2.dylib" | grep -q "arm64"; then
    echo "ERROR: libdvdcss.2.dylib is not arm64."
    exit 1
fi
if otool -L "$ARTIFACTS_DIR/libdvdcss.2.dylib" | grep -q "/opt/local"; then
    echo "ERROR: libdvdcss.2.dylib links against /opt/local libraries."
    exit 1
fi
otool -D "$ARTIFACTS_DIR/libdvdcss.2.dylib"

echo ""
echo "SwiftRipTools build complete."
