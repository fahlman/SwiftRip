#!/bin/zsh
set -euo pipefail

# SwiftRip requires macOS 27, which runs only on Apple silicon, so the app and
# its bundled tools are arm64 only.
ARTIFACTS_ARCH="${SWIFTRIP_TOOLS_ARCH:-arm64}"
if [[ "${ARTIFACTS_ARCH}" != "arm64" ]]; then
    echo "ERROR: Unsupported SwiftRip-Tools architecture: ${ARTIFACTS_ARCH}"
    echo "Supported architecture: arm64 (SwiftRip requires macOS 27, which runs only on Apple silicon)."
    exit 64
fi

build_archs=(${=${ARCHS:-${CURRENT_ARCH:-arm64}}})
if [[ "${build_archs[*]}" != "arm64" ]]; then
    echo "ERROR: SwiftRip builds for Apple silicon (arm64) only, but ARCHS is '${build_archs[*]}'."
    exit 64
fi

ARTIFACTS_DIR="${SRCROOT}/SwiftRip-Tools/Artifacts/macos-${ARTIFACTS_ARCH}"
FETCH_TOOLS_SCRIPT="${SRCROOT}/SwiftRip-Tools/Scripts/fetch-swiftrip-tools.zsh"
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

required_artifacts=(
    "${HANDBRAKE_SOURCE}"
    "${LIBDVDCSS_SOURCE}"
)

missing_artifacts=()
for artifact in "${required_artifacts[@]}"; do
    if [[ -f "${artifact}" ]]; then
        continue
    fi

    missing_artifacts+=("${artifact}")
done

if [[ "${#missing_artifacts[@]}" -gt 0 ]]; then
    echo ""
    echo "Restoring missing SwiftRip-Tools artifacts..."

    if [[ ! -x "${FETCH_TOOLS_SCRIPT}" ]]; then
        echo "ERROR: SwiftRip-Tools fetch script is not executable:"
        echo "${FETCH_TOOLS_SCRIPT}"
        exit 1
    fi

    "${FETCH_TOOLS_SCRIPT}" --arch "${ARTIFACTS_ARCH}"
fi

for artifact in "${required_artifacts[@]}"; do
    if [[ -f "${artifact}" ]]; then
        continue
    fi

    echo "ERROR: Missing SwiftRip-Tools artifact after restore:"
    echo "${artifact}"
    exit 1
done

mkdir -p "${APP_MACOS_DIR}"
mkdir -p "${APP_FRAMEWORKS_DIR}"

cp "${HANDBRAKE_SOURCE}" "${HANDBRAKE_DESTINATION}"
cp "${LIBDVDCSS_SOURCE}" "${LIBDVDCSS_FRAMEWORKS_DESTINATION}"

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
