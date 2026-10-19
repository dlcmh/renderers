#!/usr/bin/env bash
# Build both Swift variants with artifacts outside the repository.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
task_root="$repo_root/0001-empty-launch-window"
build_root="${RENDERERS_BUILD_ROOT:-/tmp/renderers}"

if [[ "$build_root" != /* || "$build_root" == "/" || "$build_root" == "$repo_root" ||
    "$build_root" == "$repo_root"/* ]]; then
    echo "refusing unsafe RENDERERS_BUILD_ROOT: $build_root" >&2
    exit 1
fi

for variant in swift-appkit swift-metal; do
    echo "building $variant with SwiftPM scratch path $build_root/$variant"
    (
        cd "$task_root/$variant"
        swift build --scratch-path "$build_root/$variant"
    )
done

echo "Swift checks passed (artifacts in $build_root/swift-appkit and $build_root/swift-metal)."
