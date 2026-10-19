# Renderers

A workbench of small, numbered experiments in rendering and game windows. The
goal is to learn how game renderers are built across platforms, from first
principles. Each task isolates one concept, stays runnable on its own, and
compares any materially new technique with the approach it replaces. The
repository is not a shared library.

## Tasks

| # | Task | Variants | Status |
| --- | --- | --- | --- |
| 0001 | [Empty launch window](0001-empty-launch-window/README.md) | [Swift (AppKit)](0001-empty-launch-window/swift-appkit/), [Swift (Metal)](0001-empty-launch-window/swift-metal/) | Complete |

New tasks get the next unused four-digit number and a kebab-case name. See
[AGENTS.md](AGENTS.md) for the full conventions and agent workflow.

## Quick start

```sh
cd 0001-empty-launch-window/swift-appkit # CPU-drawn baseline
swift run
```

```sh
cd 0001-empty-launch-window/swift-metal # GPU-backed variant
swift run
```

Both open a centered, resizable 1280×720 window. The AppKit window is black; the
Metal window is dark blue. Close either window, press Escape, or press ⌘Q to quit.

Start with the CPU baseline, then read [the Metal notes](0001-empty-launch-window/swift-metal/README.md#the-delta-at-a-glance)
for the comparison between `draw(_:)` and an explicit GPU render pass.

## Requirements

- macOS 14 or newer
- Swift 6 toolchain (Xcode Command Line Tools or Xcode)

The current setup was verified with macOS 26.6.2 and Swift 6.3.3 on arm64.

## Repository conventions

- One numbered directory per task: `NNNN-kebab-case-task/`.
- Each task has a README with its goal, acceptance criteria, and status.
- Each language variant is independent and has its own run instructions.
- Durable decisions are recorded in [docs/DECISIONS.md](docs/DECISIONS.md).
- Completed, verified work is committed and pushed to `origin/main`.

## Contributing

Read [AGENTS.md](AGENTS.md) first, whether you are an agent or a human. It covers
the task lifecycle, verification requirements, coding standards, and git policy.
