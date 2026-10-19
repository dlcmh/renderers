#!/usr/bin/env bash
# Build and run one task variant with all artifacts outside the repository.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
task_0001="$repo_root/0001-empty-launch-window"
task_0002="$repo_root/0002-first-triangle"
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
  0001: swift-appkit (frozen), swift-metal (frozen),
        rust-appkit, rust-metal, cpp-appkit, cpp-metal
  0002: rust-metal-triangle, cpp-metal-triangle

Override the build root with RENDERERS_BUILD_ROOT.
EOF
}

if [[ $# -ne 1 ]]; then
    usage >&2
    exit 2
fi

variant="$1"

run_swift() {
    local task_dir="$1"
    local name="$2"
    echo "building $name with SwiftPM scratch path $build_root/$name"
    cd "$task_dir/$name"
    exec swift run --scratch-path "$build_root/$name"
}

run_rust() {
    local task_dir="$1"
    local name="$2"
    echo "building $name with Cargo target dir $build_root/$name-target"
    cd "$task_dir"
    CARGO_TARGET_DIR="$build_root/$name-target" exec cargo run -p "$name"
}

run_cpp() {
    local task_dir="$1"
    local name="$2"
    # A dedicated build dir per variant so concurrent run.sh calls do not race
    # CMake's configure step. The check scripts still build all targets in one dir.
    local build_dir="$build_root/$name"
    echo "building $name with CMake build dir $build_dir"
    cmake -S "$task_dir" -B "$build_dir" -G Ninja -DCMAKE_BUILD_TYPE=Debug
    cmake --build "$build_dir" --target "$name"
    exec "$build_dir/$name"
}

case "$variant" in
    swift-appkit | swift-metal)
        run_swift "$task_0001" "$variant"
        ;;
    rust-appkit | rust-metal)
        run_rust "$task_0001" "$variant"
        ;;
    cpp-appkit | cpp-metal)
        run_cpp "$task_0001" "$variant"
        ;;
    rust-metal-triangle)
        run_rust "$task_0002" "$variant"
        ;;
    cpp-metal-triangle)
        run_cpp "$task_0002" "$variant"
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac
