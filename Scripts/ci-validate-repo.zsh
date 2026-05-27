#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "Checking whitespace..."
git -C "$ROOT_DIR" diff --check

echo "Checking generated artifacts are not tracked..."
TRACKED_GENERATED="$(
    git -C "$ROOT_DIR" ls-files \
        .release \
        SwiftRipTools/Build \
        SwiftRipTools/Source \
        SwiftRipTools/Packages \
        SwiftRipTools/.DS_Store
)"
if [[ -n "$TRACKED_GENERATED" ]]; then
    echo "ERROR: Generated/vendor/build artifacts are tracked:"
    echo "$TRACKED_GENERATED"
    exit 1
fi

echo "Checking shell script syntax..."
while IFS= read -r script_path; do
    /bin/zsh -n "$ROOT_DIR/$script_path"
done < <(
    git -C "$ROOT_DIR" ls-files \
        'Scripts/*.zsh' \
        'Scripts/**/*.zsh' \
        'SwiftRipTools/Scripts/*.zsh' \
        'SwiftRipTools/Scripts/**/*.zsh'
)

echo "Checking JSON manifests..."
while IFS= read -r json_path; do
    /usr/bin/plutil -convert json -o /dev/null "$ROOT_DIR/$json_path"
done < <(
    git -C "$ROOT_DIR" ls-files \
        'SwiftRipTools/Manifest/*.json' \
        'SwiftRip/Resources/Presets/*.json'
)

echo "Repository validation passed."
