#!/usr/bin/env bash
# Format-check, build, and sanitizer-build the C++ task variants.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
task_root="$repo_root/0001-empty-launch-window"

if command -v clang-format >/dev/null 2>&1; then
    clang_format="clang-format"
else
    clang_format="$(xcrun --find clang-format)"
fi

cd "$task_root"

"$clang_format" --dry-run --Werror \
    cpp-appkit/src/main.mm \
    cpp-metal/src/main.mm

cmake -S . -B build-cpp -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build build-cpp

cmake -S . -B build-cpp-asan -G Ninja \
    -DCMAKE_BUILD_TYPE=Debug \
    -DENABLE_SANITIZERS=ON
cmake --build build-cpp-asan

echo "C++ checks passed."
