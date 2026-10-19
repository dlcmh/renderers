# Empty Game Window (Swift / AppKit)

Task: [0001 — Empty launch window](../README.md). Repository rules:
[AGENTS.md](../../AGENTS.md).

A minimal macOS game window built with AppKit and Swift Package Manager. This is
the CPU-drawn baseline; see the [Metal variant](../swift-metal/) for the
GPU-backed version.

The app opens a centered, resizable 1280×720 window with a black surface.
Close the window, press Escape, or press ⌘Q to quit.

## Run

```sh
cd 0001-empty-launch-window/swift-appkit
swift run
```

## Structure

- `Package.swift` — SwiftPM executable definition.
- `Sources/EmptyGameWindow/main.swift` — application delegate, window, and
  `GameView` (the placeholder drawing surface where a renderer will go).
