#!/usr/bin/env bash
# Format, lint, build, and test every Rust crate in the task workspace.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workspace="$repo_root/0001-empty-launch-window"

cd "$workspace"

cargo fmt --all -- --check
cargo clippy --workspace --all-targets -- -D warnings
cargo build --workspace
cargo test --workspace

echo "Rust checks passed."
