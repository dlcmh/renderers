# Decision Log

Short records of durable choices. Append new entries; do not rewrite accepted
history. If a decision changes, add a new entry with status `Superseded` on the
old one and a link to its replacement.

Format: context, decision, consequences. Dates are ISO 8601.

## ADR-0001 — Numbered, self-contained tasks

- **Date:** 2026-10-19
- **Status:** Accepted

### Context

The repository grows by adding small rendering and game-window experiments. There
is no product roadmap or shared runtime yet, and experiments may be implemented
in different languages.

### Decision

Each experiment is a top-level directory named `NNNN-kebab-case-task/`. A task
may contain one or more language variants in lowercase subdirectories, each
independently runnable. Task numbers are never reused or renumbered.

### Consequences

The repository history and task sequence stay legible. Code duplication across
tasks is expected and accepted in exchange for isolation. Shared abstractions are
introduced only after a repeated need is demonstrated.

## ADR-0002 — Native Swift approach for the first task

- **Date:** 2026-10-19
- **Status:** Accepted
- **Task:** `0001-empty-launch-window`

### Context

The first task needs a macOS window with no rendering content, and future tasks
will likely add rendering to that window.

### Decision

Use Swift Package Manager and AppKit with no third-party dependencies. Deployment
target is macOS 14. The window uses a custom `NSView` with a black background as
the placeholder drawing surface. Escape quits and closing the last window
terminates the app.

### Consequences

The project builds with `swift build` and runs with `swift run` using only the
system toolchain. A future renderer can replace or extend `GameView` without
changing the app lifecycle.

## ADR-0003 — Trunk-based work with direct pushes

- **Date:** 2026-10-19
- **Status:** Accepted

### Context

This is a single-maintainer experimental repository where an agent may complete a
task without interactive review.

### Decision

Work directly on `main`, tracking `origin/main`. Completed and verified tasks are
committed and pushed without a pull request by default. History is not rewritten,
and force-pushes or remote changes require explicit user approval.

### Consequences

Continuity is simple and each task is independently revertible. Verification must
be real because no CI or review gate currently exists. If the repository later
adds CI or collaborators, supersede this decision with a branch/PR policy.

## ADR-0004 — Verify behavior, not just compilation

- **Date:** 2026-10-19
- **Status:** Accepted

### Context

Windowed applications can compile and launch while failing to display a window,
and GUI screenshot tools may be unavailable due to macOS permissions.

### Decision

Every GUI task is verified by observing an on-screen window owned by the running
process, for example via `CGWindowListCopyWindowInfo`. Screenshot capture is
optional and permission-dependent. Build success alone does not satisfy the
definition of done.

### Consequences

Agents need a short runtime check for each GUI task, but can distinguish real
application failures from screen-capture permission limits.

## ADR-0005 — Backend-qualified variant directories

- **Date:** 2026-10-19
- **Status:** Accepted

### Context

A task can be solved more than once in the same language with materially
different platform APIs. The original `swift` directory in task 0001 contains an
AppKit, CPU-drawn window, and a Metal, GPU-backed variant is being added for
comparison. A bare language name would no longer identify the implementation.

### Decision

Qualify a variant directory with its backend when one language has multiple
meaningful implementations in a task: `swift-appkit`, `swift-metal`,
`rust-winit`, `rust-wgpu`. Rename `0001-empty-launch-window/swift` to
`swift-appkit`. A bare language name remains valid when there is only one
implementation in that language.

### Consequences

Paths and IDE workspace names become self-describing, and the old/new comparison
is visible in the directory tree. Links, run commands, and workspace settings
must be updated when a variant is renamed. Git's rename detection preserves the
file history.

