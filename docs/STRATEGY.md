# Strategic Direction: GPU-Only, Native Compute APIs, and the Accelerator Decade

This document captures the direction chosen on 2026-10-19 after building and
comparing four windowing/renderer approaches (Swift, Rust, and C++ against AppKit
and Metal). It is guidance for what to learn and build next, not a description of
what exists in the repository.

Treat the platform claims as a starting point. Accelerator hardware and driver
support change quickly; re-check sources before making commitments.

## 1. Focus on the GPU

**Decision:** learn and build the renderer on the GPU path. The CPU-drawn AppKit
variants stay as teaching baselines, not as a direction for new work.

Why:

- The CPU path is a dead end for a renderer. Its value was showing what the GPU
  replaces: per-pixel work moves from a serial CPU fill to many parallel GPU
  threads.
- Every modern host — a window, a terminal, a browser, a phone, a headset — accepts
  a GPU-produced image or texture.
- The transferable skill is the submission model: acquire a surface image, record
  passes, submit, present. That model is shared by Metal, Vulkan, D3D12, and
  WebGPU; it is what task 0001's Metal variant already demonstrates in miniature.

What "GPU-only" does **not** mean:

- It does not mean skipping the platform layer. Someone must create the window and
  a native surface on every OS. The objective is to own the smallest possible
  version of it per platform, behind a stable seam.
- It does not mean abandoning CPU code. Command recording, scene updates, resource
  management, and UI remain CPU work. The GPU is the pixel producer.

## 2. "Accelerators" is becoming a spectrum

The phrase "competing accelerators from China" understates the shift. Hardware is
diversifying along two axes:

| Axis | Examples | Implication for a renderer |
| --- | --- | --- |
| **Standard graphics API on non-mainstream GPUs** | Chinese discrete GPUs, integrated GPUs from many vendors | A Vulkan/D3D/Metal backend can reach them; conformance and driver quality vary. |
| **Vendor-specific GPU compute ecosystems** | CUDA, ROCm/HIP, Intel oneAPI/Level Zero, Huawei CANN, Cambricon BANG | Direct use locks you to a vendor; an abstraction layer must translate. |
| **Dedicated AI accelerators (NPU)** | Apple Neural Engine, Qualcomm Hexagon, Huawei Da Vinci, many NPU IP cores | These usually do not run a graphics API. A renderer that handles them needs a compute abstraction. |

### The standard APIs are the portable surface

The most useful portability lever remains **Vulkan**, because it spans Windows,
Linux, Android, HarmonyOS, and — increasingly — non-Western GPU vendors that ship
Vulkan-capable drivers. Direct3D 12 covers Windows and Xbox; Metal covers Apple.

As of the sources below, Chinese GPU vendors have also stabilized their driver
ecosystem around these APIs:

- **Moore Threads** shipped Vulkan support (reported as Vulkan 1.3.290 with 94
  extensions) and OpenGL 4.6 in its late-2025 driver update, alongside its existing
  DirectX 12 support.
- **Lisuan** markets its LX 7G100 as a DirectX 12 gaming GPU, and its Windows
  driver reportedly passes Microsoft's WHQL certification.

That means the earlier plan still holds: a Vulkan backend is the best way to reach
Chinese GPUs and other non-Apple platforms, rather than writing a vendor-specific
backend per chip.

### The compute APIs are the wild west

The renderer does not need vendor compute ecosystems to draw triangles. But if the
goal expands toward compute-driven effects, simulation, or ML-adjacent rendering,
those ecosystems become relevant. OpenCL remains broadly deployed across Chinese
vendors for compute work, despite Vulkan's momentum for graphics.

Practical guidance:

- **Do not target a vendor compute API directly** in this repository. Put compute
  behind the same RHI boundary as graphics.
- **Prefer the portable compute surface**: Vulkan compute first, then WebGPU
  compute when a browser or JavaScript host is involved.
- **Expect translation layers** for NPUs and vendor compute: SPIR-V translation,
  MLIR-based compilers, or vendor SDKs wrapped behind a trait. These are exactly
  the layers that will be volatile.

## 3. Two futures for graphics

There is a real possibility that graphics converges on cross-vendor APIs — so a
Vulkan/D3D12/Metal renderer with a thin RHI reaches almost everything — while
compute accelerates separately. The reason to stay sane is that the two have
different portability physics:

```text
graphics:   Metal ─┐
                   ├── RHI ── your renderer
            Vulkan ─┤
            D3D12  ─┘

compute:    CUDA ──┐
            ROCm ──┤
            CANN ──┼── compute abstraction ── your renderer
            NPU  ──┘
            Vulkan compute ┘
```

The graphics seam is well understood. The compute seam is not, and it may never
fully settle. Treat compute as an optional layer with a narrow interface, not as
the foundation of the renderer.

## 4. Terminals are proving the same point

Rust terminal projects increasingly advertise GPU acceleration, and some now let
shaders compute terminal cell styles at runtime. That is not a special case — it is
the same architecture:

- **Hosting:** the terminal emulator owns a window and a surface; a GPU library
  (for many Rust projects, `wgpu`) provides a portable surface and device.
- **Rendering:** text and cell backgrounds are composited by GPU passes rather
  than a CPU rasterizer.
- **Constraints:** latency, frame pacing, and battery life matter more than raw
  throughput, so these projects often render only on damage and present with
  explicit pacing.

Lessons for this repository:

- The GPU path is becoming the default even for text-heavy output. CPU rasterization
  is increasingly the fallback.
- `wgpu` is the pragmatic tool for *shipping* portable GPU software, and it is a
  strong reference implementation for how to structure surfaces, devices, queues,
  and passes across backends.
- The from-scratch learning variants remain valuable precisely because `wgpu`
  exists: understanding what it abstracts is what lets you choose it deliberately
  rather than by default.

## 5. What this means for the repository

| Question | Position |
| --- | --- |
| Maintained stacks | **Rust and C++ only.** New variants and features go here. |
| Swift variants | **Frozen.** Kept as reference material for the AppKit/Metal comparison; no new features or variants (ADR-0015). Swift does not align with the cross-platform goal. |
| CPU AppKit variants | Keep as baselines and comparisons; no new CPU-renderer work. |
| New rendering work | GPU path only: pipeline, draw calls, frame loop, then renderer features. |
| Next backend | Vulkan, after the Metal path teaches the core concepts; this is also the path to Chinese GPUs and HarmonyOS. |
| Compute work | Behind the RHI, targeting Vulkan compute or WebGPU compute; no vendor SDKs in core code. |
| NPU / AI accelerators | Out of scope for the renderer; if needed later, a separate, narrow adapter. |
| Cross-platform hosting | Keep the platform layer explicit. Use `wgpu`/`winit` only when shipping value outweighs the learning value. |
| Shader authoring | Keep one portable source (likely WGSL or SPIR-V via a toolchain) and translate per backend; this is a future task. |

The Metal and AppKit concepts taught by the Swift variants are already carried by
the Rust and C++ variants, so freezing Swift removes a language host without
removing any lesson.

### Suggested sequence from here

1. ~~**Shader pipeline and a triangle** on Metal (task 0002): vertex buffer, shader
   compilation, pipeline state, draw call.~~ **Done.** The first frame loop and a
   minimal in-flight semaphore landed with it.
2. **Pacing and animation**: time uniforms, a display link that schedules against
   the target timestamp, in-flight frames released by the GPU without blocking,
   and resize-safe drawable handling. GPU work without pacing is not a game
   renderer.
3. **Camera and depth**: uniforms, projection, depth testing, a rotating cube.
4. **Vulkan backend**: implement the same triangle behind a first-cut RHI, then
   refactor the Metal backend to match. This is where the multi-backend skill is
   actually learned.
5. **Shader toolchain and resource binding**: the two biggest backend-difference
   areas.
6. **Compute pass**: a GPU compute effect integrated into the frame, proving the
   compute seam before expanding it.

## 6. Risks and open questions

- **Vulkan parity on new hardware.** Chinese GPU Vulkan drivers are recent.
  Conformance, extension coverage, and bug quality on those drivers are unknown to
  this repository. Test on real hardware before relying on Vulkan for that market.
- **Compute portability.** No vendor-neutral compute API is universally available.
  A compute abstraction may always leak vendor details.
- **Terminal/GPU lessons do not transfer wholesale.** Terminal renderers optimize
  latency and incremental updates; game renderers optimize throughput and frame
  budgets. Compare them for architecture, not for priorities.
- **Slower learning-by-shipping.** From-scratch backends are slower to ship than
  `wgpu`. Revisit the from-scratch policy if a shipping goal appears.
- **Source freshness.** Vendor claims and driver support change quickly. Treat this
  document's platform facts as a snapshot.

## Sources

- [Moore Threads driver update adds Vulkan, OpenGL 4.6 (late 2025)](https://fr.vgtimes.com/tech-and-hardware/143208-les-gpu-moore-threads-chinois-obtiennent-le-support-vulkan-mais-des-problmes-de-consommation-dnergie-persistent.html)
- [Lisuan LX 7G100 DirectX 12 gaming GPU launch coverage](https://www.tweaktown.com/news/111681/lisuan-technologys-lx-7g100-directx-12-gaming-gpu-launches-in-china/index.html)
- [Lisuan LX 7G100 WHQL driver and performance test (Chinese)](http://m.mydrivers.com/newsview/1124184.html?ref=)
- [OpenCL as a cross-vendor compute foundation (IWOCL 2026 talk, China)](https://www.iwocl.org/wp-content/uploads/IWOCL-2026-He-OpenCL-China.pdf)
- [Biren BR100 GPGPU Hot Chips presentation](https://www.hc34.hotchips.org/assets/program/conference/day1/GPU%20HPC/HC2022.BirenTech.MikeHong.LingjieXu.v01.pdf)
- [Shader-driven terminal cell styles with a GPU (tui-shader)](https://github.com/pemattern/tui-shader/)
- [HarmonyOS Vulkan support](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/vulkan)
