#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/SwiftRip.xcodeproj/project.pbxproj"
PACKAGE_RESOLVED_PATH="$ROOT_DIR/SwiftRip.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
SPARKLE_REPOSITORY_URL="https://github.com/sparkle-project/Sparkle.git"
TARGET_BRANCH="${SWIFTRIP_RELEASE_BRANCH:-main}"
SPARKLE_VERSION=""
SPARKLE_TAG=""
SPARKLE_COMMIT=""
RELEASE_VERSION=""
DRY_RUN=false
SKIP_TESTS="${SWIFTRIP_SKIP_RELEASE_TESTS:-0}"

usage() {
    cat <<'USAGE'
Usage: Scripts/consume-sparkle-update.zsh [options]

Update SwiftRip to the latest stable Sparkle release, validate it, bump the
app version, and push a release tag for the GitHub release workflow.

With no Sparkle version supplied, the latest stable release is read from the
official sparkle-project/Sparkle GitHub repository. The tag commit is resolved
again from that repository before it is consumed.

Options:
  --sparkle-version VERSION   Sparkle release version to consume.
  --sparkle-tag TAG           Exact Sparkle source tag; defaults to VERSION.
  --sparkle-commit SHA        Expected full commit SHA for the source tag.
  --release-version VERSION   SwiftRip version; defaults to the next release.
  --skip-tests                Skip the Xcode analyze/test pass.
  --dry-run                   Update and validate without committing or pushing.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --sparkle-version)
            SPARKLE_VERSION="${2:-}"
            shift 2
            ;;
        --sparkle-tag)
            SPARKLE_TAG="${2:-}"
            shift 2
            ;;
        --sparkle-commit)
            SPARKLE_COMMIT="${2:-}"
            shift 2
            ;;
        --release-version)
            RELEASE_VERSION="${2:-}"
            shift 2
            ;;
        --skip-tests)
            SKIP_TESTS=1
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
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

for command_name in curl git python3 awk; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "ERROR: Required command not found: $command_name" >&2
        exit 1
    fi
done

if [[ -n "$(git -C "$ROOT_DIR" status --porcelain)" ]]; then
    echo "ERROR: SwiftRip working tree must be clean before a Sparkle update." >&2
    git -C "$ROOT_DIR" status --short >&2
    exit 1
fi

read_sparkle_pin() {
    local field_name="$1"
    /usr/bin/python3 - "$PACKAGE_RESOLVED_PATH" "$field_name" <<'PY'
import json
import sys

path, field = sys.argv[1:]
data = json.loads(open(path, encoding="utf-8").read())
pin = next((pin for pin in data.get("pins", []) if pin.get("identity") == "sparkle"), None)
if pin is None:
    raise SystemExit("Sparkle pin was not found in Package.resolved")
print(pin["state"][field])
PY
}

read_build_setting() {
    local setting_name="$1"
    /usr/bin/awk -F'= ' -v name="$setting_name" \
        '$1 ~ "^[[:space:]]*" name "[[:space:]]*$" { value=$2; gsub(";", "", value) } END { print value }' \
        "$PROJECT_PATH"
}

version_is_greater() {
    /usr/bin/python3 - "$1" "$2" <<'PY'
import sys

left = tuple(int(part) for part in sys.argv[1].split("."))
right = tuple(int(part) for part in sys.argv[2].split("."))
width = max(len(left), len(right))
left += (0,) * (width - len(left))
right += (0,) * (width - len(right))
raise SystemExit(0 if left > right else 1)
PY
}

increment_release_version() {
    /usr/bin/python3 - "$1" <<'PY'
import sys

parts = [int(part) for part in sys.argv[1].split(".")]
if len(parts) == 1:
    parts.append(1)
elif len(parts) == 2:
    parts[-1] += 1
else:
    parts[-1] += 1
print(".".join(str(part) for part in parts))
PY
}

github_curl_args=(
    -fsSL
    -H "Accept: application/vnd.github+json"
    -H "X-GitHub-Api-Version: 2022-11-28"
)
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    github_curl_args+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

CURRENT_SPARKLE_VERSION="$(read_sparkle_pin version)"
CURRENT_SPARKLE_COMMIT="$(read_sparkle_pin revision)"
if [[ ! "$CURRENT_SPARKLE_VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
    echo "ERROR: Current Sparkle version is invalid: $CURRENT_SPARKLE_VERSION" >&2
    exit 1
fi

if [[ -z "$SPARKLE_VERSION" ]]; then
    latest_release_json="$(curl "${github_curl_args[@]}" "https://api.github.com/repos/sparkle-project/Sparkle/releases/latest")"
    SPARKLE_TAG="$(/usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"])' <<< "$latest_release_json")"
    SPARKLE_VERSION="${SPARKLE_TAG#v}"
else
    SPARKLE_VERSION="${SPARKLE_VERSION#v}"
    SPARKLE_TAG="${SPARKLE_TAG:-$SPARKLE_VERSION}"
fi

if [[ ! "$SPARKLE_VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
    echo "ERROR: Invalid Sparkle version: $SPARKLE_VERSION" >&2
    exit 64
fi

resolve_sparkle_commit() {
    local commit

    commit="$(GIT_TERMINAL_PROMPT=0 git ls-remote --tags "$SPARKLE_REPOSITORY_URL" \
        "refs/tags/${SPARKLE_TAG}^{}" | /usr/bin/awk '{ print $1; exit }')"
    if [[ -z "$commit" ]]; then
        commit="$(GIT_TERMINAL_PROMPT=0 git ls-remote --tags "$SPARKLE_REPOSITORY_URL" \
            "refs/tags/${SPARKLE_TAG}" | /usr/bin/awk '{ print $1; exit }')"
    fi
    print -r -- "$commit"
}

OFFICIAL_SPARKLE_COMMIT="$(resolve_sparkle_commit)"
if [[ ! "$OFFICIAL_SPARKLE_COMMIT" =~ '^[0-9a-fA-F]{40}$' ]]; then
    echo "ERROR: Could not resolve Sparkle tag $SPARKLE_TAG from the official repository." >&2
    exit 1
fi
if [[ -n "$SPARKLE_COMMIT" && "$SPARKLE_COMMIT" != "$OFFICIAL_SPARKLE_COMMIT" ]]; then
    echo "ERROR: Sparkle commit does not match the official tag." >&2
    echo "Expected: $SPARKLE_COMMIT" >&2
    echo "Official: $OFFICIAL_SPARKLE_COMMIT" >&2
    exit 1
fi
SPARKLE_COMMIT="$OFFICIAL_SPARKLE_COMMIT"

echo "Current Sparkle:  $CURRENT_SPARKLE_VERSION ($CURRENT_SPARKLE_COMMIT)"
echo "Latest Sparkle:  $SPARKLE_VERSION ($SPARKLE_COMMIT)"

if ! version_is_greater "$SPARKLE_VERSION" "$CURRENT_SPARKLE_VERSION"; then
    if [[ "$SPARKLE_VERSION" == "$CURRENT_SPARKLE_VERSION" && "$SPARKLE_COMMIT" != "$CURRENT_SPARKLE_COMMIT" ]]; then
        echo "ERROR: Sparkle release tag $SPARKLE_VERSION moved to a different commit." >&2
        exit 1
    fi
    echo "Sparkle is already up to date."
    exit 0
fi

if [[ -z "$RELEASE_VERSION" ]]; then
    RELEASE_VERSION="$(increment_release_version "$(read_build_setting MARKETING_VERSION)")"
fi
if [[ ! "$RELEASE_VERSION" =~ '^[0-9]+(\.[0-9]+){1,2}$' ]]; then
    echo "ERROR: Invalid SwiftRip release version: $RELEASE_VERSION" >&2
    exit 64
fi

CURRENT_PROJECT_VERSION="$(read_build_setting CURRENT_PROJECT_VERSION)"
if [[ ! "$CURRENT_PROJECT_VERSION" =~ '^[0-9]+$' ]]; then
    echo "ERROR: Current project version is not numeric: $CURRENT_PROJECT_VERSION" >&2
    exit 1
fi
NEXT_PROJECT_VERSION=$((CURRENT_PROJECT_VERSION + 1))
RELEASE_TAG="v$RELEASE_VERSION"

if git -C "$ROOT_DIR" rev-parse --verify "refs/tags/$RELEASE_TAG" >/dev/null 2>&1; then
    echo "ERROR: SwiftRip release tag already exists locally: $RELEASE_TAG" >&2
    exit 1
fi
if git -C "$ROOT_DIR" ls-remote --exit-code --tags origin "refs/tags/$RELEASE_TAG" >/dev/null 2>&1; then
    echo "ERROR: SwiftRip release tag already exists remotely: $RELEASE_TAG" >&2
    exit 1
fi

/usr/bin/python3 - "$PACKAGE_RESOLVED_PATH" "$SPARKLE_VERSION" "$SPARKLE_COMMIT" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
version, commit = sys.argv[2:]
text = path.read_text(encoding="utf-8")
identity_index = text.find('"identity" : "sparkle"')
if identity_index < 0:
    raise SystemExit("Sparkle pin was not found in Package.resolved")
block_start = text.rfind("    {", 0, identity_index)
block_end = text.find("\n    }", identity_index)
if block_start < 0 or block_end < 0:
    raise SystemExit("Could not isolate Sparkle pin in Package.resolved")
block_end += len("\n    }")
block = text[block_start:block_end]
block, revision_count = re.subn(
    r'("revision"\s*:\s*")[^"]+("\s*)',
    rf'\g<1>{commit}\g<2>',
    block,
    count=1,
)
block, version_count = re.subn(
    r'("version"\s*:\s*")[^"]+("\s*)',
    rf'\g<1>{version}\g<2>',
    block,
    count=1,
)
if revision_count != 1 or version_count != 1:
    raise SystemExit(
        f"Could not update Sparkle pin: revision={revision_count}, version={version_count}"
    )
path.write_text(text[:block_start] + block + text[block_end:], encoding="utf-8")
PY

CURRENT_SPARKLE_MINIMUM_VERSION="$(/usr/bin/awk -F'= ' \
    '$1 ~ "^[[:space:]]*minimumVersion[[:space:]]*$" { value=$2; gsub(";", "", value) } END { print value }' \
    "$PROJECT_PATH")"
CURRENT_SPARKLE_MAJOR="${CURRENT_SPARKLE_MINIMUM_VERSION%%.*}"
LATEST_SPARKLE_MAJOR="${SPARKLE_VERSION%%.*}"
if [[ "$LATEST_SPARKLE_MAJOR" -gt "$CURRENT_SPARKLE_MAJOR" ]]; then
    /usr/bin/python3 - "$PROJECT_PATH" "$SPARKLE_VERSION" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
version = sys.argv[2]
text = path.read_text(encoding="utf-8")
pattern = re.compile(
    r'(XCRemoteSwiftPackageReference "Sparkle".*?minimumVersion = )([0-9.]+)(;)',
    re.DOTALL,
)
text, count = pattern.subn(rf'\g<1>{version}\g<3>', text, count=1)
if count != 1:
    raise SystemExit("Could not update the Sparkle minimum version")
path.write_text(text, encoding="utf-8")
PY
    echo "Updated the Sparkle package requirement for major version $LATEST_SPARKLE_MAJOR."
fi

/usr/bin/python3 - "$PROJECT_PATH" "$RELEASE_VERSION" "$NEXT_PROJECT_VERSION" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
marketing_version, project_version = sys.argv[2:]
text = path.read_text(encoding="utf-8")
text, marketing_count = re.subn(
    r'(\bMARKETING_VERSION = )[0-9.]+(;)',
    rf'\g<1>{marketing_version}\g<2>',
    text,
)
text, project_count = re.subn(
    r'(\bCURRENT_PROJECT_VERSION = )[0-9]+(;)',
    rf'\g<1>{project_version}\g<2>',
    text,
)
if marketing_count == 0 or project_count == 0:
    raise SystemExit(
        f"Could not update Xcode versions: marketing={marketing_count}, project={project_count}"
    )
path.write_text(text, encoding="utf-8")
PY

RELEASE_NOTES_PATH="$ROOT_DIR/ReleaseNotes/$RELEASE_TAG.md"
if [[ -e "$RELEASE_NOTES_PATH" ]]; then
    echo "ERROR: Release notes already exist: $RELEASE_NOTES_PATH" >&2
    exit 1
fi
/bin/mkdir -p "$ROOT_DIR/ReleaseNotes"
cat > "$RELEASE_NOTES_PATH" <<EOF
# SwiftRip $RELEASE_VERSION

This release updates the bundled Sparkle framework from its official upstream release.

- Sparkle: $SPARKLE_VERSION
- Sparkle source tag: $SPARKLE_TAG
- Sparkle source commit: $SPARKLE_COMMIT
- SwiftRip build: $NEXT_PROJECT_VERSION
EOF

echo "Validating SwiftRip Sparkle update..."
"$SCRIPT_DIR/ci-validate-repo.zsh"

if [[ "$SKIP_TESTS" != "1" && "$SKIP_TESTS" != "true" ]]; then
    tools_available=true
    if ! "$ROOT_DIR/SwiftRip-Tools/Scripts/fetch-swiftrip-tools.zsh"; then
        tools_available=false
        echo "Bundled tools could not be fetched; running tests with tool checks skipped." >&2
    fi

    /usr/bin/xcodebuild analyze \
        -project "$ROOT_DIR/SwiftRip.xcodeproj" \
        -scheme SwiftRip \
        -destination 'platform=macOS' \
        CODE_SIGNING_ALLOWED=NO

    if [[ "$tools_available" == true ]]; then
        SWIFTRIP_SUPPRESS_FIRST_RUN_OUTPUT_PROMPT=1 /usr/bin/xcodebuild test \
            -project "$ROOT_DIR/SwiftRip.xcodeproj" \
            -scheme SwiftRip \
            -destination 'platform=macOS' \
            CODE_SIGNING_ALLOWED=NO \
            -only-testing:SwiftRipTests
    else
        SWIFTRIP_SUPPRESS_FIRST_RUN_OUTPUT_PROMPT=1 SWIFTRIP_SKIP_BUNDLED_TOOLS=1 /usr/bin/xcodebuild test \
            -project "$ROOT_DIR/SwiftRip.xcodeproj" \
            -scheme SwiftRip \
            -destination 'platform=macOS' \
            CODE_SIGNING_ALLOWED=NO \
            -only-testing:SwiftRipTests \
            -skip-testing:SwiftRipTests/BundleIntegrityTests
    fi
fi

if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run complete; no commit or release tag was created."
    exit 0
fi

git -C "$ROOT_DIR" add \
    SwiftRip.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved \
    SwiftRip.xcodeproj/project.pbxproj \
    "$RELEASE_NOTES_PATH"
git -C "$ROOT_DIR" config user.name "SwiftRip Sparkle release automation"
git -C "$ROOT_DIR" config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git -C "$ROOT_DIR" commit -m "Update Sparkle to $SPARKLE_VERSION"
git -C "$ROOT_DIR" push origin "HEAD:$TARGET_BRANCH"
git -C "$ROOT_DIR" tag -a "$RELEASE_TAG" -m "SwiftRip $RELEASE_VERSION"
git -C "$ROOT_DIR" push origin "$RELEASE_TAG"

echo "SwiftRip Sparkle update committed and release tag pushed: $RELEASE_TAG"
