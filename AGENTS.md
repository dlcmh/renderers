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

## Teaching standards

This repository is learning material, not a production codebase. The code should
make a concept obvious to a reader who has not used the API before.

- **One concept per task.** A task should introduce one new capability or one new
  implementation strategy. Do not hide the lesson among unrelated changes.
- **Show the mechanism.** Prefer explicit code over framework magic when the
  framework would obscure what the GPU or window system is doing. Mention the
  convenient alternative and when to use it.
- **Compare old and new.** When an implementation is a better, faster, or more
  scalable way to achieve an existing objective, its README must compare and
  contrast with the older approach: what changed, why it matters, and what it
  costs. The AppKit-versus-Metal variant is the model.
- **Be honest about performance.** State when a new path is not actually faster
  for the current workload, identify the workload where it wins, and avoid
  benchmarks or claims that were not measured.
- **Comment the why.** Put comments at the points where a reader needs the mental
  model: object lifetime, synchronization, units, and non-obvious state. Do not
  narrate syntax.
- **Make commits teach.** Prefer a small series of commits that each isolate one
  conceptual delta (for example: restructure, then working code, then the
  comparison) over one opaque commit. Commit messages should name the step.
- **Give new work its own folder.** Put a new implementation in its own variant
  directory, and restructure existing paths when a clearer name makes the
  comparison easier to follow.

## Current state

- **Maintained stacks:** Rust and C++. New variants and features go to these.
  Swift does not align with the cross-platform goal and gets no new work
  (ADR-0015).
- **Frozen:** the Swift variants in task 0001. They are reference material for the
  AppKit/Metal comparison and must not receive new features (ADR-0015).
- `0001-empty-launch-window/rust-appkit` is complete: the AppKit baseline ported
  to Rust through the `objc2` bindings.
- `0001-empty-launch-window/rust-metal` is complete: the Metal clear ported to
  Rust, including explicit `Retained` ownership of the layer and command queue.
- `0001-empty-launch-window/cpp-appkit` is complete: the AppKit baseline written
  in Objective-C++ with ARC.
- `0001-empty-launch-window/cpp-metal` is complete: the Metal clear written in
  Objective-C++ with ARC.
- `0001-empty-launch-window/swift-appkit` and `swift-metal` are complete and
  frozen: an AppKit black draw and a `CAMetalLayer` clear.
- `0002-first-triangle/rust-metal` and `0002-first-triangle/cpp-metal` are
  complete: a shader pipeline, vertex buffers, a draw call, and a display-link
  frame loop. The shared shader lives in `0002-first-triangle/shaders/`.
- There are no tests, CI workflows, or shared libraries yet.
- **Direction:** new rendering work is GPU-only (ADR-0012). The CPU AppKit
  variants stay as baselines. The next backend after Metal is Vulkan, behind a
  first-cut RHI; compute, if added, stays behind a separate seam (ADR-0013).
- Task numbers are derived from the top-level directories. After `0002`, the next
  new task is expected to be `0003-<kebab-name>`. The planned next concept is
  pacing and animation (time uniforms, in-flight frames without blocking).

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
- Language directories use lowercase canonical names: `rust`, `cpp`, `c`,
  `python`, etc. Swift is frozen reference material and gets no new directories.
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

Use the commands documented in each language README. Builds are ephemeral by
default: helper scripts put artifacts under `/tmp/renderers`, overridable with
`RENDERERS_BUILD_ROOT`. Run any variant from the repository root with:

```sh
./scripts/run.sh <variant>
```

Variants: `rust-appkit`, `rust-metal`, `cpp-appkit`, `cpp-metal` from task 0001;
`rust-metal-triangle` and `cpp-metal-triangle` from task 0002. The frozen Swift
variants also have runners (`swift-appkit`, `swift-metal`) for reference work only.

Do not extend the Swift variants. If a Swift reference must be checked, its
underlying commands are:

```sh
cd 0001-empty-launch-window/swift-appkit
swift run --scratch-path /tmp/renderers/swift-appkit
```

The debug binaries are under the scratch path:
`/tmp/renderers/swift-appkit/debug/EmptyGameWindow` and
`/tmp/renderers/swift-metal/debug/MetalLaunchWindow`. `./scripts/check-swift.sh`
builds both into the external root; it is a reference check, not part of the
maintained workflow.

Each task has its own Rust workspace and its own CMake project, so tasks do not
share build configuration. `check-rust.sh` and `check-cpp.sh` iterate over every
task automatically; add new tasks to their `tasks` arrays.

The Rust variants live in a Cargo workspace per task, for example
`0002-first-triangle/Cargo.toml`:

```sh
cd 0002-first-triangle
CARGO_TARGET_DIR=/tmp/renderers/0002-first-triangle-target cargo run -p rust-metal-triangle
```

`Cargo.lock` is committed in every task workspace because these are binaries. Run
the complete Rust check — formatting, Clippy with warnings denied, build, and test
for every task — from the repository root:

```sh
./scripts/check-rust.sh
```

The C++ variants share one CMake project per task, for example
`0002-first-triangle/CMakeLists.txt`:

```sh
cmake -S 0002-first-triangle -B /tmp/renderers/0002-cpp -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build /tmp/renderers/0002-cpp
/tmp/renderers/0002-cpp/cpp-metal-triangle
```

The CMake projects compile with ARC, `-Wall -Wextra -Wpedantic -Werror`, and an
optional `ENABLE_SANITIZERS=ON` AddressSanitizer/UndefinedBehaviorSanitizer
configuration. Run the complete C++ check from the repository root:

```sh
./scripts/check-cpp.sh
```

Remove all known build artifacts, including the external root:

```sh
./scripts/clean.sh --dry-run
./scripts/clean.sh
```

### Rust conventions

- Use thin API bindings (`objc2`, `objc2-app-kit`, `objc2-metal`,
  `objc2-quartz-core`) behind our own modules. Do not introduce `winit`, `wgpu`,
  or an engine for these learning variants.
- Do not hand-write Objective-C FFI as the baseline. Bindings are a deliberate
  tradeoff (see ADR-0014 and
  [docs/GRAPHICS-CONCEPTS.md](docs/GRAPHICS-CONCEPTS.md#language-asymmetry-objective-c-versus-rust-bindings));
  a future `rust-metal-raw` variant may teach the binding layer explicitly.
- Keep `unsafe` at the FFI and AppKit override boundaries. Every unsafe block
  needs a `// SAFETY:` comment that states the invariant; the workspace denies
  `clippy::undocumented_unsafe_blocks`.
- Keep Objective-C object ownership explicit with `Retained<T>` and store
  long-lived GPU objects in class ivars.
- The workspace pins Rust 1.97.1 in `rust-toolchain.toml`; run `cargo fmt --all`
  and `cargo clippy --workspace --all-targets -- -D warnings` before committing.
- Add new Rust crates as workspace members and keep `Cargo.lock` in sync.

### C++ conventions

- AppKit and Metal are Objective-C APIs, so use Objective-C++ (`.mm`) at the
  macOS boundary. Do not add a cross-platform windowing or rendering framework to
  hide that boundary.
- Compile with ARC. Keep Objective-C object lifetimes explicit in the source:
  strong instance variables for windows/GPU objects, and
  `__attribute__((objc_precise_lifetime))` for the weak application delegate.
- The shared CMake project lives at the task root. Compile with
  `-Wall -Wextra -Wpedantic -Werror`; discard intentionally unused callback
  parameters with `(void)parameter`.
- Format with the repository `.clang-format`. `scripts/check-cpp.sh` runs
  `clang-format --dry-run --Werror` and builds both the normal and sanitizer
  configurations.
- Keep CMake build directories out of git. The helper scripts use the external
  `/tmp/renderers` root by default; legacy `build/` and `build-*` paths remain
  ignored.

### Verifying a GUI launch

- Start the app as a managed background job; never block the session on a
  foreground GUI process.
- Confirm the process remains alive and that an on-screen window is owned by it.
  On macOS, `CGWindowListCopyWindowInfo` from a temporary Swift script can list
  the owner, layer, and bounds without Accessibility or Screen Recording access.
- `screencapture` may fail when Screen Recording permission is not granted. Treat
  that as an environment limitation, not as an app failure, and do not claim a
  screenshot you could not produce.
- When Screen Recording permission is available, capture the window with
  `screencapture -x -l <window-id> <path>` and inspect the image to verify the
  expected surface color.
- Stop the test app when verification is done so no stale process or window is
  left behind.

## Coding standards

- Prefer native platform frameworks. Do not add third-party dependencies for a
  small task without a decision-log entry; ask first if the dependency is
  significant.
- Keep UI work on the main thread and avoid blocking the run loop.
- For the macOS apps, keep the established interaction: standard window controls,
  a minimal application menu with a Quit item (⌘Q), Escape quits, and closing the
  last window terminates the app.
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
- **`docs/GRAPHICS-CONCEPTS.md`:** the shared vocabulary and portability field
  guide. Update it when terminology, platform assumptions, or the
  from-scratch/binding policy changes. Link to it when explaining concepts rather
  than re-deriving definitions in each task.
- **`docs/STRATEGY.md`:** the strategic direction. New rendering work is GPU-only;
  the CPU AppKit variants are baselines. Update it when the direction, backend
  order, or compute policy changes, and record the corresponding ADR in
  `docs/DECISIONS.md`.
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
- Rust 1.97.1, Cargo 1.97.1 (pinned by `rust-toolchain.toml`)
- Apple Clang 21.0.0, CMake 4.4.4, Ninja
- `clang-format` from the Xcode Command Line Tools; `clang-tidy` is not currently
  installed
- Git 2.50.1
- Swift package deployment target: macOS 14

## Safety

- Never commit credentials, tokens, personal paths, or private data.
- Do not run destructive commands against paths outside this repository.
- Keep network access purposeful; do not fetch or install dependencies silently.
- If user instructions conflict with this document, follow the user and then
  update the document to match the new convention.
