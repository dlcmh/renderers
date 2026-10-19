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

For where the project is heading — GPU-only rendering, a Vulkan backend for
non-Apple and Chinese GPUs, a separate compute seam, and what GPU-accelerated
Rust terminals teach — read
[Strategic direction](docs/STRATEGY.md).

## Tasks

| # | Task | Variants | Status |
| --- | --- | --- | --- |
| 0001 | [Empty launch window](0001-empty-launch-window/README.md) | [Rust (AppKit)](0001-empty-launch-window/rust-appkit/), [Rust (Metal)](0001-empty-launch-window/rust-metal/), [C++ (AppKit)](0001-empty-launch-window/cpp-appkit/), [C++ (Metal)](0001-empty-launch-window/cpp-metal/) | Complete |
| 0001 | (legacy) | [Swift (AppKit)](0001-empty-launch-window/swift-appkit/), [Swift (Metal)](0001-empty-launch-window/swift-metal/) | Frozen |
| 0002 | [First triangle](0002-first-triangle/README.md) | [Rust (Metal)](0002-first-triangle/rust-metal/), [C++ (Metal)](0002-first-triangle/cpp-metal/) | Complete |

New tasks get the next unused four-digit number and a kebab-case name. See
[AGENTS.md](AGENTS.md) for the full conventions and agent workflow.

Maintained stacks are **Rust and C++**. The Swift variants are frozen reference
material kept for the side-by-side comparison; they receive no new features (see
ADR-0015).

## Quick start

Build artifacts stay outside the repository by default. The wrapper configures,
builds, and runs one variant using the right toolchain:

```sh
./scripts/run.sh rust-appkit
./scripts/run.sh rust-metal
./scripts/run.sh cpp-appkit
./scripts/run.sh cpp-metal
./scripts/run.sh rust-metal-triangle
./scripts/run.sh cpp-metal-triangle
```

Artifacts go to `/tmp/renderers`. Override that location with
`RENDERERS_BUILD_ROOT`. Each variant README documents the underlying compiler
commands.

All variants open a centered, resizable 1280×720 window. AppKit windows are black;
Metal windows are dark blue. Close a window, press Escape, or press ⌘Q to quit.

Start with task 0001 to see a CPU baseline and the simplest GPU frame; then read
[the Metal notes](0001-empty-launch-window/swift-metal/README.md#the-delta-at-a-glance)
for CPU drawing versus an explicit GPU render pass. Task 0002 adds the shader
pipeline, vertex data, a draw call, and a display-link frame loop. The Rust and
C++ variants mirror both tasks and show the same concepts through their FFI
boundaries. The Swift variants remain available as a frozen reference.

## Cleanup

Preview and remove every artifact this repo knows how to create, including the
external build root:

```sh
./scripts/clean.sh --dry-run
./scripts/clean.sh
```

The script only removes known build paths; it does not touch source files. The
external root is configurable with `RENDERERS_BUILD_ROOT`.

## Requirements

- macOS 14 or newer
- Rust 1.85+ and Cargo for the Rust variants; the repository pins Rust 1.97.1
- CMake 3.28+ and Apple Clang for the C++ variants; the documented commands use
  Ninja
- Swift 6 toolchain only if you want to build the frozen Swift reference variants

The current setup was verified with macOS 26.6.2, Swift 6.3.3, Rust 1.97.1,
Apple Clang 21.0.0, and CMake 4.4.4 on arm64.

Run the maintained language checks with (both use the external build root):

```sh
./scripts/check-rust.sh
./scripts/check-cpp.sh
```

`./scripts/check-swift.sh` still builds the frozen Swift references.

## Repository conventions

- One numbered directory per task: `NNNN-kebab-case-task/`.
- Each task has a README with its goal, acceptance criteria, and status.
- Each language variant is independent and has its own run instructions.
- Maintained stacks are Rust and C++; Swift is frozen reference material.
- Builds default to `/tmp/renderers`; `scripts/clean.sh` removes all known
  artifacts, including the external build root.
- Durable decisions are recorded in [docs/DECISIONS.md](docs/DECISIONS.md).
- Completed, verified work is committed and pushed to `origin/main`.

## Contributing

Read [AGENTS.md](AGENTS.md) first, whether you are an agent or a human. It covers
the task lifecycle, verification requirements, coding standards, and git policy.
