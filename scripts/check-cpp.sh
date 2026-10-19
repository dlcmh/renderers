#!/usr/bin/env bash
# Format-check, build, and sanitizer-build every C++ task target outside the repo.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_root="${RENDERERS_BUILD_ROOT:-/tmp/renderers}"

if [[ "$build_root" != /* || "$build_root" == "/" || "$build_root" == "$repo_root" ||
    "$build_root" == "$repo_root"/* ]]; then
    echo "refusing unsafe RENDERERS_BUILD_ROOT: $build_root" >&2
    exit 1
fi

if command -v clang-format >/dev/null 2>&1; then
    clang_format="clang-format"
else
    clang_format="$(xcrun --find clang-format)"
fi

tasks=(
    "0001-empty-launch-window"
    "0002-first-triangle"
)

"$clang_format" --dry-run --Werror \
    "$repo_root/0001-empty-launch-window/cpp-appkit/src/main.mm" \
    "$repo_root/0001-empty-launch-window/cpp-metal/src/main.mm" \
    "$repo_root/0002-first-triangle/cpp-metal/src/main.mm"

for task in "${tasks[@]}"; do
    task_root="$repo_root/$task"
    echo "== $task =="
    cmake -S "$task_root" -B "$build_root/$task-cpp" -G Ninja -DCMAKE_BUILD_TYPE=Debug
    cmake --build "$build_root/$task-cpp"

    cmake -S "$task_root" -B "$build_root/$task-cpp-asan" -G Ninja \
        -DCMAKE_BUILD_TYPE=Debug \
        -DENABLE_SANITIZERS=ON
    cmake --build "$build_root/$task-cpp-asan"
done

echo "C++ checks passed (artifacts under $build_root)."
