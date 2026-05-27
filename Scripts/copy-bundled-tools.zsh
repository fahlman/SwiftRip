#!/bin/zsh
set -euo pipefail

ARTIFACTS_ARCH="${SWIFTRIP_TOOLS_ARCH:-arm64}"
case "${ARTIFACTS_ARCH}" in
    arm64|x86_64)
        ;;
    *)
        echo "ERROR: Unsupported SwiftRipTools architecture: ${ARTIFACTS_ARCH}"
        echo "Supported architectures: arm64, x86_64"
        exit 64
        ;;
esac

ARTIFACTS_DIR="${SRCROOT}/SwiftRipTools/Artifacts/macos-${ARTIFACTS_ARCH}"
APP_MACOS_DIR="${TARGET_BUILD_DIR}/${EXECUTABLE_FOLDER_PATH}"
APP_FRAMEWORKS_DIR="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"

HANDBRAKE_SOURCE="${ARTIFACTS_DIR}/HandBrakeCLI"
LIBDVDCSS_SOURCE="${ARTIFACTS_DIR}/libdvdcss.2.dylib"

HANDBRAKE_DESTINATION="${APP_MACOS_DIR}/HandBrakeCLI"
LIBDVDCSS_FRAMEWORKS_DESTINATION="${APP_FRAMEWORKS_DIR}/libdvdcss.2.dylib"
STALE_LIBDVDCSS_MACOS_DESTINATION="${APP_MACOS_DIR}/libdvdcss.2.dylib"

echo "Copying SwiftRip tool artifacts..."
echo "Artifacts:  ${ARTIFACTS_DIR}"
echo "MacOS dir:  ${APP_MACOS_DIR}"
echo "Frameworks: ${APP_FRAMEWORKS_DIR}"

if [[ "${SWIFTRIP_SKIP_BUNDLED_TOOLS:-0}" == "1" ]]; then
    echo "Skipping bundled tool copy because SWIFTRIP_SKIP_BUNDLED_TOOLS=1."
    exit 0
fi

if [[ ! -f "${HANDBRAKE_SOURCE}" ]]; then
    echo "ERROR: Missing HandBrakeCLI artifact:"
    echo "${HANDBRAKE_SOURCE}"
    echo "Run SwiftRipTools/Scripts/build-swiftrip-tools.zsh first."
    exit 1
fi

if [[ ! -f "${LIBDVDCSS_SOURCE}" ]]; then
    echo "ERROR: Missing libdvdcss.2.dylib artifact:"
    echo "${LIBDVDCSS_SOURCE}"
    echo "Run SwiftRipTools/Scripts/build-swiftrip-tools.zsh first."
    exit 1
fi

mkdir -p "${APP_MACOS_DIR}"
mkdir -p "${APP_FRAMEWORKS_DIR}"

cp "${HANDBRAKE_SOURCE}" "${HANDBRAKE_DESTINATION}"
rm -f "${STALE_LIBDVDCSS_MACOS_DESTINATION}"
cp "${LIBDVDCSS_SOURCE}" "${LIBDVDCSS_FRAMEWORKS_DESTINATION}"

chmod 755 "${HANDBRAKE_DESTINATION}"
chmod 755 "${LIBDVDCSS_FRAMEWORKS_DESTINATION}"

if [[ "${CODE_SIGNING_ALLOWED:-NO}" == "YES" ]]; then
    if [[ -z "${EXPANDED_CODE_SIGN_IDENTITY:-}" || "${EXPANDED_CODE_SIGN_IDENTITY}" == "-" ]]; then
        echo "ERROR: CODE_SIGNING_ALLOWED=YES but EXPANDED_CODE_SIGN_IDENTITY is not set."
        exit 1
    fi

    CODE_SIGN_OPTIONS=(--force --sign "${EXPANDED_CODE_SIGN_IDENTITY}")
    if [[ "${ENABLE_HARDENED_RUNTIME:-NO}" == "YES" ]]; then
        CODE_SIGN_OPTIONS+=(--options runtime)
    fi

    echo ""
    echo "Signing bundled tool artifacts..."
    /usr/bin/codesign "${CODE_SIGN_OPTIONS[@]}" "${LIBDVDCSS_FRAMEWORKS_DESTINATION}"
    /usr/bin/codesign "${CODE_SIGN_OPTIONS[@]}" "${HANDBRAKE_DESTINATION}"
    /usr/bin/codesign --verify --strict --verbose=2 "${LIBDVDCSS_FRAMEWORKS_DESTINATION}"
    /usr/bin/codesign --verify --strict --verbose=2 "${HANDBRAKE_DESTINATION}"
else
    echo "Skipping bundled tool signing because CODE_SIGNING_ALLOWED is not YES."
fi

echo ""
echo "Verifying copied artifacts..."

file "${HANDBRAKE_DESTINATION}"
file "${LIBDVDCSS_FRAMEWORKS_DESTINATION}"

if ! file "${HANDBRAKE_DESTINATION}" | grep -q "${ARTIFACTS_ARCH}"; then
    echo "ERROR: Bundled HandBrakeCLI is not ${ARTIFACTS_ARCH}."
    exit 1
fi

if ! file "${LIBDVDCSS_FRAMEWORKS_DESTINATION}" | grep -q "${ARTIFACTS_ARCH}"; then
    echo "ERROR: Bundled Frameworks libdvdcss.2.dylib is not ${ARTIFACTS_ARCH}."
    exit 1
fi

if otool -L "${HANDBRAKE_DESTINATION}" | grep -q "/opt/local"; then
    echo "ERROR: Bundled HandBrakeCLI links against /opt/local libraries."
    exit 1
fi

if otool -L "${LIBDVDCSS_FRAMEWORKS_DESTINATION}" | grep -q "/opt/local"; then
    echo "ERROR: Frameworks libdvdcss.2.dylib links against /opt/local libraries."
    exit 1
fi

echo ""
echo "libdvdcss install names:"
otool -D "${LIBDVDCSS_FRAMEWORKS_DESTINATION}"

echo ""
echo "SwiftRip tool artifacts copied successfully."
