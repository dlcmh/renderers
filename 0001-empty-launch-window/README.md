# 0001 — Empty launch window

- **Status:** Complete
- **Verified:** 2026-10-19 on macOS 26.6.2, arm64, Swift 6.3.3

Part of the [renderers](../README.md) task series. Repository rules:
[AGENTS.md](../AGENTS.md).

## Goal

Prove the local macOS toolchain can build and launch a native game-window shell.

## Non-goals

- Rendering anything beyond a black background.
- Input handling beyond quitting.
- Game loops, Metal/OpenGL setup, or asset loading.

## Variants

| Language | Path | Run |
| --- | --- | --- |
| Swift | [`swift/`](swift/) | `cd swift && swift run` |

## Acceptance criteria

- [x] `swift build` succeeds from a clean checkout.
- [x] `swift run` opens a centered, resizable 1280×720 window.
- [x] The window content is an empty black surface.
- [x] Closing the window, pressing Escape, or pressing ⌘Q quits the app.
- [x] The window is reported on screen with layer 0 by the window server.

## Verification

1. Build and launch:

   ```sh
   cd swift
   swift build
   .build/debug/EmptyGameWindow
   ```

2. Confirm the window through the macOS window server. A temporary
   `CGWindowListCopyWindowInfo` script reported an on-screen window owned by
   `EmptyGameWindow` with layer 0 and a 1280×752 outer frame (720pt content plus
   title bar).
3. Quit the app; no process is left running.

Screen capture was unavailable because Screen Recording permission was not
granted; this does not affect the app.

## Notes

- SwiftPM executable target, AppKit only, macOS 14 deployment target.
- `Sources/EmptyGameWindow/main.swift` contains the app delegate, window setup,
  and `GameView`, the placeholder drawing surface for future rendering tasks.
