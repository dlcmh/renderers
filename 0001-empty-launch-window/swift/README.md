# Empty Game Window (Swift)

A minimal macOS game window built with AppKit and Swift Package Manager.

## Run

```sh
cd 0001-empty-launch-window/swift
swift run
```

The app opens a centered, resizable 1280×720 window with a black surface.
Close the window, press Escape, or press ⌘Q to quit.

## Structure

- `Package.swift` — SwiftPM executable definition.
- `Sources/EmptyGameWindow/main.swift` — application delegate, window, and
  `GameView` (the placeholder drawing surface where a renderer will go).
