#!/usr/bin/env bash
# Build and run one task variant with all artifacts outside the repository.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
task_root="$repo_root/0001-empty-launch-window"
build_root="${RENDERERS_BUILD_ROOT:-/tmp/renderers}"

if [[ "$build_root" != /* || "$build_root" == "/" || "$build_root" == "$repo_root" ||
    "$build_root" == "$repo_root"/* ]]; then
    echo "refusing unsafe RENDERERS_BUILD_ROOT: $build_root" >&2
    exit 1
fi

usage() {
    cat <<EOF
Usage: $(basename "$0") <variant>

Builds and runs one variant with artifacts under:
  $build_root

Variants:
  swift-appkit
  swift-metal
  rust-appkit
  rust-metal
  cpp-appkit
  cpp-metal

Override the build root with RENDERERS_BUILD_ROOT.
EOF
}

if [[ $# -ne 1 ]]; then
    usage >&2
    exit 2
fi

variant="$1"

case "$variant" in
    swift-appkit | swift-metal)
        echo "building $variant with SwiftPM scratch path $build_root/$variant"
        cd "$task_root/$variant"
        exec swift run --scratch-path "$build_root/$variant"
        ;;
    rust-appkit | rust-metal)
        echo "building $variant with Cargo target dir $build_root/rust-target"
        cd "$task_root"
        CARGO_TARGET_DIR="$build_root/rust-target" exec cargo run -p "$variant"
        ;;
    cpp-appkit | cpp-metal)
        # Separate build dirs so concurrent run.sh calls do not race CMake's
        # configure step. check-cpp.sh still builds both targets in one dir.
        build_dir="$build_root/$variant"
        echo "building $variant with CMake build dir $build_dir"
        cmake -S "$task_root" -B "$build_dir" -G Ninja -DCMAKE_BUILD_TYPE=Debug
        cmake --build "$build_dir" --target "$variant"
        exec "$build_dir/$variant"
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac
