#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RELEASE_COMMON_SCRIPT="$ROOT_DIR/Scripts/lib/release-common.zsh"
APP_PATH=""
DVD_PATH=""
OUTPUT_DIR=""

# shellcheck source=/dev/null
source "$RELEASE_COMMON_SCRIPT"

usage() {
    cat <<'USAGE'
Usage: Scripts/signed-sandbox-rip-smoke.zsh --app PATH [--dvd PATH] [--output-dir PATH]

Checks that a signed SwiftRip.app has the expected sandbox entitlements and
bundled executable signatures before a real manual DVD smoke test.

Options:
  --app PATH          Signed SwiftRip.app to verify.
  --dvd PATH          Optional mounted DVD/folder expected to contain VIDEO_TS.
  --output-dir PATH   Optional output directory to use during the manual test.
  -h, --help          Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --app)
            APP_PATH="${2:-}"
            shift 2
            ;;
        --dvd)
            DVD_PATH="${2:-}"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="${2:-}"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1"
            echo ""
            usage
            exit 64
            ;;
    esac
done

require_value "APP_PATH" "$APP_PATH"
require_command /usr/bin/codesign
require_command /usr/bin/file
require_command /usr/bin/grep
require_command /usr/bin/otool
require_command /usr/bin/plutil

if [[ ! -d "$APP_PATH" ]]; then
    echo "ERROR: App bundle not found:"
    echo "$APP_PATH"
    exit 1
fi

APP_INFO_PLIST="$APP_PATH/Contents/Info.plist"
APP_NAME="$(/usr/bin/plutil -extract CFBundleName raw -o - "$APP_INFO_PLIST")"
APP_EXECUTABLE_NAME="$(/usr/bin/plutil -extract CFBundleExecutable raw -o - "$APP_INFO_PLIST")"
APP_EXECUTABLE="$APP_PATH/Contents/MacOS/$APP_EXECUTABLE_NAME"
HAND_BRAKE_CLI="$APP_PATH/Contents/MacOS/HandBrakeCLI"
LIBDVDCSS="$APP_PATH/Contents/Frameworks/libdvdcss.2.dylib"
ENTITLEMENTS_PATH="${TMPDIR:-/private/tmp}/swiftrip-smoke-entitlements-$$.plist"

cleanup() {
    /bin/rm -f "$ENTITLEMENTS_PATH"
}
trap cleanup EXIT

require_executable "$APP_EXECUTABLE"
require_executable "$HAND_BRAKE_CLI"
require_file "$LIBDVDCSS" "bundled libdvdcss"

if [[ -n "$DVD_PATH" && ! -d "$DVD_PATH/VIDEO_TS" ]]; then
    echo "ERROR: DVD path does not contain VIDEO_TS:"
    echo "$DVD_PATH"
    exit 1
fi

if [[ -n "$OUTPUT_DIR" && ! -d "$OUTPUT_DIR" ]]; then
    echo "ERROR: Output directory does not exist:"
    echo "$OUTPUT_DIR"
    exit 1
fi

echo "SwiftRip signed sandbox smoke check"
echo "App:        $APP_PATH"
echo "Executable: $APP_EXECUTABLE"
echo "DVD:        ${DVD_PATH:-not supplied}"
echo "Output dir: ${OUTPUT_DIR:-not supplied}"

echo ""
echo "Verifying app signature..."
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo ""
echo "Checking app entitlements..."
/usr/bin/codesign -d --entitlements - "$APP_PATH" > "$ENTITLEMENTS_PATH" 2>/dev/null
/usr/bin/grep -q "com.apple.security.app-sandbox" "$ENTITLEMENTS_PATH"
/usr/bin/grep -q "com.apple.security.files.user-selected.read-write" "$ENTITLEMENTS_PATH"
/usr/bin/grep -q "com.apple.security.files.bookmarks.app-scope" "$ENTITLEMENTS_PATH"
if /usr/bin/grep -q "com.apple.security.files.movies.read-write" "$ENTITLEMENTS_PATH"; then
    echo "ERROR: App still has broad Movies entitlement."
    exit 1
fi

echo ""
echo "Verifying bundled executable signatures..."
/usr/bin/codesign --verify --strict --verbose=2 "$HAND_BRAKE_CLI"
/usr/bin/codesign --verify --strict --verbose=2 "$LIBDVDCSS"

echo ""
echo "Checking bundled executable linkage..."
/usr/bin/file "$APP_EXECUTABLE"
/usr/bin/file "$HAND_BRAKE_CLI"
/usr/bin/file "$LIBDVDCSS"
if /usr/bin/otool -L "$HAND_BRAKE_CLI" | /usr/bin/grep -q "/opt/local"; then
    echo "ERROR: HandBrakeCLI links against /opt/local libraries."
    exit 1
fi
if /usr/bin/otool -L "$LIBDVDCSS" | /usr/bin/grep -q "/opt/local"; then
    echo "ERROR: libdvdcss links against /opt/local libraries."
    exit 1
fi

echo ""
echo "Preflight passed."
echo "Manual signed/sandboxed rip test:"
echo "1. Launch the app with: open -n $(printf '%q' "$APP_PATH")"
if [[ -n "$DVD_PATH" ]]; then
    echo "2. Choose DVD path: $DVD_PATH"
else
    echo "2. Choose a real mounted DVD or DVD folder that contains VIDEO_TS."
fi
if [[ -n "$OUTPUT_DIR" ]]; then
    echo "3. Choose output folder: $OUTPUT_DIR"
else
    echo "3. Choose an output folder through the app so macOS grants sandbox access."
fi
echo "4. Run one short rip and confirm the movie file is created on the first attempt."
