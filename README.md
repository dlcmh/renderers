# Renderers

A workbench of small, numbered experiments in rendering and game windows. The
goal is to learn how game renderers are built across platforms, from first
principles. Each task isolates one concept, stays runnable on its own, and
compares any materially new technique with the approach it replaces. The
repository is not a shared library.

## Start here

New to native graphics, or coming from web development? Read
[Graphics concepts and portability](docs/GRAPHICS-CONCEPTS.md) first. It defines
the vocabulary used throughout the repo — backend, RHI, surface, swapchain,
pipeline — and explains the platform tradeoffs, including Vulkan versus Direct3D
on Windows and the HarmonyOS host model.

## Tasks

| # | Task | Variants | Status |
| --- | --- | --- | --- |
| 0001 | [Empty launch window](0001-empty-launch-window/README.md) | [Swift (AppKit)](0001-empty-launch-window/swift-appkit/), [Swift (Metal)](0001-empty-launch-window/swift-metal/), [Rust (AppKit)](0001-empty-launch-window/rust-appkit/), [Rust (Metal)](0001-empty-launch-window/rust-metal/), [C++ (AppKit)](0001-empty-launch-window/cpp-appkit/), [C++ (Metal)](0001-empty-launch-window/cpp-metal/) | Complete |

New tasks get the next unused four-digit number and a kebab-case name. See
[AGENTS.md](AGENTS.md) for the full conventions and agent workflow.

## Quick start

Swift variants:

```sh
cd 0001-empty-launch-window/swift-appkit # CPU-drawn baseline
swift run
```

```sh
cd 0001-empty-launch-window/swift-metal # GPU-backed variant
swift run
```

Rust variants:

```sh
cd 0001-empty-launch-window
cargo run -p rust-appkit                  # CPU-drawn baseline
cargo run -p rust-metal                   # GPU-backed variant
```

C++ variants:

```sh
cd 0001-empty-launch-window
cmake -S . -B build-cpp -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build build-cpp
./build-cpp/cpp-appkit                    # CPU-drawn baseline
./build-cpp/cpp-metal                     # GPU-backed variant
```

All six open a centered, resizable 1280×720 window. AppKit windows are black;
Metal windows are dark blue. Close a window, press Escape, or press ⌘Q to quit.

Start with the Swift CPU baseline, then read [the Metal notes](0001-empty-launch-window/swift-metal/README.md#the-delta-at-a-glance)
for the comparison between `draw(_:)` and an explicit GPU render pass. The Rust
and C++ variants mirror the pair and show the same AppKit/Metal concepts through
their FFI boundaries.

## Requirements

- macOS 14 or newer
- Swift 6 toolchain (Xcode Command Line Tools or Xcode) for the Swift variants
- Rust 1.85+ and Cargo for the Rust variants; the repository pins Rust 1.97.1
- CMake 3.28+ and Apple Clang for the C++ variants; the documented commands use
  Ninja

The current setup was verified with macOS 26.6.2, Swift 6.3.3, Rust 1.97.1,
Apple Clang 21.0.0, and CMake 4.4.4 on arm64.

Run the language checks with:

```sh
./scripts/check-rust.sh
./scripts/check-cpp.sh
```

## Repository conventions

- One numbered directory per task: `NNNN-kebab-case-task/`.
- Each task has a README with its goal, acceptance criteria, and status.
- Each language variant is independent and has its own run instructions.
- Durable decisions are recorded in [docs/DECISIONS.md](docs/DECISIONS.md).
- Completed, verified work is committed and pushed to `origin/main`.

## Contributing

Read [AGENTS.md](AGENTS.md) first, whether you are an agent or a human. It covers
the task lifecycle, verification requirements, coding standards, and git policy.
