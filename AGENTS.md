# AGENTS.md

Operating guide for AI agents (and humans) working in this repository. Read it
before changing anything.

**Precedence:** direct user instructions > the nearest `AGENTS.md` > this file >
task-level READMEs. If a rule conflicts with the actual environment, follow the
environment and update the docs.

## Purpose

`renderers` is a chronological collection of small, self-contained experiments
about rendering and game windows. Each numbered task should prove one capability
and leave behind runnable code plus enough context for the next agent.

Optimize for a complete, verifiable result over architecture. Do not introduce
shared frameworks or cross-task abstractions until a second task needs them.

## Current state

- `0001-empty-launch-window/swift-appkit` is complete: an AppKit window with a
  black, CPU-drawn content view.
- There are no tests, CI workflows, or shared libraries yet.
- Task numbers are derived from the top-level directories. After `0001`, the next
  new task is expected to be `0002-<kebab-name>`.

## Repository layout

```text
NNNN-kebab-case-task/
  README.md            # task goal, acceptance criteria, status
  <language>/          # one or more independently runnable variants
    README.md
    ...
```

Naming rules:

- Task directories use a four-digit sequence and kebab-case:
  `0002-draw-triangle`.
- Never reuse, renumber, or recycle a task directory. New work gets a new number.
- Language directories use lowercase canonical names: `swift`, `rust`, `c`,
  `cpp`, `python`, etc.
- When one language has multiple meaningful implementations in a task, qualify
  the directory with the backend: `swift-appkit`, `swift-metal`, `rust-winit`,
  `rust-wgpu`, etc. See ADR-0005.
- Assets shared by all variants live at the task root; variant-specific assets
  stay inside that variant's directory.
- Every task contains a `README.md`; every language variant must be runnable on
  its own.

## Workflow for a task

1. **Orient.** Run `git status`, inspect `git log --oneline -5`, list the task
   directories, and read this file, the root `README.md`, and the README of any
   related task.
2. **Choose the ID.** Extend an existing task only when the request is clearly a
   continuation of it. Otherwise create the next unused number.
3. **Define acceptance criteria.** Put the goal, non-goals, and observable
   acceptance criteria in the task README before or alongside implementation.
4. **Implement.** Keep the change self-contained and as small as the task allows.
   Do not modify unrelated tasks.
5. **Verify.** Build with the documented command and run the result. For GUI
   apps, confirm the window actually appears; a successful build is not enough.
6. **Document.** Update the task README status, verification notes, and the task
   index in the root README. Add an entry to `docs/DECISIONS.md` when a durable
   architectural or process choice is made.
7. **Commit and push.** Follow the git policy below. Push only verified work.
8. **Report.** State what changed, the exact verification performed, and any
   remaining limitation or follow-up.

Ask the user only when a choice is irreversible, rewrites published history,
changes repository configuration, or needs credentials/permissions that are not
already available. Otherwise make the smallest reasonable choice and record it.

## Build, run, and verify

Use the commands documented in each language README. For the current Swift task:

```sh
cd 0001-empty-launch-window/swift-appkit
swift build
swift run
```

The debug binary is `.build/debug/EmptyGameWindow`. Release builds use
`swift build -c release`. Run `swift test` when a test target exists.

### Verifying a GUI launch

- Start the app as a managed background job; never block the session on a
  foreground GUI process.
- Confirm the process remains alive and that an on-screen window is owned by it.
  On macOS, `CGWindowListCopyWindowInfo` from a temporary Swift script can list
  the owner, layer, and bounds without Accessibility or Screen Recording access.
- `screencapture` may fail when Screen Recording permission is not granted. Treat
  that as an environment limitation, not as an app failure, and do not claim a
  screenshot you could not produce.
- Stop the test app when verification is done so no stale process or window is
  left behind.

## Coding standards

- Prefer native platform frameworks. Do not add third-party dependencies for a
  small task without a decision-log entry; ask first if the dependency is
  significant.
- Keep UI work on the main thread and avoid blocking the run loop.
- For the macOS apps, keep the established interaction: standard window controls,
  Escape quits, closing the last window terminates the app.
- Keep code readable and direct. Comment intent and non-obvious constraints, not
  syntax.
- Do not commit generated output: `.build/`, `.swiftpm/`, `DerivedData/`,
  `.DS_Store`, logs, or binaries.
- Preserve existing behavior unless the task explicitly changes it.

## Documentation requirements

- **Root `README.md`:** keep the task index current (`#`, task, variants, status).
- **Task `README.md`:** include status, goal, non-goals, variant table,
  acceptance criteria, verification, and relevant notes. Use `0001` as the
  template.
- **Variant `README.md`:** exact run command and what the user should observe.
- **`docs/DECISIONS.md`:** append an ADR for choices future agents would
  otherwise relitigate. Do not rewrite accepted history; supersede it instead.
- Update this file when working conventions change.

## Definition of done

A task is done only when all of these are true:

- [ ] It builds from a documented command without errors.
- [ ] Its runtime behavior was observed and matches the acceptance criteria.
- [ ] The task README and root task index reflect the final state.
- [ ] No build artifacts, secrets, or unrelated files are staged.
- [ ] The change is committed and pushed to `origin/main`.

## Git and remotes

- Canonical remote: `origin` → <https://github.com/dlcmh/renderers.git>
- Default branch: `main`, tracking `origin/main`.
- **Standing policy:** when a task is complete and verified, commit it and push to
  `origin/main` unless the user says otherwise. If a push fails (auth, network,
  protection), report the exact failure and leave the commit local; do not
  rewrite the remote or switch protocols to work around it.
- One logical change per commit. Separate unrelated fixes from the task.
- Commit subject: imperative mood, capitalized, at most 72 characters. Add a body
  when the why or verification is not obvious. Do not add AI-attribution
  trailers unless the user asks.
- Do not force-push, rewrite published history, change remotes, or rename the
  default branch without explicit user approval.
- Do not `reset --hard`, `clean`, or discard user changes without explicit
  approval. If the tree contains unrelated uncommitted work, leave it out of the
  commit.

## Environment snapshot

Verified on 2026-10-19 (re-check before relying on it):

- macOS 26.6.2, arm64
- Swift 6.3.3 (Xcode Command Line Tools)
- Git 2.50.1
- Swift package deployment target: macOS 14

## Safety

- Never commit credentials, tokens, personal paths, or private data.
- Do not run destructive commands against paths outside this repository.
- Keep network access purposeful; do not fetch or install dependencies silently.
- If user instructions conflict with this document, follow the user and then
  update the document to match the new convention.
