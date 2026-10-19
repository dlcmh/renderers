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

## ADR-0006 — Teach with `CAMetalLayer`, not `MTKView`

- **Date:** 2026-10-19
- **Status:** Accepted
- **Task:** `0001-empty-launch-window/swift-metal`

### Context

The repository is teaching material for writing renderers from scratch. MetalKit's
`MTKView` hides drawable management and the draw/display loop behind a convenient
subclass. The first Metal example should expose the pieces a renderer actually
needs to understand.

### Decision

Back an `NSView` with a `CAMetalLayer` directly. Create the `MTLDevice` and
`MTLCommandQueue` explicitly, acquire drawables with `nextDrawable()`, encode a
render pass that clears the drawable, then present and commit. Do not introduce
`MTKView`, shaders, pipelines, or geometry in this first variant.

### Consequences

The example has more boilerplate than an `MTKView` sample, but every object's role
is visible. Later tasks can add a render pipeline and draw calls without replacing
the windowing layer. `MTKView` can be introduced later as a convenience
alternative, with a comparison to this explicit path.

## ADR-0007 — Compare launch paths inside task 0001

- **Date:** 2026-10-19
- **Status:** Accepted

### Context

The Metal clear is a second way to satisfy the same objective as the existing
AppKit window, not a new rendering capability. Keeping both under one task makes
the CPU/GPU delta directly comparable.

### Decision

Keep both implementations in `0001-empty-launch-window`: `swift-appkit` and
`swift-metal`. The task README defines shared acceptance criteria, while each
variant README explains its implementation and links to the other. New
capabilities, such as drawing a triangle, receive a new task number.

### Consequences

The directory tree makes the comparison obvious and both variants can be run
side by side. The variants intentionally duplicate app-lifecycle code; shared
abstractions remain deferred until a later task proves the need.

## ADR-0008 — Teaching-first code, docs, and commits

- **Date:** 2026-10-19
- **Status:** Accepted

### Context

The repository exists to learn cross-platform game renderer construction from
first principles. Code that merely works can still hide the mechanism; a large
single commit can also make the new idea hard to isolate. The maintainer values
conceptual clarity and honest performance comparisons.

### Decision

Treat every task as teaching material. Prefer explicit mechanisms over framework
convenience when the convenience hides the concept. When new code supersedes or
improves an older approach, its README compares the two, including costs and when
the old approach remains appropriate. Performance statements must be qualified or
measured. Put explanatory comments at non-obvious points, and prefer a short
series of commits that each isolate one conceptual delta.

### Consequences

Tasks take slightly longer to document, but they remain useful as reference
material. New implementations live in their own variant directories, and existing
folders may be renamed when a clearer comparison requires it. The AppKit-versus-
Metal comparison in task 0001 is the reference example for future tasks.

## ADR-0009 — Portability strategy: thin bindings, Metal first, Vulkan second

- **Date:** 2026-10-19
- **Status:** Accepted

### Context

The repository should teach native graphics from first principles and eventually
support multiple backends, with HarmonyOS Next as a possible future target. The
Rust binding ecosystem is uneven: Apple bindings such as `objc2` are mature, while
HarmonyOS Rust tooling is younger and community-driven. HarmonyOS also requires an
ArkTS host, NAPI bridge, and XComponent surface rather than a standalone native
binary. A blanket "zero third-party crates" policy would not remove that platform
work.

### Decision

- Do not use game engines or GPU abstraction frameworks for the learning
  backends. In particular, no Bevy, `wgpu`, or `bgfx`; defer `winit` while the
  native windowing layer is part of the lesson.
- Allow thin, direct API bindings (`objc2`/`objc2-metal`, later `ash` for Vulkan)
  when they are mature. Isolate them behind our own platform and RHI modules, and
  keep their types out of the renderer API.
- Expect hand-written or vendored FFI where bindings are missing, especially for a
  future HarmonyOS NAPI/XComponent/Vulkan host.
- Implement the Metal backend first, then a Vulkan backend; extract the RHI only
  after the second backend exposes the real differences.
- Treat the platform layer and the GPU layer as separate seams. HarmonyOS will use
  an ArkTS + NAPI + XComponent host; macOS will use AppKit + `CAMetalLayer`.

The reasoning and vocabulary are documented in
[docs/GRAPHICS-CONCEPTS.md](GRAPHICS-CONCEPTS.md).

### Consequences

The macOS learning path stays focused on renderer concepts without taking on the
risk of hand-maintaining Objective-C bindings. Portability is achieved through
owned interfaces and a second backend, not through avoiding dependencies
everywhere. HarmonyOS work will require a separate host project and may require
more FFI effort than the macOS variants.

## ADR-0010 — Rust workspace per task

- **Date:** 2026-10-19
- **Status:** Accepted
- **Task:** `0001-empty-launch-window`

### Context

Task 0001 now has two Rust implementations with the same dependencies and tooling
requirements. Giving each crate its own lockfile and target directory would
duplicate builds, and running the linters separately invites drift.

### Decision

Use one Cargo workspace at the task root,
`0001-empty-launch-window/Cargo.toml`, with `rust-appkit` and `rust-metal` as
members. The workspace owns:

- the shared `Cargo.lock`, committed because both members are binaries,
- the shared `target/` directory, which is git-ignored,
- workspace lints (`unsafe_op_in_unsafe_fn`, `unused_must_use`,
  `undocumented_unsafe_blocks`),
- the pinned toolchain in `rust-toolchain.toml` and `rustfmt.toml`,
- the `scripts/check-rust.sh` verification entry point.

Each member remains independently runnable with `cargo run -p <member>` or from
its own directory.

### Consequences

Rust builds and checks are consistent across the variants, and adding another
Rust variant means adding one workspace member and refreshing the lockfile. The
mixed-language task root now contains a Cargo workspace alongside the Swift
directories; Cargo only knows about its explicit members. Rust-specific tooling
is documented in `AGENTS.md` so future variants follow the same pattern.

## ADR-0011 — C++ variants use Objective-C++ and one CMake project

- **Date:** 2026-10-19
- **Status:** Accepted
- **Task:** `0001-empty-launch-window`

### Context

The C++ variants need direct access to AppKit and Metal, which are Objective-C
APIs. Introducing a cross-platform windowing or rendering framework would hide
the native boundary the repository is meant to teach. The task also needs a build
system, formatting, warnings-as-errors, and a sanitizer path that work for
Objective-C++.

### Decision

- Write the macOS boundary in Objective-C++ (`.mm`) and compile with ARC. Keep
  C++/Objective-C object lifetimes explicit: strong ivars for windows and GPU
  objects, and `__attribute__((objc_precise_lifetime))` for the weak application
  delegate.
- Use one CMake project at the task root with `cpp-appkit` and `cpp-metal`
  targets. Compile with `-Wall -Wextra -Wpedantic -Werror`.
- Provide an `ENABLE_SANITIZERS` option that adds AddressSanitizer and
  UndefinedBehaviorSanitizer to both compile and link steps.
- Format with the repository `.clang-format`; `scripts/check-cpp.sh` performs the
  format check and builds both normal and sanitizer configurations.
- Do not adopt `clang-tidy` yet; it is not installed in the current environment.
  The compiler warnings plus sanitizer build are the baseline.

### Consequences

The C++ variants are macOS-specific Objective-C++ rather than portable standard
C++. That is deliberate: the shared RHI boundary remains a future layer above the
platform APIs. CMake build directories stay out of git, and adding another C++
variant means adding one target and one source file.

## ADR-0012 — Go GPU-only for new rendering work

- **Date:** 2026-10-19
- **Status:** Accepted
- **Supersedes for scope:** the CPU half of the task-0001 comparisons, as a
  direction for future work only. The AppKit baselines remain in the repository.

### Context

Task 0001 proved that the same window can be produced by CPU drawing or by a GPU
render pass in four languages. The maintainer's goal is to learn renderer
architecture across platforms and accelerators, and the CPU path does not scale
toward that goal: it serializes per-pixel work on the CPU and cannot express
shaders, pipelines, or compute.

### Decision

All new rendering work targets the GPU. The CPU/AppKit variants stay as teaching
baselines and historical comparisons, but no new renderer features are added to
them. The platform layer (window plus native surface) remains explicit and
per-OS; "GPU-only" refers to the pixel-producing path, not to discarding the
native host.

Reasoning and the wider accelerator analysis are documented in
[docs/STRATEGY.md](STRATEGY.md).

### Consequences

The learning path proceeds through shader pipelines, frame loops, depth and
cameras, and then a Vulkan backend. Fewer divergences between variants are
expected, because future work concentrates on the GPU path. Task READMEs that
describe CPU variants should label them as baselines rather than targets.

## ADR-0013 — Portability rests on standard APIs, not vendor ecosystems

- **Date:** 2026-10-19
- **Status:** Accepted

### Context

Chinese hardware vendors, NPUs, and vendor compute ecosystems are multiplying.
Moore Threads, Lisuan, and similar vendors increasingly ship Vulkan, Direct3D, and
OpenGL drivers, while vendor compute ecosystems (CUDA, CANN, MUSA, and others) and
NPUs do not expose a portable graphics API. Rust terminals and other GPU-heavy
tools also rely on portable GPU abstractions for shipping.

### Decision

- Continue implementing the graphics path against native standard APIs (Metal,
  then Vulkan), behind our own RHI seam.
- Treat Vulkan as the primary multi-platform backend, including for non-Western
  GPU vendors and HarmonyOS; validate driver conformance on real hardware rather
  than assuming parity.
- Keep compute behind a separate, narrow seam. Target Vulkan compute or WebGPU
  compute; do not integrate vendor compute SDKs or NPU APIs into the renderer core.
- Keep `wgpu` out of the learning variants but recognize it as the pragmatic
  shipping path and as a reference architecture, especially for terminal-style GPU
  rendering.
- Do not treat terminal GPU acceleration as a separate direction; it is the same
  submission-model problem with different latency and pacing priorities.

The supporting analysis lives in [docs/STRATEGY.md](STRATEGY.md).

### Consequences

The repository remains a from-scratch learning project while staying compatible
with the platforms that are likely to matter. Compute and NPU support, if added
later, will be adapters rather than core dependencies. Accepting Vulkan as the
next backend implies a future task for a first-cut RHI and a Vulkan implementation
of the same triangle.

## ADR-0014 — Keep thin Rust bindings; defer a raw-FFI variant

- **Date:** 2026-10-19
- **Status:** Accepted
- **Task:** `0001-empty-launch-window` (affects all Rust work)

### Context

The C++ variants reach AppKit and Metal through Objective-C++, which compiles
in-language and needs no binding crate. Swift has built-in Objective-C interop.
Rust, by contrast, needs `objc2` and its framework crates to message-send to
Objective-C objects, register classes, and model ownership. This asymmetry raised
the question of whether Rust should hand-write its FFI to match C++'s "no binding
dependency."

### Decision

- Keep `objc2` and its framework crates as the default Rust binding layer,
  isolated behind our own modules.
- Do not hand-write Objective-C FFI as the baseline. It adds unsafe code, retain
  and release reasoning, and class/protocol boilerplate without advancing the
  renderer lesson.
- Plan a separate, later teaching variant (`rust-metal-raw`) that implements the
  same launch window with hand-written `objc_msgSend` FFI, to make the binding
  layer explicit by comparison.
- Treat the real cross-language comparison as ownership and safety: ARC
  (Swift/C++), reference counting with `Retained<T>` (Rust), and `unsafe` boundaries
  in both Rust and C++ — not "dependency versus no dependency."

### Consequences

Rust variants stay maintainable and focused on graphics concepts, and the binding
layer is documented as a deliberate tradeoff rather than an accident. The raw-FFI
variant is an optional experiment, not a maintenance burden on every Rust variant.
C++ remains the dependency-lightest host language, which is itself useful teaching
material.
