// A `.metal` file is Metal Shading Language (MSL) source: a small C++-like
// program that runs on the GPU. A vertex function runs once per vertex; a
// fragment function runs once per covered pixel. This file names two entry
// points, `vertex_main` and `fragment_main`, which the host looks up by name
// after compiling the source into an MTLLibrary.
//
// The `[[...]]` attributes are how the shader declares what the host must bind:
// `[[buffer(n)]]` matches host bindings at index n, `[[vertex_id]]` is the
// vertex index, `[[position]]` is the clip-space output, and `[[stage_in]]` is
// the interpolated vertex output handed to the fragment stage.
//
// See docs/GRAPHICS-CONCEPTS.md, section "`.metal` files and the Metal Shading
// Language", for runtime versus offline compilation and the equivalents in
// Vulkan, D3D12, and WebGPU.
//
// One shader source for the whole task: both the Rust and C++ variants compile
// it at runtime with MTLLibrary, so the shader is also the teaching artifact.
// Read it next to the pipeline setup on the host side.
#include <metal_stdlib>
using namespace metal;

// Passed from the vertex shader to the fragment shader. `[[position]]` is the
// clip-space position; `color` is interpolated across the triangle.
struct VertexOut {
    float4 position [[position]];
    float4 color;
};

// `vertex_id` is the index of the vertex being processed (0, 1, 2, ...).
// Buffers bound at index 0 and 1 hold positions and colors respectively.
vertex VertexOut vertex_main(uint vertexID [[vertex_id]],
                             constant float2 *positions [[buffer(0)]],
                             constant float4 *colors [[buffer(1)]]) {
    VertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.color = colors[vertexID];
    return out;
}

// `[[stage_in]]` receives the interpolated VertexOut values.
fragment float4 fragment_main(VertexOut in [[stage_in]]) {
    return in.color;
}
