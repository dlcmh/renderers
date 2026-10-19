#!/usr/bin/env bash
# Format, lint, build, and test every Rust crate with artifacts outside the repo.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_root="${RENDERERS_BUILD_ROOT:-/tmp/renderers}"

if [[ "$build_root" != /* || "$build_root" == "/" || "$build_root" == "$repo_root" ||
    "$build_root" == "$repo_root"/* ]]; then
    echo "refusing unsafe RENDERERS_BUILD_ROOT: $build_root" >&2
    exit 1
fi

# Each task has its own Cargo workspace so the tasks stay independent. The
# script runs the same checks for every one of them.
tasks=(
    "0001-empty-launch-window"
    "0002-first-triangle"
)

for task in "${tasks[@]}"; do
    workspace="$repo_root/$task"
    export CARGO_TARGET_DIR="$build_root/$task-rust-target"
    echo "== $task =="
    (
        cd "$workspace"
        cargo fmt --all -- --check
        cargo clippy --workspace --all-targets -- -D warnings
        cargo build --workspace
        cargo test --workspace
    )
done

echo "Rust checks passed (artifacts under $build_root)."
