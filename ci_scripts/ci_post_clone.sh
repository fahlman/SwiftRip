#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPOSITORY_DIR="${CI_PRIMARY_REPOSITORY_PATH:-}"

if [[ -z "$REPOSITORY_DIR" || ! -d "$REPOSITORY_DIR" ]]; then
    REPOSITORY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

if [[ -n "${CI_WORKSPACE:-}" && ! -d "$REPOSITORY_DIR/SwiftRipTools" && -d "$CI_WORKSPACE/repository" ]]; then
    REPOSITORY_DIR="$CI_WORKSPACE/repository"
fi

FETCH_SCRIPT="$REPOSITORY_DIR/SwiftRipTools/Scripts/fetch-swiftrip-tools.zsh"

echo "Xcode Cloud post-clone setup"
echo "Repository: $REPOSITORY_DIR"

if [[ ! -x "$FETCH_SCRIPT" ]]; then
    echo "ERROR: SwiftRipTools fetch script is not executable:"
    echo "$FETCH_SCRIPT"
    exit 1
fi

for arch in arm64 x86_64; do
    echo ""
    echo "Fetching SwiftRipTools artifacts for $arch..."
    "$FETCH_SCRIPT" --arch "$arch"
done

echo ""
echo "Xcode Cloud post-clone setup complete."
