#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RELEASE_COMMON_SCRIPT="$ROOT_DIR/Scripts/lib/release-common.zsh"
PROJECT_PATH="$ROOT_DIR/SwiftRip.xcodeproj"
SCHEME="SwiftRip"
CONFIGURATION="Release"
APP_NAME="SwiftRip"
RELEASE_ARCH="universal"
RELEASE_TMP_ROOT="${TMPDIR:-/private/tmp}"
OUTPUT_DIR="$ROOT_DIR/dist"
TEAM_ID="${SWIFTRIP_TEAM_ID:-PUT2KYMV2W}"
SIGNING_IDENTITY="${SWIFTRIP_SIGNING_IDENTITY:-Developer ID Application}"
NOTARY_PROFILE="${SWIFTRIP_NOTARY_PROFILE:-}"
NOTARY_APPLE_ID="${SWIFTRIP_NOTARY_APPLE_ID:-}"
NOTARY_PASSWORD="${SWIFTRIP_NOTARY_PASSWORD:-}"
SOURCE_APP_PATH="${SWIFTRIP_RELEASE_APP_PATH:-}"
SPARKLE_FEED_URL="${SWIFTRIP_SPARKLE_FEED_URL:-https://fahlman.github.io/SwiftRip/appcast.xml}"
SKIP_NOTARIZATION=false
typeset -a NOTARY_ARGS

# shellcheck source=/dev/null
source "$RELEASE_COMMON_SCRIPT"

usage() {
    cat <<'USAGE'
Usage: Scripts/release-zip.zsh [options]

Package, notarize, staple, and verify a universal SwiftRip.app ZIP.

By default, this script uses SWIFTRIP_RELEASE_APP_PATH. If it is not present, it builds a local
universal Release app and signs it with Developer ID.

Options:
  --app-path PATH           Signed app, exported app directory, or ZIP to package.
  --skip-notarization       Build/sign/package without submitting to Apple.
  --notary-profile NAME     notarytool keychain profile name.
  --team-id TEAMID          Apple Developer Team ID.
  --signing-identity NAME   Code signing identity for local fallback builds.
  --output-dir PATH         Directory for the final ZIP. Defaults to ./dist.
  -h, --help                Show this help.

Environment variables:
  SWIFTRIP_RELEASE_APP_PATH
  SWIFTRIP_TEAM_ID
  SWIFTRIP_SIGNING_IDENTITY
  SWIFTRIP_NOTARY_PROFILE
  SWIFTRIP_NOTARY_APPLE_ID
  SWIFTRIP_NOTARY_PASSWORD
  SWIFTRIP_SPARKLE_FEED_URL
  SWIFTRIP_RELEASE_WORK_DIR

Notarization requires a notarytool keychain profile or Apple notarization
credentials provided through environment variables.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --app-path)
            SOURCE_APP_PATH="${2:-}"
            shift 2
            ;;
        --skip-notarization)
            SKIP_NOTARIZATION=true
            shift
            ;;
        --notary-profile)
            NOTARY_PROFILE="${2:-}"
            shift 2
            ;;
        --team-id)
            TEAM_ID="${2:-}"
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
            exit 64
            ;;
    esac
done

WORK_DIR="${SWIFTRIP_RELEASE_WORK_DIR:-${RELEASE_TMP_ROOT%/}/swiftrip-release-${USER:-user}-zip}"
APP_ENTITLEMENTS_SOURCE="$ROOT_DIR/SwiftRip/SwiftRip.entitlements"
APP_SIGNING_ENTITLEMENTS="$WORK_DIR/$APP_NAME-signing.entitlements"

require_value "TEAM_ID" "$TEAM_ID"
require_command /usr/bin/codesign
require_command /usr/bin/ditto
require_command /usr/bin/file
require_command /usr/bin/xattr
require_command /usr/bin/xcrun
require_command /usr/sbin/spctl

if [[ "$SKIP_NOTARIZATION" == false ]]; then
    if [[ -n "$NOTARY_PROFILE" ]]; then
        NOTARY_ARGS=(--keychain-profile "$NOTARY_PROFILE")
    elif [[ -n "$NOTARY_APPLE_ID" && -n "$NOTARY_PASSWORD" ]]; then
        NOTARY_ARGS=(--apple-id "$NOTARY_APPLE_ID" --password "$NOTARY_PASSWORD" --team-id "$TEAM_ID")
    else
        echo "ERROR: Notarization needs --notary-profile."
        echo "For GitHub Actions, set SWIFTRIP_NOTARY_APPLE_ID and SWIFTRIP_NOTARY_PASSWORD as secrets."
        echo "Use --skip-notarization for a local packaging check without Apple notarization."
        exit 1
    fi
fi

refuse_unsafe_path "$WORK_DIR" "release work directory" "$ROOT_DIR"

/bin/rm -rf "$WORK_DIR"
/bin/mkdir -p "$WORK_DIR" "$OUTPUT_DIR"

copy_source_app() {
    local source_path="$1"
    local destination_root="$2"
    local extracted_root="$destination_root/extracted"
    local found_app

    /bin/mkdir -p "$extracted_root"

    if [[ -d "$source_path" && "$source_path" == *.app ]]; then
        /usr/bin/ditto "$source_path" "$destination_root/$APP_NAME.app"
        echo "$destination_root/$APP_NAME.app"
        return
    fi

    if [[ -d "$source_path" ]]; then
        found_app="$(/usr/bin/find "$source_path" -maxdepth 5 -name "$APP_NAME.app" -type d -print -quit)"
        if [[ -n "$found_app" ]]; then
            /usr/bin/ditto "$found_app" "$destination_root/$APP_NAME.app"
            echo "$destination_root/$APP_NAME.app"
            return
        fi
    fi

    if [[ -f "$source_path" && "$source_path" == *.zip ]]; then
        /usr/bin/ditto -x -k "$source_path" "$extracted_root"
        found_app="$(/usr/bin/find "$extracted_root" -maxdepth 5 -name "$APP_NAME.app" -type d -print -quit)"
        if [[ -n "$found_app" ]]; then
            /usr/bin/ditto "$found_app" "$destination_root/$APP_NAME.app"
            echo "$destination_root/$APP_NAME.app"
            return
        fi
    fi

    echo "ERROR: Could not find $APP_NAME.app in:"
    echo "$source_path"
    exit 1
}

sign_local_app() {
    local app_path="$1"
    local bundle_identifier="$2"
    local sparkle_framework="$app_path/Contents/Frameworks/Sparkle.framework"

    require_value "SIGNING_IDENTITY" "$SIGNING_IDENTITY"
    if ! signing_identity_available "$SIGNING_IDENTITY"; then
        echo "ERROR: Code signing identity was not found in the keychain:"
        echo "$SIGNING_IDENTITY"
        echo ""
        echo "Available identities:"
        /usr/bin/security find-identity -v -p codesigning
        exit 1
    fi

    /usr/bin/sed "s|[$](PRODUCT_BUNDLE_IDENTIFIER)|$bundle_identifier|g" "$APP_ENTITLEMENTS_SOURCE" > "$APP_SIGNING_ENTITLEMENTS"

    echo ""
    echo "Signing bundled executable code..."
    /usr/bin/codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp "$app_path/Contents/Frameworks/libdvdcss.2.dylib"
    /usr/bin/codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp "$app_path/Contents/MacOS/HandBrakeCLI"

    if [[ -d "$sparkle_framework" ]]; then
        echo ""
        echo "Signing Sparkle framework..."
        local sparkle_current="$sparkle_framework/Versions/Current"
        local sparkle_downloader_xpc="$sparkle_current/XPCServices/Downloader.xpc"

        if [[ -e "$sparkle_downloader_xpc" || -L "$sparkle_downloader_xpc" ]]; then
            /bin/rm -rf "$sparkle_downloader_xpc"
        fi

        if [[ -d "$sparkle_current/XPCServices/Installer.xpc" ]]; then
            /usr/bin/codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp "$sparkle_current/XPCServices/Installer.xpc"
        fi
        if [[ -e "$sparkle_current/Autoupdate" ]]; then
            /usr/bin/codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp "$sparkle_current/Autoupdate"
        fi
        if [[ -d "$sparkle_current/Updater.app" ]]; then
            /usr/bin/codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp "$sparkle_current/Updater.app"
        fi

        /usr/bin/codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp "$sparkle_framework"
    fi

    echo ""
    echo "Signing app bundle..."
    /usr/bin/codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp --entitlements "$APP_SIGNING_ENTITLEMENTS" "$app_path"
}

build_local_app() {
    local derived_data_path="$WORK_DIR/DerivedData"
    local app_path="$derived_data_path/Build/Products/$CONFIGURATION/$APP_NAME.app"

    require_command /usr/bin/xcodebuild

    echo ""
    echo "Building local universal release app..."
    /usr/bin/xcodebuild build \
        -quiet \
        -project "$PROJECT_PATH" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -destination "generic/platform=macOS" \
        -derivedDataPath "$derived_data_path" \
        ARCHS="arm64 x86_64" \
        SWIFTRIP_TOOLS_ARCH=universal \
        SWIFTRIP_SPARKLE_FEED_URL="$SPARKLE_FEED_URL" \
        ENABLE_USER_SCRIPT_SANDBOXING=NO \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO

    if [[ ! -d "$app_path" ]]; then
        echo "ERROR: Built app was not found:"
        echo "$app_path"
        exit 1
    fi

    BUILT_APP_PATH="$app_path"
}

if [[ -n "$SOURCE_APP_PATH" ]]; then
    echo "SwiftRip ZIP release"
    echo "Source app:      $SOURCE_APP_PATH"
    APP_PATH="$(copy_source_app "$SOURCE_APP_PATH" "$WORK_DIR")"
    BUILT_LOCALLY=false
else
    echo "SwiftRip ZIP release"
    echo "Source app:      local fallback build"
    build_local_app
    APP_PATH="$BUILT_APP_PATH"
    BUILT_LOCALLY=true
fi

echo "Root:            $ROOT_DIR"
echo "Team ID:         $TEAM_ID"
echo "Architecture:    $RELEASE_ARCH"
echo "Sparkle feed:    $SPARKLE_FEED_URL"
echo "Work dir:        $WORK_DIR"
echo "Output:          $OUTPUT_DIR"

echo ""
echo "Removing extended attributes from app bundle..."
/usr/bin/xattr -cr "$APP_PATH"

VERSION="$(/usr/bin/plutil -extract CFBundleShortVersionString raw -o - "$APP_PATH/Contents/Info.plist")"
BUNDLE_IDENTIFIER="$(/usr/bin/plutil -extract CFBundleIdentifier raw -o - "$APP_PATH/Contents/Info.plist")"
APP_SPARKLE_FEED_URL="$(/usr/bin/plutil -extract SUFeedURL raw -o - "$APP_PATH/Contents/Info.plist")"
ZIP_NAME="$APP_NAME-$VERSION.zip"
ZIP_PATH="$OUTPUT_DIR/$ZIP_NAME"
NOTARY_ZIP_PATH="$WORK_DIR/$APP_NAME-$VERSION-notary.zip"
MANIFEST_PATH="$OUTPUT_DIR/$APP_NAME-$VERSION-manifest.json"
APP_ENTITLEMENTS="$WORK_DIR/$APP_NAME.entitlements"
APP_EXECUTABLE="$APP_PATH/Contents/MacOS/$APP_NAME"
HANDBRAKE_CLI="$APP_PATH/Contents/MacOS/HandBrakeCLI"
LIBDVDCSS="$APP_PATH/Contents/Frameworks/libdvdcss.2.dylib"
SPARKLE_FRAMEWORK="$APP_PATH/Contents/Frameworks/Sparkle.framework"

if [[ "$APP_SPARKLE_FEED_URL" != "$SPARKLE_FEED_URL" ]]; then
    echo "ERROR: App has the wrong Sparkle feed URL."
    echo "Expected: $SPARKLE_FEED_URL"
    echo "Actual:   $APP_SPARKLE_FEED_URL"
    exit 1
fi

if [[ "$BUILT_LOCALLY" == true ]]; then
    sign_local_app "$APP_PATH" "$BUNDLE_IDENTIFIER"
fi

echo ""
echo "Verifying app signature and entitlements..."
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign_entitlements "$APP_PATH" "$APP_ENTITLEMENTS"
assert_no_debug_entitlement "$APP_ENTITLEMENTS"
assert_entitlement_present "$APP_ENTITLEMENTS" "com.apple.security.app-sandbox"
assert_entitlement_present "$APP_ENTITLEMENTS" "com.apple.security.files.user-selected.read-write"
assert_entitlement_present "$APP_ENTITLEMENTS" "com.apple.security.files.bookmarks.app-scope"
assert_entitlement_present "$APP_ENTITLEMENTS" "com.apple.security.network.client"
assert_entitlement_present "$APP_ENTITLEMENTS" "com.apple.security.temporary-exception.mach-lookup.global-name"
assert_entitlement_present "$APP_ENTITLEMENTS" "$BUNDLE_IDENTIFIER-spks"
assert_entitlement_present "$APP_ENTITLEMENTS" "$BUNDLE_IDENTIFIER-spki"
assert_entitlement_absent "$APP_ENTITLEMENTS" "com.apple.security.files.movies.read-write"
assert_entitlement_absent "$APP_ENTITLEMENTS" "com.apple.security.temporary-exception.shared-preference.read-write"
assert_entitlement_absent "$APP_ENTITLEMENTS" "PRODUCT_BUNDLE_IDENTIFIER"

echo ""
echo "Verifying universal app architecture..."
/usr/bin/file "$APP_EXECUTABLE"
for expected_arch in arm64 x86_64; do
    if ! /usr/bin/file "$APP_EXECUTABLE" | /usr/bin/grep -q "$expected_arch"; then
        echo "ERROR: App executable is missing $expected_arch."
        exit 1
    fi
done

echo ""
echo "Verifying bundled executable code..."
/usr/bin/codesign --verify --strict --verbose=2 "$HANDBRAKE_CLI"
/usr/bin/codesign --verify --strict --verbose=2 "$LIBDVDCSS"
if [[ -d "$SPARKLE_FRAMEWORK" ]]; then
    /usr/bin/codesign --verify --deep --strict --verbose=2 "$SPARKLE_FRAMEWORK"
fi

/usr/bin/file "$HANDBRAKE_CLI"
/usr/bin/file "$LIBDVDCSS"
for expected_arch in arm64 x86_64; do
    if ! /usr/bin/file "$HANDBRAKE_CLI" | /usr/bin/grep -q "$expected_arch"; then
        echo "ERROR: Universal HandBrakeCLI is missing $expected_arch."
        exit 1
    fi

    if ! /usr/bin/file "$LIBDVDCSS" | /usr/bin/grep -q "$expected_arch"; then
        echo "ERROR: Universal libdvdcss.2.dylib is missing $expected_arch."
        exit 1
    fi
done

if /usr/bin/otool -L "$HANDBRAKE_CLI" | /usr/bin/grep -q "/opt/local"; then
    echo "ERROR: Bundled HandBrakeCLI links against /opt/local libraries."
    exit 1
fi

if /usr/bin/otool -L "$LIBDVDCSS" | /usr/bin/grep -q "/opt/local"; then
    echo "ERROR: Frameworks libdvdcss.2.dylib links against /opt/local libraries."
    exit 1
fi

/bin/rm -f "$ZIP_PATH" "$NOTARY_ZIP_PATH"

echo ""
echo "Creating notarization ZIP..."
/usr/bin/ditto -c -k --keepParent "$APP_PATH" "$NOTARY_ZIP_PATH"

if [[ "$SKIP_NOTARIZATION" == true ]]; then
    /bin/cp "$NOTARY_ZIP_PATH" "$ZIP_PATH"
    write_zip_release_manifest \
        "$MANIFEST_PATH" \
        "$APP_NAME" \
        "$VERSION" \
        "$BUNDLE_IDENTIFIER" \
        "$RELEASE_ARCH" \
        "$SPARKLE_FEED_URL" \
        "$APP_PATH" \
        "$ZIP_PATH" \
        false
    echo "Release manifest: $MANIFEST_PATH"
    echo "Skipped notarization."
    echo "ZIP: $ZIP_PATH"
    exit 0
fi

echo ""
echo "Submitting ZIP for notarization..."
/usr/bin/xcrun notarytool submit "$NOTARY_ZIP_PATH" --wait "${NOTARY_ARGS[@]}"

echo ""
echo "Stapling notarization ticket to app..."
/usr/bin/xcrun stapler staple "$APP_PATH"
/usr/bin/xcrun stapler validate "$APP_PATH"

echo ""
echo "Assessing notarized app with Gatekeeper..."
/usr/sbin/spctl --assess --type execute --verbose=4 "$APP_PATH"

echo ""
echo "Creating final ZIP..."
/usr/bin/ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo ""
echo "Release ZIP is ready:"
echo "$ZIP_PATH"
write_zip_release_manifest \
    "$MANIFEST_PATH" \
    "$APP_NAME" \
    "$VERSION" \
    "$BUNDLE_IDENTIFIER" \
    "$RELEASE_ARCH" \
    "$SPARKLE_FEED_URL" \
    "$APP_PATH" \
    "$ZIP_PATH" \
    true
echo "Release manifest:"
echo "$MANIFEST_PATH"
