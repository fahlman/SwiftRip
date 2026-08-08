#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TOOLS_REPOSITORY="${SWIFTRIP_TOOLS_REPOSITORY:-fahlman/SwiftRip-Tools}"
TOOLS_REVISION=""
PACKAGE_VERSION=""
HANDBRAKE_VERSION=""
HANDBRAKE_SOURCE_TAG=""
HANDBRAKE_SOURCE_COMMIT=""
LIBDVDCSS_VERSION=""
LIBDVDCSS_SOURCE_TAG=""
LIBDVDCSS_SOURCE_COMMIT=""
RELEASE_VERSION=""
TARGET_BRANCH="${SWIFTRIP_RELEASE_BRANCH:-main}"
WORK_DIR=""

usage() {
    cat <<'USAGE'
Usage: Scripts/consume-swiftrip-tools-update.zsh [options]

Consume an exact SwiftRip-Tools update, bump SwiftRip's version, commit the
new provenance, and push a version tag for the GitHub release workflow.

Options:
  --tools-repository REPOSITORY  SwiftRip-Tools repository, owner/name.
  --tools-revision SHA            Exact SwiftRip-Tools commit to consume.
  --package-version VERSION       Published package set version.
  --handbrake-version VERSION     HandBrake version in the package.
  --handbrake-source-tag TAG      Exact SwiftRip-HandBrake source tag.
  --handbrake-source-commit SHA   Exact SwiftRip-HandBrake source commit.
  --libdvdcss-version VERSION     libdvdcss version in the package.
  --libdvdcss-source-tag TAG      Exact SwiftRip-libdvdcss source tag.
  --libdvdcss-source-commit SHA   Exact SwiftRip-libdvdcss source commit.
  --release-version VERSION       App version; defaults to the next patch version.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --tools-repository)
            TOOLS_REPOSITORY="${2:-}"
            shift 2
            ;;
        --tools-revision)
            TOOLS_REVISION="${2:-}"
            shift 2
            ;;
        --package-version)
            PACKAGE_VERSION="${2:-}"
            shift 2
            ;;
        --handbrake-version)
            HANDBRAKE_VERSION="${2:-}"
            shift 2
            ;;
        --handbrake-source-tag)
            HANDBRAKE_SOURCE_TAG="${2:-}"
            shift 2
            ;;
        --handbrake-source-commit)
            HANDBRAKE_SOURCE_COMMIT="${2:-}"
            shift 2
            ;;
        --libdvdcss-version)
            LIBDVDCSS_VERSION="${2:-}"
            shift 2
            ;;
        --libdvdcss-source-tag)
            LIBDVDCSS_SOURCE_TAG="${2:-}"
            shift 2
            ;;
        --libdvdcss-source-commit)
            LIBDVDCSS_SOURCE_COMMIT="${2:-}"
            shift 2
            ;;
        --release-version)
            RELEASE_VERSION="${2:-}"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            exit 64
            ;;
    esac
done

required_values=(
    TOOLS_REVISION
    PACKAGE_VERSION
    HANDBRAKE_VERSION
    HANDBRAKE_SOURCE_TAG
    HANDBRAKE_SOURCE_COMMIT
    LIBDVDCSS_VERSION
    LIBDVDCSS_SOURCE_TAG
    LIBDVDCSS_SOURCE_COMMIT
)
for variable_name in "${required_values[@]}"; do
    if [[ -z "${(P)variable_name}" ]]; then
        echo "ERROR: Missing required value: $variable_name" >&2
        exit 64
    fi
done

if [[ ! "$TOOLS_REVISION" =~ '^[0-9a-fA-F]{40}$' ]]; then
    echo "ERROR: SwiftRip-Tools revision must be a full 40-character SHA." >&2
    exit 64
fi
for commit in "$HANDBRAKE_SOURCE_COMMIT" "$LIBDVDCSS_SOURCE_COMMIT"; do
    if [[ ! "$commit" =~ '^[0-9a-fA-F]{40}$' ]]; then
        echo "ERROR: Source commit must be a full 40-character SHA: $commit" >&2
        exit 64
    fi
done

for command_name in curl git python3; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "ERROR: Required command not found: $command_name" >&2
        exit 1
    fi
done

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/swiftrip-tools-consumer.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

RAW_BASE_URL="https://raw.githubusercontent.com/$TOOLS_REPOSITORY/$TOOLS_REVISION"
for manifest_name in swiftrip-tools.json swiftrip-tools-x86_64.json; do
    curl -fsSL "$RAW_BASE_URL/Manifest/$manifest_name" -o "$WORK_DIR/$manifest_name"
    /usr/bin/plutil -convert json -o /dev/null "$WORK_DIR/$manifest_name"
done

for manifest_name in swiftrip-tools.json swiftrip-tools-x86_64.json; do
    manifest_version="$(/usr/bin/plutil -extract version raw -o - "$WORK_DIR/$manifest_name")"
    if [[ "$manifest_version" != "$PACKAGE_VERSION" ]]; then
        echo "ERROR: $manifest_name does not contain package version $PACKAGE_VERSION:" >&2
        echo "$manifest_version" >&2
        exit 1
    fi
done

current_arm_version="$(/usr/bin/plutil -extract version raw -o - "$ROOT_DIR/SwiftRip-Tools/Manifest/swiftrip-tools.json")"
current_intel_version="$(/usr/bin/plutil -extract version raw -o - "$ROOT_DIR/SwiftRip-Tools/Manifest/swiftrip-tools-x86_64.json")"
if [[ "$current_arm_version" == "$PACKAGE_VERSION" && "$current_intel_version" == "$PACKAGE_VERSION" ]]; then
    echo "SwiftRip already consumes $PACKAGE_VERSION; nothing to do."
    exit 0
fi

/bin/cp "$WORK_DIR/swiftrip-tools.json" "$ROOT_DIR/SwiftRip-Tools/Manifest/swiftrip-tools.json"
/bin/cp "$WORK_DIR/swiftrip-tools-x86_64.json" "$ROOT_DIR/SwiftRip-Tools/Manifest/swiftrip-tools-x86_64.json"

/usr/bin/python3 - "$ROOT_DIR/THIRD_PARTY_NOTICES.md" "$ROOT_DIR/SOURCE_OFFER.md" "$HANDBRAKE_SOURCE_TAG" "$LIBDVDCSS_SOURCE_TAG" "$HANDBRAKE_VERSION" "$LIBDVDCSS_VERSION" <<'PY'
from pathlib import Path
import re
import sys

third_party_path = Path(sys.argv[1])
source_offer_path = Path(sys.argv[2])
handbrake_tag, libdvdcss_tag, handbrake_version, libdvdcss_version = sys.argv[3:]

for path in (third_party_path, source_offer_path):
    text = path.read_text(encoding="utf-8")
    text = re.sub(r"swiftrip-handbrake-[0-9.]+", handbrake_tag, text)
    text = re.sub(r"swiftrip-libdvdcss-[0-9.]+", libdvdcss_tag, text)
    path.write_text(text, encoding="utf-8")

text = third_party_path.read_text(encoding="utf-8")
target_version_pattern = re.compile(r"(- Current SwiftRip-Tools target version: )[0-9.]+")
text, handbrake_count = target_version_pattern.subn(rf"\g<1>{handbrake_version}", text, count=1)
text, libdvdcss_count = target_version_pattern.subn(rf"\g<1>{libdvdcss_version}", text, count=1)
if handbrake_count != 1 or libdvdcss_count != 1:
    raise SystemExit(
        f"Could not update third-party target versions: HandBrake={handbrake_count}, "
        f"libdvdcss={libdvdcss_count}"
    )
third_party_path.write_text(text, encoding="utf-8")
PY

read_build_setting() {
    local setting_name="$1"
    /usr/bin/awk -F'= ' -v name="$setting_name" '$1 ~ "^[[:space:]]*" name "[[:space:]]*$" { value=$2; gsub(";", "", value) } END { print value }' \
        "$ROOT_DIR/SwiftRip.xcodeproj/project.pbxproj"
}

increment_patch_version() {
    /usr/bin/python3 - "$1" <<'PY'
import sys

parts = [int(part) for part in sys.argv[1].split(".")]
if len(parts) < 3:
    parts.append(0)
parts[-1] += 1
print(".".join(str(part) for part in parts))
PY
}

CURRENT_MARKETING_VERSION="$(read_build_setting MARKETING_VERSION)"
CURRENT_PROJECT_VERSION="$(read_build_setting CURRENT_PROJECT_VERSION)"
if [[ -z "$RELEASE_VERSION" ]]; then
    RELEASE_VERSION="$(increment_patch_version "$CURRENT_MARKETING_VERSION")"
fi
if [[ ! "$RELEASE_VERSION" =~ '^[0-9]+(\.[0-9]+){1,2}$' ]]; then
    echo "ERROR: Invalid SwiftRip release version: $RELEASE_VERSION" >&2
    exit 64
fi
if [[ ! "$CURRENT_PROJECT_VERSION" =~ '^[0-9]+$' ]]; then
    echo "ERROR: Current project version is not numeric: $CURRENT_PROJECT_VERSION" >&2
    exit 1
fi
NEXT_PROJECT_VERSION=$((CURRENT_PROJECT_VERSION + 1))

/usr/bin/python3 - "$ROOT_DIR/SwiftRip.xcodeproj/project.pbxproj" "$RELEASE_VERSION" "$NEXT_PROJECT_VERSION" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
marketing_version, project_version = sys.argv[2:]
text = path.read_text(encoding="utf-8")
text, marketing_count = re.subn(
    r"(\bMARKETING_VERSION = )[0-9.]+(;)",
    rf"\g<1>{marketing_version}\g<2>",
    text,
)
text, project_count = re.subn(
    r"(\bCURRENT_PROJECT_VERSION = )[0-9]+(;)",
    rf"\g<1>{project_version}\g<2>",
    text,
)
if marketing_count == 0 or project_count == 0:
    raise SystemExit(
        f"Could not update Xcode versions: marketing={marketing_count}, project={project_count}"
    )
path.write_text(text, encoding="utf-8")
PY

RELEASE_TAG="v$RELEASE_VERSION"
RELEASE_NOTES_DIR="$ROOT_DIR/ReleaseNotes"
RELEASE_NOTES_PATH="$RELEASE_NOTES_DIR/$RELEASE_TAG.md"
/bin/mkdir -p "$RELEASE_NOTES_DIR"
cat > "$RELEASE_NOTES_PATH" <<EOF
# SwiftRip $RELEASE_VERSION

This release updates the bundled tools automatically from their upstream releases.

- HandBrakeCLI: $HANDBRAKE_VERSION
- libdvdcss: $LIBDVDCSS_VERSION
- SwiftRip-Tools package: $PACKAGE_VERSION
- SwiftRip-Tools revision: $TOOLS_REVISION
- SwiftRip-HandBrake source: $HANDBRAKE_SOURCE_TAG ($HANDBRAKE_SOURCE_COMMIT)
- SwiftRip-libdvdcss source: $LIBDVDCSS_SOURCE_TAG ($LIBDVDCSS_SOURCE_COMMIT)
EOF

echo "Validating SwiftRip update before committing..."
git -C "$ROOT_DIR" diff --check
if [[ -x "$SCRIPT_DIR/ci-validate-repo.zsh" ]]; then
    "$SCRIPT_DIR/ci-validate-repo.zsh"
fi

if git -C "$ROOT_DIR" rev-parse --verify "refs/tags/$RELEASE_TAG" >/dev/null 2>&1; then
    echo "ERROR: SwiftRip release tag already exists: $RELEASE_TAG" >&2
    exit 1
fi

git -C "$ROOT_DIR" add \
    SwiftRip-Tools/Manifest/swiftrip-tools.json \
    SwiftRip-Tools/Manifest/swiftrip-tools-x86_64.json \
    SwiftRip.xcodeproj/project.pbxproj \
    THIRD_PARTY_NOTICES.md \
    SOURCE_OFFER.md \
    "$RELEASE_NOTES_PATH"

git -C "$ROOT_DIR" config user.name "SwiftRip release automation"
git -C "$ROOT_DIR" config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git -C "$ROOT_DIR" commit -m "Update bundled tools to HandBrake $HANDBRAKE_VERSION and libdvdcss $LIBDVDCSS_VERSION"
git -C "$ROOT_DIR" push origin "HEAD:$TARGET_BRANCH"

git -C "$ROOT_DIR" tag -a "$RELEASE_TAG" -m "SwiftRip $RELEASE_VERSION"
git -C "$ROOT_DIR" push origin "$RELEASE_TAG"

echo "SwiftRip update committed and release tag pushed: $RELEASE_TAG"
