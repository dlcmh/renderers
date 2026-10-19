# 0001 — Empty launch window

- **Status:** Complete
- **Verified:** 2026-10-19 on macOS 26.6.2, arm64, Swift 6.3.3, Rust 1.97.1,
  Apple Clang 21.0.0, CMake 4.4.4

Part of the [renderers](../README.md) task series. Repository rules:
[AGENTS.md](../AGENTS.md).

## Goal

Prove the local macOS toolchain can build and launch a native game-window shell,
and compare six implementations of the same objective:

- Swift against AppKit, then against Metal.
- Rust against AppKit, then against Metal.
- C++ (Objective-C++) against AppKit, then against Metal.

The Rust and C++ variants are direct ports, not wrappers around a windowing or
rendering framework.

**Direction:** the CPU/AppKit variants are baselines for comparison only. New
rendering work in this repository is GPU-only; see
[Strategic direction](../docs/STRATEGY.md) and ADR-0012 in
[docs/DECISIONS.md](../docs/DECISIONS.md).

## Non-goals

- Rendering geometry, shaders, or assets.
- Input handling beyond quitting.
- A continuous animation or game loop.
- A cross-platform windowing abstraction.
- Sharing code between the six variants.

## Variants

| Stack | Path | Run | Surface |
| --- | --- | --- | --- |
| Swift / AppKit | [`swift-appkit/`](swift-appkit/) | `cd swift-appkit && swift run` | Black, CPU-drawn |
| Swift / Metal | [`swift-metal/`](swift-metal/) | `cd swift-metal && swift run` | Dark blue, GPU clear |
| Rust / AppKit | [`rust-appkit/`](rust-appkit/) | `cd rust-appkit && cargo run` | Black, CPU-drawn |
| Rust / Metal | [`rust-metal/`](rust-metal/) | `cd rust-metal && cargo run` | Dark blue, GPU clear |
| C++ / AppKit | [`cpp-appkit/`](cpp-appkit/) | [CMake commands](cpp-appkit/README.md#run) | Black, CPU-drawn |
| C++ / Metal | [`cpp-metal/`](cpp-metal/) | [CMake commands](cpp-metal/README.md#run) | Dark blue, GPU clear |

## Acceptance criteria

- [x] Each variant builds with its documented command.
- [x] Each variant opens a centered, resizable 1280×720 window.
- [x] AppKit variants fill the content view black; Metal variants clear a drawable
      to dark blue.
- [x] Closing the window, pressing Escape, or pressing ⌘Q quits the app.
- [x] Each window is reported on screen with layer 0 by the window server.

## Verification

Build and launch any variant from the repository root. The wrapper keeps all
build artifacts under `/tmp/renderers`:

```sh
./scripts/run.sh swift-appkit
./scripts/run.sh swift-metal
./scripts/run.sh rust-appkit
./scripts/run.sh rust-metal
./scripts/run.sh cpp-appkit
./scripts/run.sh cpp-metal
```

The underlying tool commands are documented in each variant README. The language
checks also use the external build root:

```sh
./scripts/check-swift.sh
./scripts/check-rust.sh
./scripts/check-cpp.sh
```

Confirm each window through the macOS window server. A temporary
`CGWindowListCopyWindowInfo` script reported on-screen windows owned by
`EmptyGameWindow`, `MetalLaunchWindow`, `rust-appkit`, `rust-metal`, `cpp-appkit`,
and `cpp-metal`, each at layer 0 with a 1280×752 outer frame (720pt content plus
title bar). Quit each app afterward; no process should remain.

Screen capture is available with Screen Recording permission; all six variants
were captured on 2026-10-19 and showed the expected black or dark blue surfaces.

Remove all in-repo and external build artifacts with:

```sh
./scripts/clean.sh --dry-run
./scripts/clean.sh
```

## Notes

- Swift variants are SwiftPM executables with a macOS 14 deployment target and no
  third-party dependencies.
- Rust variants live in a Cargo workspace at the task root. They use `objc2` and
  its AppKit/Metal/QuartzCore bindings as thin language bindings, not as a
  windowing framework. `Cargo.lock` is committed.
- Rust unsafe code is limited to the FFI and AppKit override seams, and every
  unsafe block carries a `// SAFETY:` explanation enforced by Clippy.
- C++ variants are Objective-C++ (`.mm`) because AppKit and Metal are
  Objective-C APIs. They use ARC, one shared CMake project at the task root, and
  compile with `-Wall -Wextra -Wpedantic -Werror`. The check script also builds an
  AddressSanitizer/UndefinedBehaviorSanitizer configuration.
- Builds are ephemeral: the helper scripts use `/tmp/renderers`, overridable with
  `RENDERERS_BUILD_ROOT`. `scripts/clean.sh` removes the external root and any
  legacy in-repo build directories.
- The variants intentionally duplicate window and app-lifecycle code so each can
  be read in isolation. Shared abstractions are deferred until a later task
  demonstrates the need.
- Every variant installs a minimal application menu with a standard Quit item so
  ⌘Q quits, in addition to closing the window or pressing Escape.
- Deeper Metal teaching notes live in the
  [Swift Metal README](swift-metal/README.md),
  [Rust Metal README](rust-metal/README.md), and
  [C++ Metal README](cpp-metal/README.md).
- Shared terminology and portability guidance live in
  [Graphics concepts and portability](../docs/GRAPHICS-CONCEPTS.md).
