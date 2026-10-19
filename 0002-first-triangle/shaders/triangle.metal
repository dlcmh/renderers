// One shader source for the whole task. Both the Rust and C++ variants compile
// this string at runtime with MTLLibrary, so the shader is also the teaching
// artifact: read it next to the pipeline setup on the host side.
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
