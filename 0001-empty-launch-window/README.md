# 0001 — Empty launch window

- **Status:** Complete
- **Verified:** 2026-10-19 on macOS 26.6.2, arm64, Swift 6.3.3

Part of the [renderers](../README.md) task series. Repository rules:
[AGENTS.md](../AGENTS.md).

## Goal

Prove the local macOS toolchain can build and launch a native game-window shell,
and compare the CPU-drawn AppKit path with a GPU-backed Metal path.

## Non-goals

- Rendering geometry, shaders, or assets.
- Input handling beyond quitting.
- A continuous animation or game loop.
- A cross-platform windowing abstraction.

## Variants

| Stack | Path | Run | Surface |
| --- | --- | --- | --- |
| Swift / AppKit | [`swift-appkit/`](swift-appkit/) | `cd swift-appkit && swift run` | Black, CPU-drawn |
| Swift / Metal | [`swift-metal/`](swift-metal/) | `cd swift-metal && swift run` | Dark blue, GPU clear |

## Acceptance criteria

- [x] Each variant builds with `swift build`.
- [x] Each variant opens a centered, resizable 1280×720 window.
- [x] AppKit fills the content view black; Metal clears a drawable to dark blue.
- [x] Closing the window, pressing Escape, or pressing ⌘Q quits the app.
- [x] Each window is reported on screen with layer 0 by the window server.

## Verification

Build and launch each variant from its directory:

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

Confirm each window through the macOS window server. A temporary
`CGWindowListCopyWindowInfo` script reported an on-screen window owned by the
running binary with layer 0 and a 1280×752 outer frame (720pt content plus title
bar). Quit the app afterward; no process should remain.

Screen capture was unavailable because Screen Recording permission was not
granted; this does not affect the apps.

## Notes

- Both are SwiftPM executables with a macOS 14 deployment target and no
  third-party dependencies.
- The variants intentionally duplicate window and app-lifecycle code so each can
  be read in isolation. Shared abstractions are deferred until a later task
  demonstrates the need.
- Deeper Metal teaching notes live in the
  [Metal variant README](swift-metal/README.md).
- Shared terminology and portability guidance live in
  [Graphics concepts and portability](../docs/GRAPHICS-CONCEPTS.md).
