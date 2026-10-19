# Empty Game Window (Swift / AppKit)

> **Frozen reference variant.** Swift is not a maintained stack in this
> repository; it does not align with the cross-platform goal (ADR-0015). This
> variant is kept for the side-by-side AppKit/Metal comparison and receives no
> new work. Maintained equivalents: [rust-appkit](../rust-appkit/) and
> [cpp-appkit](../cpp-appkit/).

Task: [0001 — Empty launch window](../README.md). Repository rules:
[AGENTS.md](../../AGENTS.md).

A minimal macOS game window built with AppKit and Swift Package Manager. This is
the CPU-drawn baseline; see the [Metal variant](../swift-metal/) for the
GPU-backed version.

The app opens a centered, resizable 1280×720 window with a black surface.
Close the window, press Escape, or press ⌘Q to quit. A minimal application menu
provides the standard Quit item so ⌘Q works.

## Run

From the repository root, with build artifacts under `/tmp/renderers`:

```sh
./scripts/run.sh swift-appkit
```

Or invoke SwiftPM directly:

```sh
cd 0001-empty-launch-window/swift-appkit
swift run --scratch-path /tmp/renderers/swift-appkit
```

## Structure

- `Package.swift` — SwiftPM executable definition.
- `Sources/EmptyGameWindow/main.swift` — application delegate, window, and
  `GameView` (the placeholder drawing surface where a renderer will go).
