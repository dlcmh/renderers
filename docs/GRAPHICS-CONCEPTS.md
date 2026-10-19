# Graphics Concepts and Portability

A field guide for this repository: the vocabulary behind the code, the layers a
renderer is built from, and the things that change when you target another
platform.

Written for someone coming from web development. The code in this repository is
the primary material; this document is the map that keeps the terminology from
blurring together. Last reviewed: 2026-10-19.

## The stack, top to bottom

```text
your game / app
  └── renderer                 decides what to draw, in what order
        └── RHI                your common interface over GPU APIs
              ├── Metal backend        (macOS, iOS)
              ├── Vulkan backend       (Windows, Linux, Android, HarmonyOS)
              └── D3D12 backend        (Windows, Xbox)
                    └── driver         written by the GPU vendor
                          └── GPU
  └── platform layer           window, event loop, input, native surface
```

The **platform layer** and the **GPU layer** are different problems. Keeping them
separate is the single most important portability decision in this repository.

## Web-development translation

| Web world | Native graphics world | Notes |
| --- | --- | --- |
| `<canvas>` | window + surface | The canvas is not the GPU API; it is where pixels are presented. |
| WebGL / WebGPU | graphics API | The contract you use to submit GPU work. |
| `requestAnimationFrame` | display link / vsync callback | Drives one frame per refresh. |
| Three.js | renderer / scene layer | Sits above the raw API. |
| Browser event loop | platform event loop | The OS delivers input and lifecycle events. |
| WebGPU implementation (Dawn, `wgpu`) | RHI / GPU abstraction layer | Maps one API onto Metal, Vulkan, or D3D12. |
| React | game engine / scene graph | Much higher level than a renderer. |

“Using a graphics API” is like using the browser’s Canvas or WebGPU API directly.
“Using `wgpu`” is like using a cross-browser wrapper. “Using Bevy” is like using a
full application framework.

## Vocabulary

### Graphics API

The contract for submitting work to a GPU: devices, queues, buffers, textures,
pipelines, command buffers, and presentation. Metal, Vulkan, Direct3D 12, and
WebGPU are graphics APIs.

### Backend

In this repository, a **backend** is the API-specific implementation behind the
RHI: the Metal backend, the Vulkan backend, the D3D12 backend. People also say
“Metal is a backend” casually; both usages are common. The important thing is that
a backend is replaceable without rewriting the renderer.

### Driver

The GPU vendor’s software that translates API commands into hardware work. You do
not write the driver; you write against its API. Driver bugs and version
differences are a real portability cost.

### RHI

**Render Hardware Interface.** A thin abstraction over one or more graphics APIs.
It exposes concepts such as `Device`, `Queue`, `Buffer`, `Texture`, `Pipeline`, and
`Surface`, so the renderer does not call Metal or Vulkan directly. Unreal Engine’s
RHI is the best-known example; `bgfx` is a cross-platform rendering library with a
similar role.

An RHI is **not** an engine and should not try to hide every difference between
backends. It is a seam for portability and testing.

### HAL

**Hardware Abstraction Layer.** A broader, older term. It can mean the same thing
as RHI, or a lower-level layer that also covers memory, platform, or device
discovery. When someone says “GPU HAL”, ask which layer they mean. “RHI” or
“graphics abstraction layer” is more precise here.

### Renderer

The layer that turns a scene or a frame description into passes and draw calls. It
owns high-level decisions: shadow passes, post-processing, material variants, and
eventually a render graph. It consumes the RHI.

### Engine

Renderer + scene graph + assets + physics + audio + UI + scripting + tooling.
Bevy, Unity, and Unreal are engines. This repository is deliberately not building
one yet.

### Platform layer

The native code that creates a window, pumps the event loop, handles input, and
produces a native surface handle. On macOS that is AppKit; on Windows, Win32; on
Linux, X11 or Wayland; on HarmonyOS, ArkTS + NAPI + XComponent.

### Native window handle

An opaque OS-specific pointer or identifier for a window or view: `NSView*`,
`HWND`, `ANativeWindow*`, `OHNativeWindow*`. A GPU API uses it to create a
presentable surface. Keep it opaque in cross-platform code.

### Surface

The presentable drawing target. A surface owns or references the images that the
OS compositor can display. Metal calls the images **drawables**; Vulkan calls the
collection a **swapchain**.

### Swapchain

A rotating set of presentable images with acquisition and presentation rules. The
OS or driver decides how many images exist and when one is free. A Metal
`CAMetalLayer` is the equivalent mechanism, with `nextDrawable()` borrowing an
image.

### Frame

One iteration of “acquire an image, record work, submit, present.” A frame is not
necessarily one command buffer; it can contain many passes and submissions.

### Command queue / command buffer

A **queue** is a submission channel to one device. A **command buffer** (Vulkan,
Metal) or **command list** (D3D12) is recorded work submitted to a queue.

- Metal: `MTLCommandQueue` → `MTLCommandBuffer` → render/blit/compute encoder.
- Vulkan: `VkQueue` ← `VkCommandBuffer`.
- D3D12: command queue ← command list.
- WebGPU: `GPUQueue.submit()` ← `GPUCommandBuffer`.

Queues commonly map to hardware queues with different capabilities (graphics,
compute, transfer, presentation), though the exact model varies.

### Render pass

A group of rendering work that writes one or more attachments (color, depth,
stencil). It defines how those attachments are loaded and stored:

- `loadAction = .clear` means “do not load the old contents.”
- `storeAction = .store` means “keep the result for later use or presentation.”

Metal expresses this with `MTLRenderPassDescriptor`; Vulkan with a render pass or
dynamic rendering; D3D12 with render-target and depth-stencil views. WebGPU uses a
render pass encoder.

### Pipeline / pipeline state

The compiled combination of shaders and fixed-function state: blend mode, depth
test, primitive topology, vertex layout, and so on. Pipeline creation is often
expensive, so create and cache pipelines at startup rather than per frame.

### Shader

A program that runs on the GPU. Common stages: **vertex**, **fragment** (pixel),
and **compute**. Shader languages differ by API:

| API | Shader language / IR |
| --- | --- |
| Metal | Metal Shading Language (MSL) |
| Vulkan | SPIR-V (usually authored in GLSL or HLSL) |
| Direct3D 12 | HLSL, compiled to DXIL |
| WebGPU | WGSL |

Shader translation is one of the largest real-world portability costs. Tools such
as SPIRV-Cross, DXC, and Naga translate between representations, but not every
feature maps cleanly.

### Buffer and texture

A **buffer** is linear GPU-accessible memory: vertices, indices, uniforms, storage
data. A **texture** is a multidimensional image: color attachments, sampled images,
depth buffers. Both have usage flags and lifetimes that matter for performance and
correctness.

### Descriptor / binding

How a shader finds a buffer or texture. Vulkan uses descriptor sets and pipeline
layouts; D3D12 uses descriptor heaps and root signatures; Metal uses argument
tables or direct binding; WebGPU uses bind groups. This is one of the least
portable parts of any RHI.

### Synchronization

The rules that prevent the CPU, GPU, and presentation engine from reading or
writing the same resource at the wrong time. Vulkan requires explicit barriers,
semaphores, and fences. Metal and D3D12 automate more hazard tracking, but not all
of it. Getting this wrong causes flicker, corrupted frames, or crashes.

### Present

Handing a finished image to the compositor. In Metal:
`commandBuffer.present(drawable)`. In Vulkan: `vkQueuePresentKHR`. In D3D12:
`IDXGISwapChain::Present`. In WebGPU, presentation is managed by the canvas.

### VSync and display link

Presentation paced to the display refresh. `requestAnimationFrame` is the web
version; macOS has `CADisplayLink`, Windows has `DwmFlush`/waitable swapchains, and
Vulkan uses `VK_PRESENT_MODE_FIFO_KHR` for vsync-like pacing.

### Triple buffering

Keeping multiple frames in flight so the CPU can record while the GPU renders and
the display presents. It improves throughput but adds latency and requires a
semaphore or fence to prevent the CPU from running too far ahead. A pool of
drawables or swapchain images is not automatically triple buffering.

### Retina / DPI

Window coordinates are in points; drawable and framebuffer sizes are in pixels. A
2× display needs a 2× larger drawable. Getting this wrong produces blurry or
cropped output.

### sRGB, HDR, and color management

The same numeric color can look different depending on whether a format is sRGB,
what color space the surface uses, and whether the compositor applies tone mapping.
Start with a known format and validate visually; color is a portability trap.

### Render graph

A modern renderer technique for declaring passes and their resource dependencies,
then scheduling barriers and memory aliasing automatically. It is an advanced
optimization, not a starting point.

### FFI, bindings, NAPI, XComponent

- **FFI**: Foreign Function Interface — Rust calling C or Objective-C.
- **Bindings**: Rust declarations and safe wrappers for a foreign API.
- **NAPI**: the native bridge HarmonyOS uses to load a native shared library from
  ArkTS/JavaScript.
- **XComponent**: the ArkUI component that gives native code a surface/window
  handle for custom rendering.

## One frame, four APIs

The names change; the shape does not.

| Step | Metal | Vulkan | Direct3D 12 | WebGPU |
| --- | --- | --- | --- | --- |
| Acquire image | `nextDrawable()` | `vkAcquireNextImageKHR` | `GetCurrentBackBufferIndex` | `getCurrentTexture()` |
| Record commands | command buffer + encoder | command buffer | command list | command encoder |
| Submit | `commit()` | `vkQueueSubmit` | `ExecuteCommandLists` | `queue.submit()` |
| Synchronize | automatic + `addCompletedHandler` | semaphores / fences / barriers | fences / barriers | browser-managed |
| Present | `present(drawable)` | `vkQueuePresentKHR` | `Present` | implicit on canvas |

This is why task 0001’s Metal clear is a useful foundation: it teaches the
acquire/record/submit/present loop that every backend shares.

## The major graphics APIs

| API | Owner | Main platforms | Shading | Character |
| --- | --- | --- | --- | --- |
| Metal | Apple | macOS, iOS, iPadOS | MSL | Low-level, Apple-only; unified memory on Apple silicon; less verbose than Vulkan. |
| Vulkan | Khronos | Windows, Linux, Android, HarmonyOS | SPIR-V | Explicit, verbose, cross-platform; requires careful synchronization. |
| Direct3D 12 | Microsoft | Windows, Xbox | HLSL → DXIL | Explicit; deep Microsoft ecosystem and tooling. |
| Direct3D 11 | Microsoft | Windows | HLSL | Older, simpler, still common; less explicit than D3D12. |
| OpenGL / OpenGL ES | Khronos | Broad legacy support | GLSL | Older state-machine API; deprecated on macOS, still used on Android and embedded systems. |
| WebGPU | W3C | Browsers | WGSL | Modern web API; implemented on top of Metal/Vulkan/D3D12. |

“DirectX” is a family, not a single API. It includes Direct3D 11/12, DXGI
(presentation), and related components. When someone says “Windows uses DirectX,”
they usually mean Direct3D, but Vulkan also runs natively on Windows.

### Is OpenGL ES still relevant?

Yes, but as a compatibility API rather than the direction of new work.

- **The spec is effectively frozen.** OpenGL ES 3.2 dates from 2015. Khronos has
  concentrated new feature work on Vulkan, and OpenGL ES updates are maintenance
  rather than growth.
- **It is still everywhere.** Android continues to support OpenGL ES, and it
  remains common for simpler apps, older devices, and embedded/automotive
  systems. [Huawei documents native OpenGL ES APIs](https://developer.huawei.com/consumer/en/doc/harmonyos-references/opengles)
  for HarmonyOS alongside Vulkan.
- **The web depends on it.** WebGL 1 and 2 are based on OpenGL ES 2.0 and 3.0, so
  GLES concepts remain widespread even in browser code. WebGPU is the modern
  replacement.
- **It survives as a translation target.** ANGLE implements OpenGL ES on top of
  Direct3D, Metal, and Vulkan, and is used by browsers and other portability
  layers. That keeps GLES relevant even where it is not the native API.
- **Apple has moved on.** OpenGL and OpenGL ES are deprecated on Apple platforms;
  Metal is the supported path. macOS has no native OpenGL ES implementation.
- **Desktop OpenGL is not OpenGL ES.** OpenGL ES is the mobile/embedded subset;
  desktop OpenGL is a separate legacy API. Neither is a good first target for a
  new renderer in 2026.

For this repository, GLES is not a primary backend. It is a candidate for a later
compatibility backend if old Android or HarmonyOS hardware needs it, or as a
simpler teaching comparison. Vulkan remains the better second backend for
portability.

## Platform support at a glance

| Platform | Host / UI | Native GPU APIs | Notes |
| --- | --- | --- | --- |
| macOS | AppKit / SwiftUI | Metal | OpenGL is deprecated; Vulkan requires MoltenVK translation. |
| iOS / iPadOS | UIKit / SwiftUI | Metal | No Vulkan. |
| Windows | Win32 / WinUI | D3D11, D3D12, Vulkan, OpenGL | Vulkan is supported by GPU drivers; D3D and Vulkan coexist. |
| Linux | X11 / Wayland | Vulkan, OpenGL | Vulkan is the modern default. |
| Android | Java/Kotlin + JNI / NativeActivity | Vulkan, OpenGL ES | Device support and driver quality vary widely. |
| HarmonyOS Next | ArkTS / ArkUI | Vulkan (native), OpenGL ES | Native code loads via NAPI; custom surfaces use XComponent. See below. |
| Web | Browser | WebGPU, WebGL | No direct native API access; the browser owns the device. |
| Chinese discrete GPUs | Windows (mostly) | Vulkan, D3D12, OpenGL; vendor compute (MUSA, CANN, etc.) | Vendors such as Moore Threads and Lisuan ship mainstream APIs; driver maturity and power efficiency still lag. |
| Terminals | Native app window | Whatever the host uses (often `wgpu`) | GPU-accelerated terminals are the same renderer problem in text form. |

### Accelerators are not all GPUs

Hardware is splitting along three lines, and they portability behave very
differently:

| Category | Examples | Portable API? |
| --- | --- | --- |
| Mainstream GPU with standard APIs | AMD, NVIDIA, Intel, Apple, Chinese GPU vendors | Yes: Metal, Vulkan, D3D12 on the OS side |
| Vendor GPU compute ecosystem | CUDA, ROCm/HIP, Level Zero, MUSA, CANN, BANG | No; vendor-specific |
| Dedicated AI accelerator (NPU) | Apple Neural Engine, Qualcomm Hexagon, Huawei Da Vinci | No; usually behind vendor SDKs and compilers |

The graphics path still has a cross-vendor API surface. The compute path does not,
beyond Vulkan compute and WebGPU compute. Keep graphics and compute behind
separate seams, and do not target a vendor compute SDK from core renderer code.
For the strategic direction behind this, see [docs/STRATEGY.md](STRATEGY.md).

### Vulkan on Windows

Yes, Vulkan works on Windows. It is not a Linux-only or Android-only API.

- Modern GPU drivers from AMD, NVIDIA, and Intel ship Vulkan implementations on
  Windows.
- Vulkan is a peer of Direct3D 12, not a layer on top of it.
- A Windows program can use D3D11, D3D12, Vulkan, or OpenGL. The choice depends on
  portability goals, features, tooling, and driver support.
- D3D12 is usually the path of least resistance for a Windows-only or Xbox title;
  Vulkan is attractive when one backend must also serve Linux, Android, and
  HarmonyOS.
- “DirectX” and “Vulkan” are not mutually exclusive platform choices; games ship
  with both backends.

For this repository, **Vulkan is the natural second backend**: it covers Windows,
Linux, Android, and HarmonyOS with one API, while Metal covers Apple platforms.
D3D12 can be a later third backend if Windows/Xbox-specific features matter.

macOS is the exception: there is no native Vulkan driver. MoltenVK translates
Vulkan to Metal, but that adds a third-party translation layer. Native Metal is
the right first Apple backend.

A Vulkan backend is also the most realistic path to non-Western GPU vendors. Moore
Threads added Vulkan support in its late-2025 driver line, Lisuan targets DirectX 12
on Windows, and Huawei documents Vulkan for HarmonyOS. Driver quality and
conformance on that hardware must be tested, not assumed. See
[docs/STRATEGY.md](STRATEGY.md#the-standard-apis-are-the-portable-surface) for the
sources and caveats.

## HarmonyOS Next specifics

HarmonyOS Next is not simply “another Linux window.” The host model is different:

```text
ArkTS Ability (app lifecycle, UI)
  └── NAPI native module boundary
        └── Rust cdylib
              ├── XComponent surface / native window handle
              └── Vulkan or OpenGL ES
```

Important consequences:

- The app entry point is **ArkTS**, not a native `main`. Native Rust is packaged as
  a shared library and loaded through NAPI. The community [ohos-rs](https://ohos.rs/en/blog/2025-01-24/)
  project provides Ability/NAPI wrappers and has adapted `winit`/`glutin` in a
  preview form.
- Custom rendering uses [XComponent](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/napi-xcomponent-guidelines),
  which exposes a native surface handle.
- Huawei documents [Vulkan support](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/vulkan)
  for native development. OpenGL ES also appears in native samples.
- The Rust ecosystem around HarmonyOS is younger and more community-driven than
  the macOS/iOS ecosystem. Expect to evaluate, patch, or write bindings yourself.
- You cannot produce one standalone Rust binary that also runs as a HarmonyOS
  app. The platform layer is necessarily host-specific; the RHI and renderer can
  still be shared.

The practical portability strategy is therefore **not** “zero third-party crates
everywhere.” It is “thin bindings where they are mature, hand-written or vendored
FFI where they are not, and a clean boundary around both.”

These details reflect public documentation and community tooling as of the
sources above; verify them against the current DevEco Studio and HarmonyOS SDK
before committing to a target version.

## Portability checklist

When adding a platform or backend, work through these in order:

1. **Host model.** Is the app a standalone executable, a shared library loaded by
   ArkTS/Java, or a browser tab? Who owns the event loop?
2. **Window and input.** Which native window system creates the window, and how are
   resize, close, and input delivered?
3. **Surface and resize.** What native handle does the GPU API need? What happens
   to the swapchain/drawable on resize or display-scale change?
4. **GPU API availability.** Which API and version can you rely on? Which
   extensions are optional? Query capabilities rather than checking the OS name.
5. **Shader toolchain.** Which shading language and compiler? How will shaders be
   compiled, packaged, and cross-compiled? This is often the largest hidden cost.
6. **Queue and synchronization model.** How many queues? What barriers,
   semaphores, or fences are required? What does the API track automatically?
7. **Resource binding.** Descriptor sets, root signatures, argument buffers, or
   bind groups. This affects every shader and pipeline.
8. **Memory model.** Unified memory (Apple silicon, some mobile) versus discrete
   GPU memory; residency, staging buffers, and upload heuristics.
9. **Presentation and color.** sRGB versus linear formats, HDR/EDR, color space,
   DPI scaling, and compositor behavior.
10. **Frame pacing.** VSync, variable refresh rate, display link, and how many
    frames are allowed in flight.
11. **Packaging and distribution.** `.app` bundles, `.exe`, `.hap`, shared
    libraries, signing, sandboxing, and store policies.
12. **Bindings and toolchain.** Are the Rust bindings maintained? Can you
    cross-compile? Does the linker see the platform SDK? What is the fallback if a
    binding is missing?
13. **Debugging and profiling.** Xcode GPU capture, RenderDoc, PIX, Nsight, Android
    GPU Inspector, browser WebGPU tools. Plan for a capture path on each platform.
14. **Test matrix.** Real devices, GPU vendors, OS versions, and CI runners. GPU
    bugs often appear only on specific drivers.

## Architecture guidance

### Build one backend first

Do not design a universal graphics API on paper. Implement Metal, then implement a
second backend (Vulkan), then extract the RHI from the differences that actually
appeared. This is the same advice as “do not write the interface before the second
implementation” in web development.

### Keep the seams narrow

```text
renderer (safe, backend-agnostic)
  └── rhi traits (plain Rust types, opaque handles)
        └── metal backend (unsafe FFI isolated here)
        └── vulkan backend (unsafe FFI isolated here)
  └── platform traits (window + surface)
        └── macos (AppKit)
        └── harmony (NAPI + XComponent)
```

- No `objc2`, `ash`, `windows`, or `ohos-rs` types in the renderer’s API.
- Surface creation returns an opaque handle that the GPU backend can consume.
- Prefer capability queries over `#[cfg(target_os = ...)]` inside the renderer.
- Isolate unsafe code and document each unsafe block’s invariant.

### Be explicit about “from scratch”

For this repository, the working definition is:

| Choice | Policy |
| --- | --- |
| Game engine (Bevy, Godot) | No |
| GPU abstraction framework (`wgpu`, `bgfx`) | No for the learning backends |
| Cross-platform windowing framework (`winit`) | No for now; it hides the platform lesson |
| Thin API bindings (`objc2`, `ash`, `metal`) | Yes, behind our own modules |
| Objective-C++ at the macOS boundary | Yes — AppKit and Metal are Objective-C APIs |
| Hand-written FFI where bindings are missing | Yes |
| Our own RHI, renderer, and platform boundary | Yes — this is the lesson |

A binding is not a framework. The renderer, RHI, and platform decisions remain
yours. The C++ variants use Objective-C++ rather than a cross-platform windowing
library because the native boundary itself is part of the lesson; see
[ADR-0011](DECISIONS.md) and the
[C++ AppKit README](../0001-empty-launch-window/cpp-appkit/README.md).

### Language asymmetry: Objective-C++ versus Rust bindings

The four macOS host stacks do not pay the same price for language interop. That is
expected, and it is part of what the variants teach.

| Language | Needs a binding layer? | How it reaches AppKit/Metal |
| --- | --- | --- |
| Swift | No | Built-in Objective-C interop. |
| C++ | No | The compiler is the binding: Objective-C++ (`.mm`) compiles C++ and Objective-C in one translation unit, with ARC for lifetime. |
| Rust | Yes | `objc2` plus generated framework crates (`objc2-app-kit`, `objc2-metal`, `objc2-quartz-core`). Rust cannot include Cocoa headers or message-send directly. |

So C++ developers write the same AppKit and Metal calls in the language Apple's
APIs are written in, while Rust developers depend on a third-party translation
layer. That layer is substantial: message-send safety, ARC-like `Retained<T>`,
runtime class registration (`define_class!`), protocol objects, and bindings for the
SDK surface used here.

C++ is not free of external machinery either. Its stack is CMake, framework
linking (Cocoa, Metal, QuartzCore, CoreGraphics), `clang-format`, and the sanitizers.
The difference is that the interop itself is not a dependency: native Objective-C
and C++ compile together.

Tradeoffs:

- **C++:** fewer moving parts, every OS call is native, and no binding can lag an
  API. The cost is Apple-specific Objective-C++ code that never runs on other
  platforms without a rewrite.
- **Rust:** more moving parts, but the host code is memory-safe Rust with a
  well-tested binding. The risk is that a binding lags an API you need, and the
  unsafe boundary still has to be understood.

Policy for this repository: thin bindings stay the default for Rust, and a
hand-written FFI variant is deferred until the renderer path is established. See
[ADR-0014](DECISIONS.md). The raw-FFI comparison is planned later as an explicit
teaching variant (`rust-metal-raw`) rather than as the foundation of every Rust
variant.

### Rust crates by role

| Crate | Role | Verdict for this repo |
| --- | --- | --- |
| `objc2`, `objc2-app-kit`, `objc2-metal` | Thin Apple API bindings | Used by the `rust-appkit` and `rust-metal` variants |
| `metal` | Higher-level Metal wrapper | Alternative; compare later |
| `ash` | Thin Vulkan bindings | Use for a future Vulkan backend |
| `bindgen` | Generates C bindings | Tooling, not a runtime dependency |
| `raw-window-handle` | Common native-handle trait | Useful when a second platform lands |
| `ohos-rs`, `napi-rs` | HarmonyOS/NAPI bindings | Evaluate when targeting HarmonyOS |
| `winit` | Cross-platform window/event loop | Defer; hides native windowing |
| `wgpu` | GPU abstraction over native APIs | Not for from-scratch backend learning; strong reference for shipping, and what GPU-accelerated Rust terminals typically use |

Crate maturity and APIs change; re-check versions and maintenance status before
adopting one. For the strategic reading of when to use `wgpu` versus the
from-scratch backends, see
[docs/STRATEGY.md](STRATEGY.md#4-terminals-are-proving-the-same-point).

## Suggested learning path

1. **Task 0001 (done):** native window + a Metal clear. Learn the surface,
   drawable, command queue, and render pass.
2. **Next:** shader pipeline + triangle. Learn shader compilation, pipeline state,
   vertex buffers, draw calls.
3. **Then:** a continuous frame loop with a display link and in-flight frame
   limiting. Learn pacing and synchronization.
4. **Then:** uniforms, textures, depth, and a simple 3D camera.
5. **Then:** a second backend. Vulkan is the most useful target for Windows,
   Linux, Android, and HarmonyOS; compare it with Metal and extract the RHI.
6. **Later:** shader cross-compilation, render graph, and optional D3D12/WebGPU
   backends.

The goal is not to learn every API at once. It is to make the shared concepts
obvious, then let each backend show where it differs.

## Sources and further reading

- [Apple Metal documentation](https://developer.apple.com/documentation/metal)
- [Khronos Vulkan specification and guides](https://www.vulkan.org/)
- [Microsoft Direct3D 12 documentation](https://learn.microsoft.com/en-us/windows/win32/direct3d12/directx-12-programming-guide)
- [WebGPU specification](https://www.w3.org/TR/webgpu/)
- [HarmonyOS: Vulkan support capability](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/vulkan)
- [HarmonyOS: OpenGL ES standard libraries](https://developer.huawei.com/consumer/en/doc/harmonyos-references/opengles)
- [Android: Use Vulkan for graphics](https://developer.android.com/games/develop/vulkan/overview)
- [Khronos OpenGL ES registry](https://www.khronos.org/opengles/)
- [HarmonyOS: custom rendering with XComponent](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/napi-xcomponent-guidelines)
- [ohos-rs: OpenHarmony Ability and winit for Harmony](https://ohos.rs/en/blog/2025-01-24/)
- [winit issue: OpenHarmony support discussion](https://github.com/rust-windowing/winit/issues/4081)

External documentation changes quickly. Treat platform-specific claims as a
starting point and verify them against the SDK version you are targeting.
