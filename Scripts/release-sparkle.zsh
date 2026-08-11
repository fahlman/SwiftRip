#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RELEASE_COMMON_SCRIPT="$ROOT_DIR/Scripts/lib/release-common.zsh"
RELEASE_ZIP_SCRIPT="$ROOT_DIR/Scripts/release-zip.zsh"
PROJECT_PATH="$ROOT_DIR/SwiftRip.xcodeproj"
SCHEME="SwiftRip"
APP_NAME="SwiftRip"
OWNER_REPO="${SWIFTRIP_GITHUB_REPO:-fahlman/SwiftRip}"
VERSION=""
RELEASE_TAG=""
RELEASE_TITLE=""
NOTES_FILE=""
NOTARY_PROFILE="${SWIFTRIP_NOTARY_PROFILE:-}"
NOTARY_APPLE_ID="${SWIFTRIP_NOTARY_APPLE_ID:-}"
NOTARY_PASSWORD="${SWIFTRIP_NOTARY_PASSWORD:-}"
OUTPUT_DIR=""
PAGES_WORKTREE="${SWIFTRIP_PAGES_WORKTREE:-${TMPDIR:-/private/tmp}/swiftrip-gh-pages-publish}"
APPCAST_WORK_DIR="${SWIFTRIP_APPCAST_WORK_DIR:-${TMPDIR:-/private/tmp}/swiftrip-appcasts}"
GENERATE_APPCAST="${SWIFTRIP_GENERATE_APPCAST:-}"
GITHUB_TOKEN="${SWIFTRIP_GITHUB_TOKEN:-${GITHUB_TOKEN:-}}"
SPARKLE_ED_KEY="${SWIFTRIP_SPARKLE_ED_KEY:-}"
SKIP_NOTARIZATION=false
PRERELEASE=false
ALLOW_CLOBBER="${SWIFTRIP_RELEASE_ALLOW_CLOBBER:-0}"
typeset -a RELEASE_ASSET_PATHS

# shellcheck source=/dev/null
source "$RELEASE_COMMON_SCRIPT"

usage() {
    cat <<'USAGE'
Usage: Scripts/release-sparkle.zsh [options]

Package a universal SwiftRip.app ZIP, upload it to a GitHub release,
generate the Sparkle appcast, and publish the appcast to GitHub Pages.

Options:
  --version VERSION         Release version. Defaults to MARKETING_VERSION.
  --release-tag TAG         GitHub release tag. Defaults to vVERSION.
  --title TITLE             GitHub release title. Defaults to SwiftRip VERSION.
  --notes-file PATH         Release notes file for gh release create.
  --notary-profile NAME     notarytool keychain profile name.
  --skip-notarization       Pass through to release-zip.zsh.
  --prerelease              Mark a newly created GitHub release as a prerelease.
  --output-dir PATH         Directory for built ZIPs. Defaults to ./dist/VERSION.
  --pages-worktree PATH     Local gh-pages checkout/worktree.
  --generate-appcast PATH   Sparkle generate_appcast executable.
  -h, --help                Show this help.

Environment variables:
  SWIFTRIP_GITHUB_REPO
  SWIFTRIP_NOTARY_PROFILE
  SWIFTRIP_NOTARY_APPLE_ID
  SWIFTRIP_NOTARY_PASSWORD
  SWIFTRIP_PAGES_WORKTREE
  SWIFTRIP_APPCAST_WORK_DIR
  SWIFTRIP_GENERATE_APPCAST
  SWIFTRIP_GITHUB_TOKEN
  SWIFTRIP_SPARKLE_ED_KEY
  SWIFTRIP_RELEASE_ALLOW_CLOBBER
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            VERSION="${2:-}"
            shift 2
            ;;
        --release-tag)
            RELEASE_TAG="${2:-}"
            shift 2
            ;;
        --title)
            RELEASE_TITLE="${2:-}"
            shift 2
            ;;
        --notes-file)
            NOTES_FILE="${2:-}"
            shift 2
            ;;
        --notary-profile)
            NOTARY_PROFILE="${2:-}"
            shift 2
            ;;
        --skip-notarization)
            SKIP_NOTARIZATION=true
            shift
            ;;
        --prerelease)
            PRERELEASE=true
            shift
            ;;
        --output-dir)
            OUTPUT_DIR="${2:-}"
            shift 2
            ;;
        --pages-worktree)
            PAGES_WORKTREE="${2:-}"
            shift 2
            ;;
        --generate-appcast)
            GENERATE_APPCAST="${2:-}"
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

build_setting() {
    local setting_name="$1"
    /usr/bin/xcodebuild -project "$PROJECT_PATH" -scheme "$SCHEME" -configuration Release -showBuildSettings 2>/dev/null \
        | /usr/bin/awk -F '= ' -v key="$setting_name" '$1 ~ "^[[:space:]]*" key "[[:space:]]*$" { value=$2 } END { print value }'
}

find_generate_appcast() {
    if [[ -n "$GENERATE_APPCAST" ]]; then
        echo "$GENERATE_APPCAST"
        return
    fi

    local derived_data="$HOME/Library/Developer/Xcode/DerivedData"
    local release_work_dir="${SWIFTRIP_RELEASE_WORK_DIR:-}"
    local candidate

    if [[ -n "$release_work_dir" && -d "$release_work_dir" ]]; then
        candidate="$(/usr/bin/find "$release_work_dir" -path "*/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast" -type f -print | /usr/bin/tail -n 1)"
        if [[ -n "$candidate" ]]; then
            echo "$candidate"
            return
        fi
    fi

    if [[ -d "$derived_data" ]]; then
        /usr/bin/find "$derived_data" \
            -path "*/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast" \
            -type f \
            -print \
            | /usr/bin/tail -n 1
    fi
}

release_notes_arg() {
    if [[ -n "$NOTES_FILE" ]]; then
        echo "--notes-file"
        echo "$NOTES_FILE"
    else
        echo "--notes"
        echo "$APP_NAME $VERSION"
    fi
}

release_notes_body() {
    if [[ -n "$NOTES_FILE" ]]; then
        /bin/cat "$NOTES_FILE"
    else
        echo "$APP_NAME $VERSION"
    fi
}

authenticated_git() {
    if [[ -n "$GITHUB_TOKEN" ]]; then
        local authorization
        authorization="$(
            printf "%s" "x-access-token:$GITHUB_TOKEN" \
                | /usr/bin/base64 \
                | /usr/bin/tr -d '\n'
        )"
        git -c "http.https://github.com/.extraheader=AUTHORIZATION: basic $authorization" "$@"
    else
        git "$@"
    fi
}

github_api() {
    local method="$1"
    local url="$2"
    local data_file="${3:-}"
    typeset -a args

    require_value "SWIFTRIP_GITHUB_TOKEN" "$GITHUB_TOKEN"

    args=(
        -fsS
        -X "$method"
        -H "Accept: application/vnd.github+json"
        -H "Authorization: Bearer $GITHUB_TOKEN"
        -H "X-GitHub-Api-Version: 2022-11-28"
    )

    if [[ -n "$data_file" ]]; then
        args+=(-H "Content-Type: application/json" --data-binary "@$data_file")
    fi

    /usr/bin/curl "${args[@]}" "$url"
}

json_field() {
    local field="$1"
    /usr/bin/python3 - "$field" <<'PY'
import json
import sys

field = sys.argv[1]
value = json.load(sys.stdin)
for part in field.split("."):
    value = value[part]
print(value)
PY
}

asset_id_for_name() {
    local asset_name="$1"
    /usr/bin/python3 - "$asset_name" <<'PY'
import json
import sys

asset_name = sys.argv[1]
for asset in json.load(sys.stdin):
    if asset.get("name") == asset_name:
        print(asset.get("id", ""))
        break
PY
}

release_payload_file() {
    local target_commitish="$1"
    local payload_path="$2"
    local notes_path="$3"

    release_notes_body > "$notes_path"

    /usr/bin/python3 - "$RELEASE_TAG" "$target_commitish" "$RELEASE_TITLE" "$PRERELEASE" "$notes_path" > "$payload_path" <<'PY'
import json
import sys

tag_name, target_commitish, title, prerelease, notes_path = sys.argv[1:6]
with open(notes_path, encoding="utf-8") as handle:
    body = handle.read()

json.dump(
    {
        "tag_name": tag_name,
        "target_commitish": target_commitish,
        "name": title,
        "body": body,
        "prerelease": prerelease.lower() == "true",
    },
    sys.stdout,
)
PY
}

github_upload_release_asset() {
    local release_id="$1"
    local upload_url="$2"
    local asset_path="$3"
    local asset_name
    local asset_id
    local assets_json
    local upload_base_url="${upload_url%%\{*}"

    asset_name="$(basename "$asset_path")"
    assets_json="$(github_api GET "https://api.github.com/repos/$OWNER_REPO/releases/$release_id/assets?per_page=100")"
    asset_id="$(printf "%s" "$assets_json" | asset_id_for_name "$asset_name")"

    if [[ -n "$asset_id" ]]; then
        if [[ "$ALLOW_CLOBBER" != "1" ]]; then
            echo "ERROR: Release asset already exists: $asset_name"
            echo "Set SWIFTRIP_RELEASE_ALLOW_CLOBBER=1 to replace existing release assets."
            exit 1
        fi

        github_api DELETE "https://api.github.com/repos/$OWNER_REPO/releases/assets/$asset_id" >/dev/null
    fi

    /usr/bin/curl \
        -fsS \
        -X POST \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "Content-Type: application/octet-stream" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        --data-binary "@$asset_path" \
        "$upload_base_url?name=$asset_name" \
        >/dev/null
}

create_or_update_release_with_api() {
    local release_json
    local release_id
    local upload_url
    local current_target
    local payload_path
    local notes_path

    require_command /usr/bin/curl
    require_command /usr/bin/python3
    require_value "SWIFTRIP_GITHUB_TOKEN" "$GITHUB_TOKEN"

    if release_json="$(github_api GET "https://api.github.com/repos/$OWNER_REPO/releases/tags/$RELEASE_TAG" 2>/dev/null)"; then
        if [[ "$ALLOW_CLOBBER" != "1" ]]; then
            echo "ERROR: GitHub release already exists: $RELEASE_TAG"
            echo "Set SWIFTRIP_RELEASE_ALLOW_CLOBBER=1 to replace existing release assets."
            exit 1
        fi
    else
        current_target="${SWIFTRIP_RELEASE_TARGET:-${CI_TAG:-${CI_BRANCH:-}}}"
        if [[ -z "$current_target" ]]; then
            current_target="$(git -C "$ROOT_DIR" rev-parse HEAD)"
        fi

        payload_path="$(/usr/bin/mktemp)"
        notes_path="$(/usr/bin/mktemp)"
        release_payload_file "$current_target" "$payload_path" "$notes_path"
        release_json="$(github_api POST "https://api.github.com/repos/$OWNER_REPO/releases" "$payload_path")"
        /bin/rm -f "$payload_path" "$notes_path"
    fi

    release_id="$(printf "%s" "$release_json" | json_field id)"
    upload_url="$(printf "%s" "$release_json" | json_field upload_url)"

    for asset_path in "${RELEASE_ASSET_PATHS[@]}"; do
        github_upload_release_asset "$release_id" "$upload_url" "$asset_path"
    done
}

ensure_pages_worktree() {
    local origin_url
    if [[ -n "$GITHUB_TOKEN" ]]; then
        origin_url="https://github.com/$OWNER_REPO.git"
    else
        origin_url="$(git -C "$ROOT_DIR" remote get-url origin)"
    fi
    refuse_unsafe_path "$PAGES_WORKTREE" "GitHub Pages worktree" "$ROOT_DIR"

    if [[ -d "$PAGES_WORKTREE/.git" ]]; then
        authenticated_git -C "$PAGES_WORKTREE" checkout gh-pages
        authenticated_git -C "$PAGES_WORKTREE" pull --ff-only origin gh-pages
        return
    fi

    /bin/rm -rf "$PAGES_WORKTREE"
    if ! authenticated_git clone --branch gh-pages --single-branch "$origin_url" "$PAGES_WORKTREE"; then
        echo "ERROR: Could not clone the existing gh-pages publishing branch."
        exit 1
    fi
}

publish_appcasts() {
    ensure_pages_worktree

    /usr/bin/touch "$PAGES_WORKTREE/.nojekyll"
    /bin/cp "$APPCAST_WORK_DIR/appcast.xml" "$PAGES_WORKTREE/appcast.xml"

    # Compatibility for released builds whose SUFeedURL still points at an
    # architecture-specific appcast. New builds use appcast.xml.
    /bin/cp "$APPCAST_WORK_DIR/appcast.xml" "$PAGES_WORKTREE/appcast-arm64.xml"
    /bin/cp "$APPCAST_WORK_DIR/appcast.xml" "$PAGES_WORKTREE/appcast-x86_64.xml"

    authenticated_git -C "$PAGES_WORKTREE" add .nojekyll appcast.xml appcast-arm64.xml appcast-x86_64.xml
    if authenticated_git -C "$PAGES_WORKTREE" diff --cached --quiet; then
        echo "GitHub Pages appcasts are already current."
        return
    fi

    authenticated_git -C "$PAGES_WORKTREE" config user.name "${GIT_AUTHOR_NAME:-SwiftRip Release Automation}"
    authenticated_git -C "$PAGES_WORKTREE" config user.email "${GIT_AUTHOR_EMAIL:-actions@users.noreply.github.com}"
    authenticated_git -C "$PAGES_WORKTREE" commit -m "Publish Sparkle appcasts for $VERSION"
    authenticated_git -C "$PAGES_WORKTREE" push origin gh-pages
}

create_or_update_release() {
    local release_note_args
    release_note_args=("${(@f)$(release_notes_arg)}")

    if ! command -v gh >/dev/null 2>&1; then
        create_or_update_release_with_api
        return
    fi

    if gh release view "$RELEASE_TAG" --repo "$OWNER_REPO" >/dev/null 2>&1; then
        if [[ "$ALLOW_CLOBBER" != "1" ]]; then
            echo "ERROR: GitHub release already exists: $RELEASE_TAG"
            echo "Set SWIFTRIP_RELEASE_ALLOW_CLOBBER=1 to replace existing release assets."
            exit 1
        fi

        gh release upload "$RELEASE_TAG" "${RELEASE_ASSET_PATHS[@]}" --repo "$OWNER_REPO" --clobber
        return
    fi

    local current_branch
    current_branch="${SWIFTRIP_RELEASE_TARGET:-$(git -C "$ROOT_DIR" branch --show-current)}"
    if [[ -z "$current_branch" ]]; then
        current_branch="$(git -C "$ROOT_DIR" rev-parse HEAD)"
    fi

    typeset -a release_args
    release_args=(release create "$RELEASE_TAG" "${RELEASE_ASSET_PATHS[@]}" --repo "$OWNER_REPO" --target "$current_branch" --title "$RELEASE_TITLE" "${release_note_args[@]}")
    if [[ "$PRERELEASE" == true ]]; then
        release_args+=(--prerelease)
    fi

    gh "${release_args[@]}"
}

require_command git
require_executable "$RELEASE_ZIP_SCRIPT"

if [[ -z "$VERSION" ]]; then
    VERSION="$(build_setting MARKETING_VERSION)"
fi
if [[ -z "$VERSION" ]]; then
    echo "ERROR: Could not determine MARKETING_VERSION. Pass --version."
    exit 1
fi

RELEASE_TAG="${RELEASE_TAG:-v$VERSION}"
RELEASE_TITLE="${RELEASE_TITLE:-$APP_NAME $VERSION}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/dist/$VERSION}"
if [[ "$SKIP_NOTARIZATION" == false && -z "$NOTARY_PROFILE" && ( -z "$NOTARY_APPLE_ID" || -z "$NOTARY_PASSWORD" ) ]]; then
    echo "ERROR: Notarization needs --notary-profile, Apple notarization secrets, or --skip-notarization."
    exit 1
fi

echo "SwiftRip Sparkle release"
echo "Version:        $VERSION"
echo "Tag:            $RELEASE_TAG"
echo "Repository:     $OWNER_REPO"
echo "Output:         $OUTPUT_DIR"
echo "Appcast work:   $APPCAST_WORK_DIR"
echo "Pages worktree: $PAGES_WORKTREE"

/bin/mkdir -p "$OUTPUT_DIR" "$APPCAST_WORK_DIR"

typeset -a release_zip_args
release_zip_args=(--output-dir "$OUTPUT_DIR")

if [[ "$SKIP_NOTARIZATION" == true ]]; then
    release_zip_args+=(--skip-notarization)
elif [[ -n "$NOTARY_PROFILE" ]]; then
    release_zip_args+=(--notary-profile "$NOTARY_PROFILE")
fi

"$RELEASE_ZIP_SCRIPT" "${release_zip_args[@]}"

if [[ -z "$GENERATE_APPCAST" ]]; then
    GENERATE_APPCAST="$(find_generate_appcast)"
fi
require_executable "$GENERATE_APPCAST"

zip_path="$OUTPUT_DIR/$APP_NAME-$VERSION.zip"
if [[ ! -f "$zip_path" ]]; then
    echo "ERROR: Expected ZIP was not created: $zip_path"
    exit 1
fi

RELEASE_ASSET_PATHS+=("$zip_path")

create_or_update_release

refuse_unsafe_path "$APPCAST_WORK_DIR" "appcast work directory" "$ROOT_DIR"
/bin/rm -rf "$APPCAST_WORK_DIR"
/bin/mkdir -p "$APPCAST_WORK_DIR"

appcast_dir="$APPCAST_WORK_DIR/release"
/bin/mkdir -p "$appcast_dir"
/bin/cp "$zip_path" "$appcast_dir/"

appcast_args=(
    --download-url-prefix "https://github.com/$OWNER_REPO/releases/download/$RELEASE_TAG/"
    -o "$APPCAST_WORK_DIR/appcast.xml"
)

if [[ -n "$SPARKLE_ED_KEY" ]]; then
    printf "%s" "$SPARKLE_ED_KEY" | "$GENERATE_APPCAST" "${appcast_args[@]}" --ed-key-file - "$appcast_dir"
else
    "$GENERATE_APPCAST" "${appcast_args[@]}" "$appcast_dir"
fi

publish_appcasts

echo ""
echo "Sparkle release is published:"
echo "https://github.com/$OWNER_REPO/releases/tag/$RELEASE_TAG"
echo "https://fahlman.github.io/SwiftRip/appcast.xml"
