# Metal Launch Window (Swift / Metal)

Task: [0001 — Empty launch window](../README.md). CPU baseline:
[swift-appkit](../swift-appkit/). Repository rules: [AGENTS.md](../../AGENTS.md).

A GPU-backed empty window built directly on `CAMetalLayer`, `MTLDevice`, and a
Metal render pass. It clears the drawable to a dark blue every time the window is
created or resized.

## Run

```sh
cd 0001-empty-launch-window/swift-metal
swift run
```

A centered, resizable 1280×720 window opens with a dark blue surface. Close it,
press Escape, or press ⌘Q to quit.

## Status

Complete and verified on 2026-10-19 (macOS 26.6.2, arm64, Swift 6.3.3). The
window server reported an on-screen window owned by `MetalLaunchWindow` with
layer 0 and a 1280×752 outer frame. Screen capture was unavailable because
Screen Recording permission was not granted.

## Structure

- `Sources/MetalLaunchWindow/main.swift` — app delegate, `CAMetalLayer`-backed
  `MetalView`, command queue, render pass, and window lifecycle.
- `Package.swift` — SwiftPM executable definition with no dependencies.
