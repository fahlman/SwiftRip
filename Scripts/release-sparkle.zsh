#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RELEASE_DMG_SCRIPT="$ROOT_DIR/Scripts/release-dmg.zsh"
PROJECT_PATH="$ROOT_DIR/SwiftRip.xcodeproj"
SCHEME="SwiftRip"
APP_NAME="SwiftRip"
OWNER_REPO="${SWIFTRIP_GITHUB_REPO:-fahlman/SwiftRip}"
VERSION=""
RELEASE_TAG=""
RELEASE_TITLE=""
NOTES_FILE=""
NOTARY_PROFILE="${SWIFTRIP_NOTARY_PROFILE:-}"
OUTPUT_DIR=""
PAGES_WORKTREE="${SWIFTRIP_PAGES_WORKTREE:-${TMPDIR:-/private/tmp}/swiftrip-gh-pages-publish}"
APPCAST_WORK_DIR="${SWIFTRIP_APPCAST_WORK_DIR:-${TMPDIR:-/private/tmp}/swiftrip-appcasts}"
GENERATE_APPCAST="${SWIFTRIP_GENERATE_APPCAST:-}"
SKIP_NOTARIZATION=false
PRERELEASE=false
typeset -a DMG_PATHS

usage() {
    cat <<'USAGE'
Usage: Scripts/release-sparkle.zsh [options]

Build both architecture-specific DMGs, upload them to a GitHub release,
generate Sparkle appcasts, and publish the appcasts to GitHub Pages.

Options:
  --version VERSION         Release version. Defaults to MARKETING_VERSION.
  --release-tag TAG         GitHub release tag. Defaults to vVERSION.
  --title TITLE             GitHub release title. Defaults to SwiftRip VERSION.
  --notes-file PATH         Release notes file for gh release create.
  --notary-profile NAME     notarytool keychain profile name.
  --skip-notarization       Pass through to release-dmg.zsh.
  --prerelease              Mark a newly created GitHub release as a prerelease.
  --output-dir PATH         Directory for built DMGs. Defaults to ./dist/VERSION.
  --pages-worktree PATH     Local gh-pages checkout/worktree.
  --generate-appcast PATH   Sparkle generate_appcast executable.
  -h, --help                Show this help.

Environment variables:
  SWIFTRIP_GITHUB_REPO
  SWIFTRIP_NOTARY_PROFILE
  SWIFTRIP_PAGES_WORKTREE
  SWIFTRIP_APPCAST_WORK_DIR
  SWIFTRIP_GENERATE_APPCAST
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

require_command() {
    local command_name="$1"
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "ERROR: Missing required command: $command_name"
        exit 1
    fi
}

require_executable() {
    local executable_path="$1"
    if [[ ! -x "$executable_path" ]]; then
        echo "ERROR: Missing executable: $executable_path"
        exit 1
    fi
}

refuse_unsafe_path() {
    local path_to_check="${1:A}"
    local label="$2"

    case "$path_to_check" in
        "/"|"$HOME"|"$ROOT_DIR"|"$ROOT_DIR"/*)
            echo "ERROR: Refusing to use unsafe $label: $path_to_check"
            exit 1
            ;;
    esac
}

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
    if [[ ! -d "$derived_data" ]]; then
        return
    fi

    /usr/bin/find "$derived_data" \
        -path "*/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast" \
        -type f \
        -print \
        | /usr/bin/tail -n 1
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

ensure_pages_worktree() {
    local origin_url
    origin_url="$(git -C "$ROOT_DIR" remote get-url origin)"
    refuse_unsafe_path "$PAGES_WORKTREE" "GitHub Pages worktree"

    if [[ -d "$PAGES_WORKTREE/.git" ]]; then
        git -C "$PAGES_WORKTREE" checkout gh-pages
        git -C "$PAGES_WORKTREE" pull --ff-only origin gh-pages
        return
    fi

    /bin/rm -rf "$PAGES_WORKTREE"
    if git ls-remote --exit-code --heads "$origin_url" gh-pages >/dev/null 2>&1; then
        git clone --branch gh-pages --single-branch "$origin_url" "$PAGES_WORKTREE"
        return
    fi

    /bin/mkdir -p "$PAGES_WORKTREE"
    git -C "$PAGES_WORKTREE" init
    git -C "$PAGES_WORKTREE" checkout --orphan gh-pages
    git -C "$PAGES_WORKTREE" remote add origin "$origin_url"
}

publish_appcasts() {
    ensure_pages_worktree

    /usr/bin/touch "$PAGES_WORKTREE/.nojekyll"
    for arch in arm64 x86_64; do
        /bin/cp "$APPCAST_WORK_DIR/$arch/appcast-$arch.xml" "$PAGES_WORKTREE/appcast-$arch.xml"
    done

    git -C "$PAGES_WORKTREE" add .nojekyll appcast-arm64.xml appcast-x86_64.xml
    if git -C "$PAGES_WORKTREE" diff --cached --quiet; then
        echo "GitHub Pages appcasts are already current."
        return
    fi

    git -C "$PAGES_WORKTREE" commit -m "Publish Sparkle appcasts for $VERSION"
    git -C "$PAGES_WORKTREE" push
}

create_or_update_release() {
    local release_note_args
    release_note_args=("${(@f)$(release_notes_arg)}")

    if gh release view "$RELEASE_TAG" --repo "$OWNER_REPO" >/dev/null 2>&1; then
        gh release upload "$RELEASE_TAG" "${DMG_PATHS[@]}" --repo "$OWNER_REPO" --clobber
        return
    fi

    local current_branch
    current_branch="$(git -C "$ROOT_DIR" branch --show-current)"

    typeset -a release_args
    release_args=(release create "$RELEASE_TAG" "${DMG_PATHS[@]}" --repo "$OWNER_REPO" --target "$current_branch" --title "$RELEASE_TITLE" "${release_note_args[@]}")
    if [[ "$PRERELEASE" == true ]]; then
        release_args+=(--prerelease)
    fi

    gh "${release_args[@]}"
}

require_command gh
require_command git
require_executable "$RELEASE_DMG_SCRIPT"

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
GENERATE_APPCAST="$(find_generate_appcast)"
require_executable "$GENERATE_APPCAST"

if [[ "$SKIP_NOTARIZATION" == false && -z "$NOTARY_PROFILE" ]]; then
    echo "ERROR: Notarization needs --notary-profile, or use --skip-notarization."
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

for arch in arm64 x86_64; do
    typeset -a release_dmg_args
    release_dmg_args=(--arch "$arch" --output-dir "$OUTPUT_DIR")

    if [[ "$SKIP_NOTARIZATION" == true ]]; then
        release_dmg_args+=(--skip-notarization)
    else
        release_dmg_args+=(--notary-profile "$NOTARY_PROFILE")
    fi

    "$RELEASE_DMG_SCRIPT" "${release_dmg_args[@]}"

    dmg_path="$OUTPUT_DIR/$APP_NAME-$VERSION-$arch.dmg"
    if [[ ! -f "$dmg_path" ]]; then
        echo "ERROR: Expected DMG was not created: $dmg_path"
        exit 1
    fi

    DMG_PATHS+=("$dmg_path")
done

create_or_update_release

refuse_unsafe_path "$APPCAST_WORK_DIR" "appcast work directory"
/bin/rm -rf "$APPCAST_WORK_DIR"
/bin/mkdir -p "$APPCAST_WORK_DIR"

for arch in arm64 x86_64; do
    appcast_dir="$APPCAST_WORK_DIR/$arch"
    /bin/mkdir -p "$appcast_dir"
    /bin/cp "$OUTPUT_DIR/$APP_NAME-$VERSION-$arch.dmg" "$appcast_dir/"

    "$GENERATE_APPCAST" \
        --download-url-prefix "https://github.com/$OWNER_REPO/releases/download/$RELEASE_TAG/" \
        -o "$appcast_dir/appcast-$arch.xml" \
        "$appcast_dir"
done

publish_appcasts

echo ""
echo "Sparkle release is published:"
echo "https://github.com/$OWNER_REPO/releases/tag/$RELEASE_TAG"
echo "https://fahlman.github.io/SwiftRip/appcast-arm64.xml"
echo "https://fahlman.github.io/SwiftRip/appcast-x86_64.xml"
