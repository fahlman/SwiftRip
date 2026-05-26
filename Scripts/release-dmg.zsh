#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/SwiftRip.xcodeproj"
SCHEME="SwiftRip"
CONFIGURATION="Release"
APP_NAME="SwiftRip"
VOLUME_NAME="SwiftRip"
RELEASE_ARCH="arm64"
RELEASE_TMP_ROOT="${TMPDIR:-/private/tmp}"
WORK_DIR="${SWIFTRIP_RELEASE_WORK_DIR:-${RELEASE_TMP_ROOT%/}/swiftrip-release-${USER:-user}}"
OUTPUT_DIR="$ROOT_DIR/dist"
TEAM_ID="${SWIFTRIP_TEAM_ID:-PUT2KYMV2W}"
SIGNING_IDENTITY="${SWIFTRIP_SIGNING_IDENTITY:-Developer ID Application}"
NOTARY_PROFILE="${SWIFTRIP_NOTARY_PROFILE:-}"
NOTARY_APPLE_ID="${SWIFTRIP_NOTARY_APPLE_ID:-}"
NOTARY_PASSWORD="${SWIFTRIP_NOTARY_PASSWORD:-}"
NOTARY_TEAM_ID="${SWIFTRIP_NOTARY_TEAM_ID:-$TEAM_ID}"
SKIP_NOTARIZATION=false
typeset -a NOTARY_ARGS

usage() {
    cat <<'USAGE'
Usage: Scripts/release-dmg.zsh [options]

Build, sign, package, notarize, and staple a SwiftRip release DMG.

Options:
  --skip-notarization        Build and sign the DMG without submitting to Apple.
                             Still requires Developer ID signing.
  --notary-profile NAME      notarytool keychain profile name.
  --apple-id EMAIL           Apple ID for notarytool.
  --password PASSWORD        App-specific password or keychain password reference.
  --team-id TEAMID           Apple Developer Team ID.
  --signing-identity NAME    Code signing identity. Defaults to Developer ID Application.
  --output-dir PATH          Directory for the final DMG. Defaults to ./dist.
  -h, --help                 Show this help.

Environment variables:
  SWIFTRIP_TEAM_ID
  SWIFTRIP_SIGNING_IDENTITY
  SWIFTRIP_NOTARY_PROFILE
  SWIFTRIP_NOTARY_APPLE_ID
  SWIFTRIP_NOTARY_PASSWORD
  SWIFTRIP_NOTARY_TEAM_ID
  SWIFTRIP_RELEASE_WORK_DIR

Notarization uses either --notary-profile, or --apple-id plus --password.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-notarization)
            SKIP_NOTARIZATION=true
            shift
            ;;
        --notary-profile)
            NOTARY_PROFILE="${2:-}"
            shift 2
            ;;
        --apple-id)
            NOTARY_APPLE_ID="${2:-}"
            shift 2
            ;;
        --password)
            NOTARY_PASSWORD="${2:-}"
            shift 2
            ;;
        --team-id)
            TEAM_ID="${2:-}"
            NOTARY_TEAM_ID="${2:-}"
            shift 2
            ;;
        --signing-identity)
            SIGNING_IDENTITY="${2:-}"
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
            exit 1
            ;;
    esac
done

require_command() {
    local command_path="$1"
    if [[ ! -x "$command_path" ]]; then
        echo "ERROR: Missing required command: $command_path"
        exit 1
    fi
}

require_value() {
    local name="$1"
    local value="$2"
    if [[ -z "$value" ]]; then
        echo "ERROR: Missing required value: $name"
        exit 1
    fi
}

codesign_entitlements() {
    local target_path="$1"
    local output_path="$2"
    /usr/bin/codesign -d --entitlements - "$target_path" > "$output_path" 2>/dev/null
}

assert_no_debug_entitlement() {
    local entitlements_path="$1"
    if /usr/bin/grep -q "com.apple.security.get-task-allow" "$entitlements_path"; then
        echo "ERROR: Release app has the debug get-task-allow entitlement."
        echo "$entitlements_path"
        exit 1
    fi
}

assert_entitlement_present() {
    local entitlements_path="$1"
    local entitlement="$2"
    if ! /usr/bin/grep -q "$entitlement" "$entitlements_path"; then
        echo "ERROR: Missing expected entitlement: $entitlement"
        echo "$entitlements_path"
        exit 1
    fi
}

assert_entitlement_absent() {
    local entitlements_path="$1"
    local entitlement="$2"
    if /usr/bin/grep -q "$entitlement" "$entitlements_path"; then
        echo "ERROR: Found unwanted entitlement: $entitlement"
        echo "$entitlements_path"
        exit 1
    fi
}

signing_identity_available() {
    /usr/bin/security find-identity -v -p codesigning | /usr/bin/grep -Fq "$SIGNING_IDENTITY"
}

require_value "TEAM_ID" "$TEAM_ID"
require_value "SIGNING_IDENTITY" "$SIGNING_IDENTITY"
require_command /usr/bin/xcodebuild
require_command /usr/bin/codesign
require_command /usr/bin/file
require_command /usr/bin/hdiutil
require_command /usr/bin/xattr
require_command /usr/sbin/spctl
require_command /usr/bin/xcrun

if [[ "$SKIP_NOTARIZATION" == false ]]; then
    if [[ -n "$NOTARY_PROFILE" ]]; then
        NOTARY_ARGS=(--keychain-profile "$NOTARY_PROFILE")
    elif [[ -n "$NOTARY_APPLE_ID" && -n "$NOTARY_PASSWORD" ]]; then
        NOTARY_ARGS=(--apple-id "$NOTARY_APPLE_ID" --password "$NOTARY_PASSWORD" --team-id "$NOTARY_TEAM_ID")
    else
        echo "ERROR: Notarization needs --notary-profile, or --apple-id plus --password."
        echo "Use --skip-notarization for a local packaging check without Apple notarization."
        exit 1
    fi
fi

if ! signing_identity_available; then
    echo "ERROR: Code signing identity was not found in the keychain:"
    echo "$SIGNING_IDENTITY"
    echo ""
    echo "Available identities:"
    /usr/bin/security find-identity -v -p codesigning
    exit 1
fi

echo "SwiftRip release DMG"
echo "Root:             $ROOT_DIR"
echo "Configuration:    $CONFIGURATION"
echo "Team ID:          $TEAM_ID"
echo "Signing identity: $SIGNING_IDENTITY"
echo "Architecture:     $RELEASE_ARCH"
echo "Work dir:         $WORK_DIR"
echo "Output:           $OUTPUT_DIR"

"$ROOT_DIR/SwiftRipTools/Scripts/verify-swiftrip-tools.zsh"

case "$WORK_DIR" in
    "/"|"$HOME"|"$ROOT_DIR")
        echo "ERROR: Refusing to use unsafe release work directory: $WORK_DIR"
        exit 1
        ;;
esac

/bin/rm -rf "$WORK_DIR"
/bin/mkdir -p "$WORK_DIR" "$OUTPUT_DIR"

DERIVED_DATA_PATH="$WORK_DIR/DerivedData"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$APP_NAME.app"
APP_ENTITLEMENTS_SOURCE="$ROOT_DIR/SwiftRip/SwiftRip.entitlements"

echo ""
echo "Building release app..."
/usr/bin/xcodebuild build \
    -quiet \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    ARCHS="$RELEASE_ARCH" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO

if [[ ! -d "$APP_PATH" ]]; then
    echo "ERROR: Built app was not found:"
    echo "$APP_PATH"
    exit 1
fi

echo ""
echo "Removing extended attributes from app bundle..."
/usr/bin/xattr -cr "$APP_PATH"

VERSION="$(/usr/bin/plutil -extract CFBundleShortVersionString raw -o - "$APP_PATH/Contents/Info.plist")"
BUILD="$(/usr/bin/plutil -extract CFBundleVersion raw -o - "$APP_PATH/Contents/Info.plist")"
DMG_NAME="$APP_NAME-$VERSION-$BUILD.dmg"
DMG_PATH="$OUTPUT_DIR/$DMG_NAME"
APP_ENTITLEMENTS="$WORK_DIR/$APP_NAME.entitlements"
APP_EXECUTABLE="$APP_PATH/Contents/MacOS/$APP_NAME"

echo ""
echo "Signing bundled executable code..."
/usr/bin/codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp "$APP_PATH/Contents/Frameworks/libdvdcss.2.dylib"
/usr/bin/codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp "$APP_PATH/Contents/MacOS/HandBrakeCLI"

echo ""
echo "Signing app bundle..."
/usr/bin/codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp --entitlements "$APP_ENTITLEMENTS_SOURCE" "$APP_PATH"

echo ""
echo "Verifying app signature and entitlements..."
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo ""
echo "Verifying app architecture..."
/usr/bin/file "$APP_EXECUTABLE"
if ! /usr/bin/file "$APP_EXECUTABLE" | /usr/bin/grep -q "$RELEASE_ARCH"; then
    echo "ERROR: App executable is not $RELEASE_ARCH."
    exit 1
fi
if /usr/bin/file "$APP_EXECUTABLE" | /usr/bin/grep -q "x86_64"; then
    echo "ERROR: App executable is universal, but bundled SwiftRipTools are $RELEASE_ARCH-only."
    exit 1
fi

codesign_entitlements "$APP_PATH" "$APP_ENTITLEMENTS"
assert_no_debug_entitlement "$APP_ENTITLEMENTS"
assert_entitlement_present "$APP_ENTITLEMENTS" "com.apple.security.app-sandbox"
assert_entitlement_present "$APP_ENTITLEMENTS" "com.apple.security.files.user-selected.read-write"
assert_entitlement_present "$APP_ENTITLEMENTS" "com.apple.security.files.bookmarks.app-scope"
assert_entitlement_absent "$APP_ENTITLEMENTS" "com.apple.security.files.movies.read-write"
assert_entitlement_absent "$APP_ENTITLEMENTS" "com.apple.security.temporary-exception.shared-preference.read-write"

echo ""
echo "Verifying bundled executable code..."
/usr/bin/codesign --verify --strict --verbose=2 "$APP_PATH/Contents/MacOS/HandBrakeCLI"
/usr/bin/codesign --verify --strict --verbose=2 "$APP_PATH/Contents/Frameworks/libdvdcss.2.dylib"

DMG_ROOT="$WORK_DIR/dmg-root"
/bin/mkdir -p "$DMG_ROOT"
/usr/bin/ditto "$APP_PATH" "$DMG_ROOT/$APP_NAME.app"
/bin/ln -s /Applications "$DMG_ROOT/Applications"
/bin/rm -f "$DMG_PATH"

echo ""
echo "Creating DMG..."
/usr/bin/hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$DMG_ROOT" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -ov \
    "$DMG_PATH"

echo ""
echo "Signing DMG..."
/usr/bin/codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$DMG_PATH"
/usr/bin/codesign --verify --verbose=2 "$DMG_PATH"
/usr/bin/hdiutil verify "$DMG_PATH"

if [[ "$SKIP_NOTARIZATION" == true ]]; then
    echo ""
    echo "Skipped notarization."
    echo "DMG: $DMG_PATH"
    exit 0
fi

echo ""
echo "Submitting DMG for notarization..."
/usr/bin/xcrun notarytool submit "$DMG_PATH" --wait "${NOTARY_ARGS[@]}"

echo ""
echo "Stapling notarization ticket..."
/usr/bin/xcrun stapler staple "$DMG_PATH"
/usr/bin/xcrun stapler validate "$DMG_PATH"

echo ""
echo "Assessing notarized DMG with Gatekeeper..."
/usr/sbin/spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG_PATH"

echo ""
echo "Release DMG is ready:"
echo "$DMG_PATH"
