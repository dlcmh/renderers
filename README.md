# Renderers

A workbench of small, numbered experiments in rendering and game windows. Each
task is self-contained and runnable; the repository is not a shared library.

## Tasks

| # | Task | Variants | Status |
| --- | --- | --- | --- |
| 0001 | [Empty launch window](0001-empty-launch-window/README.md) | Swift | Complete |

New tasks get the next unused four-digit number and a kebab-case name. See
[AGENTS.md](AGENTS.md) for the full conventions and agent workflow.

## Quick start

```sh
cd 0001-empty-launch-window/swift
swift run
```

A centered, resizable 1280×720 window opens with a black surface. Close it,
press Escape, or press ⌘Q to quit.

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
