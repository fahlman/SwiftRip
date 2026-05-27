#!/bin/zsh
set -euo pipefail

requested_arch="${SWIFTRIP_TOOLS_ARCH:-}"
if [[ -n "${requested_arch}" ]]; then
    ARTIFACTS_ARCH="${requested_arch}"
else
    build_archs=" ${ARCHS:-${CURRENT_ARCH:-arm64}} "
    if [[ "${build_archs}" == *" arm64 "* && "${build_archs}" == *" x86_64 "* ]]; then
        ARTIFACTS_ARCH="universal"
    elif [[ "${build_archs}" == *" x86_64 "* ]]; then
        ARTIFACTS_ARCH="x86_64"
    else
        ARTIFACTS_ARCH="arm64"
    fi
fi

case "${ARTIFACTS_ARCH}" in
    arm64|x86_64|universal)
        ;;
    *)
        echo "ERROR: Unsupported SwiftRipTools architecture: ${ARTIFACTS_ARCH}"
        echo "Supported architectures: arm64, x86_64, universal"
        exit 64
        ;;
esac

ARTIFACTS_DIR="${SRCROOT}/SwiftRipTools/Artifacts/macos-${ARTIFACTS_ARCH}"
ARM64_ARTIFACTS_DIR="${SRCROOT}/SwiftRipTools/Artifacts/macos-arm64"
X86_64_ARTIFACTS_DIR="${SRCROOT}/SwiftRipTools/Artifacts/macos-x86_64"
APP_MACOS_DIR="${TARGET_BUILD_DIR}/${EXECUTABLE_FOLDER_PATH}"
APP_FRAMEWORKS_DIR="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"

HANDBRAKE_SOURCE="${ARTIFACTS_DIR}/HandBrakeCLI"
LIBDVDCSS_SOURCE="${ARTIFACTS_DIR}/libdvdcss.2.dylib"

HANDBRAKE_DESTINATION="${APP_MACOS_DIR}/HandBrakeCLI"
LIBDVDCSS_FRAMEWORKS_DESTINATION="${APP_FRAMEWORKS_DIR}/libdvdcss.2.dylib"
STALE_LIBDVDCSS_MACOS_DESTINATION="${APP_MACOS_DIR}/libdvdcss.2.dylib"

echo "Copying SwiftRip tool artifacts..."
echo "Artifacts:  ${ARTIFACTS_DIR}"
echo "Archs:      ${ARCHS:-${CURRENT_ARCH:-unknown}}"
echo "MacOS dir:  ${APP_MACOS_DIR}"
echo "Frameworks: ${APP_FRAMEWORKS_DIR}"

if [[ "${SWIFTRIP_SKIP_BUNDLED_TOOLS:-0}" == "1" ]]; then
    echo "Skipping bundled tool copy because SWIFTRIP_SKIP_BUNDLED_TOOLS=1."
    exit 0
fi

if [[ "${ARTIFACTS_ARCH}" == "universal" ]]; then
    required_artifacts=(
        "${ARM64_ARTIFACTS_DIR}/HandBrakeCLI"
        "${ARM64_ARTIFACTS_DIR}/libdvdcss.2.dylib"
        "${X86_64_ARTIFACTS_DIR}/HandBrakeCLI"
        "${X86_64_ARTIFACTS_DIR}/libdvdcss.2.dylib"
    )
else
    required_artifacts=(
        "${HANDBRAKE_SOURCE}"
        "${LIBDVDCSS_SOURCE}"
    )
fi

for artifact in "${required_artifacts[@]}"; do
    if [[ -f "${artifact}" ]]; then
        continue
    fi

    echo "ERROR: Missing SwiftRipTools artifact:"
    echo "${artifact}"
    echo "Run SwiftRipTools/Scripts/fetch-swiftrip-tools.zsh first."
    exit 1
done

mkdir -p "${APP_MACOS_DIR}"
mkdir -p "${APP_FRAMEWORKS_DIR}"

if [[ "${ARTIFACTS_ARCH}" == "universal" ]]; then
    echo ""
    echo "Creating universal bundled tool artifacts..."
    /usr/bin/lipo -create \
        "${ARM64_ARTIFACTS_DIR}/HandBrakeCLI" \
        "${X86_64_ARTIFACTS_DIR}/HandBrakeCLI" \
        -output "${HANDBRAKE_DESTINATION}"
    /usr/bin/lipo -create \
        "${ARM64_ARTIFACTS_DIR}/libdvdcss.2.dylib" \
        "${X86_64_ARTIFACTS_DIR}/libdvdcss.2.dylib" \
        -output "${LIBDVDCSS_FRAMEWORKS_DESTINATION}"
else
    cp "${HANDBRAKE_SOURCE}" "${HANDBRAKE_DESTINATION}"
    cp "${LIBDVDCSS_SOURCE}" "${LIBDVDCSS_FRAMEWORKS_DESTINATION}"
fi

rm -f "${STALE_LIBDVDCSS_MACOS_DESTINATION}"

chmod 755 "${HANDBRAKE_DESTINATION}"
chmod 755 "${LIBDVDCSS_FRAMEWORKS_DESTINATION}"

if [[ "${CODE_SIGNING_ALLOWED:-NO}" == "YES" ]]; then
    SIGNING_IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY:-${CODE_SIGN_IDENTITY:-}}"
    if [[ -z "${SIGNING_IDENTITY}" ]]; then
        echo "ERROR: CODE_SIGNING_ALLOWED=YES but no code signing identity is set."
        exit 1
    fi

    CODE_SIGN_OPTIONS=(--force --sign "${SIGNING_IDENTITY}")
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

case "${ARTIFACTS_ARCH}" in
    universal)
        for expected_arch in arm64 x86_64; do
            if ! file "${HANDBRAKE_DESTINATION}" | grep -q "${expected_arch}"; then
                echo "ERROR: Universal HandBrakeCLI is missing ${expected_arch}."
                exit 1
            fi

            if ! file "${LIBDVDCSS_FRAMEWORKS_DESTINATION}" | grep -q "${expected_arch}"; then
                echo "ERROR: Universal Frameworks libdvdcss.2.dylib is missing ${expected_arch}."
                exit 1
            fi
        done
        ;;
    *)
        if ! file "${HANDBRAKE_DESTINATION}" | grep -q "${ARTIFACTS_ARCH}"; then
            echo "ERROR: Bundled HandBrakeCLI is not ${ARTIFACTS_ARCH}."
            exit 1
        fi

        if ! file "${LIBDVDCSS_FRAMEWORKS_DESTINATION}" | grep -q "${ARTIFACTS_ARCH}"; then
            echo "ERROR: Bundled Frameworks libdvdcss.2.dylib is not ${ARTIFACTS_ARCH}."
            exit 1
        fi
        ;;
esac

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
