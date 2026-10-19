#!/usr/bin/env bash
# Remove all build artifacts created by this repository, including the external
# /tmp build root. Nothing outside the known build paths is touched.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
task_root="$repo_root/0001-empty-launch-window"
task_0002="$repo_root/0002-first-triangle"
build_root="${RENDERERS_BUILD_ROOT:-/tmp/renderers}"
dry_run=false

case "${1:-}" in
    --dry-run)
        dry_run=true
        ;;
    -h | --help)
        cat <<EOF
Usage: $(basename "$0") [--dry-run]

Removes:
  - SwiftPM .build/.swiftpm directories
  - Rust target directories
  - CMake build directories from older in-repo builds
  - the external build root (default: /tmp/renderers)

Override the external root with RENDERERS_BUILD_ROOT.
EOF
        exit 0
        ;;
    "")
        ;;
    *)
        echo "unknown option: $1" >&2
        echo "usage: $(basename "$0") [--dry-run]" >&2
        exit 2
        ;;
esac

if [[ "$build_root" != /* || "$build_root" == "/" || "$build_root" == "$repo_root" ||
    "$build_root" == "$repo_root"/* ]]; then
    echo "refusing unsafe RENDERERS_BUILD_ROOT: $build_root" >&2
    exit 1
fi

remove_path() {
    local path="$1"

    if [[ ! -e "$path" && ! -L "$path" ]]; then
        return 0
    fi

    if [[ "$path" != "$repo_root"/* && "$path" != "$build_root" ]]; then
        echo "refusing to remove unexpected path: $path" >&2
        return 1
    fi

    if $dry_run; then
        echo "would remove $path"
    else
        rm -rf -- "$path"
        echo "removed $path"
    fi
}

# Known in-repo artifacts. Keep this list explicit; do not glob-delete source
# directories. The build scripts live outside the repo, but older checkouts may
# still contain these paths.
in_repo_paths=(
    "$task_root/swift-appkit/.build"
    "$task_root/swift-appkit/.swiftpm"
    "$task_root/swift-metal/.build"
    "$task_root/swift-metal/.swiftpm"
    "$task_root/target"
    "$task_root/rust-appkit/target"
    "$task_root/rust-metal/target"
    "$task_root/build-cpp"
    "$task_root/build-cpp-asan"
    "$task_root/build"
    "$task_0002/target"
    "$task_0002/rust-metal/target"
    "$task_0002/build"
    "$task_0002/build-cpp"
    "$task_0002/build-cpp-asan"
)

for path in "${in_repo_paths[@]}"; do
    remove_path "$path"
done

remove_path "$build_root"

if $dry_run; then
    echo "Dry run complete; nothing was deleted."
else
    echo "Build artifacts removed."
fi
