#!/usr/bin/env bash
# Format-check, build, and sanitizer-build the C++ task variants outside the repo.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
task_root="$repo_root/0001-empty-launch-window"
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

"$clang_format" --dry-run --Werror \
    "$task_root/cpp-appkit/src/main.mm" \
    "$task_root/cpp-metal/src/main.mm"

cmake -S "$task_root" -B "$build_root/cpp" -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build "$build_root/cpp"

cmake -S "$task_root" -B "$build_root/cpp-asan" -G Ninja \
    -DCMAKE_BUILD_TYPE=Debug \
    -DENABLE_SANITIZERS=ON
cmake --build "$build_root/cpp-asan"

echo "C++ checks passed (artifacts in $build_root/cpp and $build_root/cpp-asan)."
