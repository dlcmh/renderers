# 0001 — Empty launch window

- **Status:** Complete
- **Verified:** 2026-10-19 on macOS 26.6.2, arm64, Swift 6.3.3, Rust 1.97.1

Part of the [renderers](../README.md) task series. Repository rules:
[AGENTS.md](../AGENTS.md).

## Goal

Prove the local macOS toolchain can build and launch a native game-window shell,
and compare four implementations of the same objective:

- Swift against AppKit, then against Metal.
- Rust against AppKit, then against Metal.

The Rust variants are direct ports, not wrappers around a windowing or rendering
framework.

## Non-goals

- Rendering geometry, shaders, or assets.
- Input handling beyond quitting.
- A continuous animation or game loop.
- A cross-platform windowing abstraction.
- Sharing code between the four variants.

## Variants

| Stack | Path | Run | Surface |
| --- | --- | --- | --- |
| Swift / AppKit | [`swift-appkit/`](swift-appkit/) | `cd swift-appkit && swift run` | Black, CPU-drawn |
| Swift / Metal | [`swift-metal/`](swift-metal/) | `cd swift-metal && swift run` | Dark blue, GPU clear |
| Rust / AppKit | [`rust-appkit/`](rust-appkit/) | `cd rust-appkit && cargo run` | Black, CPU-drawn |
| Rust / Metal | [`rust-metal/`](rust-metal/) | `cd rust-metal && cargo run` | Dark blue, GPU clear |

## Acceptance criteria

- [x] Each variant builds with its documented command.
- [x] Each variant opens a centered, resizable 1280×720 window.
- [x] AppKit variants fill the content view black; Metal variants clear a drawable
      to dark blue.
- [x] Closing the window, pressing Escape, or pressing ⌘Q quits the app.
- [x] Each window is reported on screen with layer 0 by the window server.

## Verification

Build and launch the Swift variants from their directories:

```sh
cd swift-appkit
swift build
.build/debug/EmptyGameWindow
```

```sh
cd swift-metal
swift build
.build/debug/MetalLaunchWindow
```

Build and launch the Rust variants from their directories:

```sh
cd rust-appkit
cargo run
```

```sh
cd rust-metal
cargo run
```

The full Rust check (fmt, clippy with warnings denied, build, test) runs from the
repository root:

```sh
./scripts/check-rust.sh
```

Confirm each window through the macOS window server. A temporary
`CGWindowListCopyWindowInfo` script reported on-screen windows owned by
`EmptyGameWindow`, `MetalLaunchWindow`, `rust-appkit`, and `rust-metal`, each at
layer 0 with a 1280×752 outer frame (720pt content plus title bar). Quit each app
afterward; no process should remain.

Screen capture was unavailable because Screen Recording permission was not
granted; this does not affect the apps.

## Notes

- Swift variants are SwiftPM executables with a macOS 14 deployment target and no
  third-party dependencies.
- Rust variants live in a Cargo workspace at the task root. They use `objc2` and
  its AppKit/Metal/QuartzCore bindings as thin language bindings, not as a
  windowing framework. `Cargo.lock` is committed.
- Rust unsafe code is limited to the FFI and AppKit override seams, and every
  unsafe block carries a `// SAFETY:` explanation enforced by Clippy.
- The variants intentionally duplicate window and app-lifecycle code so each can
  be read in isolation. Shared abstractions are deferred until a later task
  demonstrates the need.
- Every variant installs a minimal application menu with a standard Quit item so
  ⌘Q quits, in addition to closing the window or pressing Escape.
- Deeper Metal teaching notes live in the
  [Swift Metal README](swift-metal/README.md) and
  [Rust Metal README](rust-metal/README.md).
- Shared terminology and portability guidance live in
  [Graphics concepts and portability](../docs/GRAPHICS-CONCEPTS.md).
