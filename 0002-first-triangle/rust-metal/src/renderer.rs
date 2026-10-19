use dispatch2::{DispatchRetained, DispatchSemaphore, DispatchTime};
use objc2::rc::Retained;
use objc2::runtime::ProtocolObject;
use objc2_metal::{
    MTLBuffer, MTLClearColor, MTLCommandBuffer, MTLCommandEncoder, MTLCommandQueue, MTLDevice,
    MTLDrawable, MTLLibrary, MTLLoadAction, MTLPrimitiveType, MTLRenderCommandEncoder,
    MTLRenderPassDescriptor, MTLRenderPipelineDescriptor, MTLRenderPipelineState,
    MTLResourceOptions, MTLStoreAction,
};
use objc2_quartz_core::{CAMetalDrawable, CAMetalLayer};

// Keep at most three frames in flight, matching the drawable pool size. The
// semaphore stops the CPU from recording far ahead of the GPU.
const MAX_FRAMES_IN_FLIGHT: isize = 3;

const CLEAR_COLOR: MTLClearColor = MTLClearColor {
    red: 0.04,
    green: 0.10,
    blue: 0.18,
    alpha: 1.0,
};

/// Everything that persists across frames: device, queue, pipeline, and vertex
/// data. Built once because pipeline compilation is expensive.
pub(crate) struct Renderer {
    pub(crate) device: Retained<ProtocolObject<dyn MTLDevice>>,
    pub(crate) queue: Retained<ProtocolObject<dyn MTLCommandQueue>>,
    pub(crate) pipeline: Retained<ProtocolObject<dyn MTLRenderPipelineState>>,
    pub(crate) positions: Retained<ProtocolObject<dyn MTLBuffer>>,
    pub(crate) colors: Retained<ProtocolObject<dyn MTLBuffer>>,
    pub(crate) frame_semaphore: DispatchRetained<DispatchSemaphore>,
}

impl Renderer {
    pub(crate) fn new() -> Result<Self, String> {
        let Some(device) = objc2_metal::MTLCreateSystemDefaultDevice() else {
            return Err("No Metal device is available on this Mac.".into());
        };
        let Some(queue) = device.newCommandQueue() else {
            return Err("Could not create a Metal command queue.".into());
        };

        let pipeline = Self::build_pipeline(&device)?;

        // Three vertices in counter-clockwise order. Positions are in clip space
        // (-1..1 on both axes); colors are RGBA and interpolated by the GPU.
        let positions: [f32; 6] = [0.0, 0.8, -0.8, -0.8, 0.8, -0.8];
        let colors: [f32; 12] = [1.0, 0.2, 0.3, 1.0, 0.2, 1.0, 0.3, 1.0, 0.3, 0.4, 1.0, 1.0];

        let Some(positions) = Self::buffer_from_slice(&device, &positions) else {
            return Err("Could not allocate the position buffer.".into());
        };
        let Some(colors) = Self::buffer_from_slice(&device, &colors) else {
            return Err("Could not allocate the color buffer.".into());
        };

        Ok(Self {
            device,
            queue,
            pipeline,
            positions,
            colors,
            frame_semaphore: DispatchSemaphore::new(MAX_FRAMES_IN_FLIGHT),
        })
    }

    fn build_pipeline(
        device: &ProtocolObject<dyn MTLDevice>,
    ) -> Result<Retained<ProtocolObject<dyn MTLRenderPipelineState>>, String> {
        let source = objc2_foundation::NSString::from_str(crate::SHADER_SOURCE);

        // Compile at runtime so the shader stays visible next to the host code.
        // Production builds usually precompile the .metal file into a .metallib.
        let library: Retained<ProtocolObject<dyn MTLLibrary>> =
            match device.newLibraryWithSource_options_error(&source, None) {
                Ok(library) => library,
                Err(error) => return Err(format!("Shader compilation failed: {error}")),
            };

        let Some(vertex_function) =
            library.newFunctionWithName(objc2_foundation::ns_string!("vertex_main"))
        else {
            return Err("Shader has no `vertex_main` function.".into());
        };
        let Some(fragment_function) =
            library.newFunctionWithName(objc2_foundation::ns_string!("fragment_main"))
        else {
            return Err("Shader has no `fragment_main` function.".into());
        };

        let descriptor = MTLRenderPipelineDescriptor::new();
        descriptor.setVertexFunction(Some(&vertex_function));
        descriptor.setFragmentFunction(Some(&fragment_function));

        // The pipeline must declare the format of every attachment it writes.
        // It must match the CAMetalLayer's pixel format.
        // SAFETY: Color attachment slot 0 always exists on a pipeline descriptor.
        let attachment = unsafe { descriptor.colorAttachments().objectAtIndexedSubscript(0) };
        attachment.setPixelFormat(crate::PIXEL_FORMAT);

        match device.newRenderPipelineStateWithDescriptor_error(&descriptor) {
            Ok(pipeline) => Ok(pipeline),
            Err(error) => Err(format!("Pipeline creation failed: {error}")),
        }
    }

    fn buffer_from_slice<T>(
        device: &ProtocolObject<dyn MTLDevice>,
        values: &[T],
    ) -> Option<Retained<ProtocolObject<dyn MTLBuffer>>> {
        let length = std::mem::size_of_val(values);
        let pointer = std::ptr::NonNull::new(values.as_ptr().cast_mut().cast())?;
        // SAFETY: `pointer` points to `length` initialized bytes. Metal copies
        // them, so the slice does not need to outlive the call.
        unsafe {
            device.newBufferWithBytes_length_options(
                pointer,
                length,
                MTLResourceOptions::StorageModeShared,
            )
        }
    }

    /// Acquire, record, present, submit. This is the complete GPU frame.
    pub(crate) fn draw(&self, layer: &CAMetalLayer) {
        // Wait for an in-flight slot. The guard signals the semaphore when it is
        // dropped after the frame has been submitted.
        let Ok(_slot) = self.frame_semaphore.try_acquire(DispatchTime::FOREVER) else {
            return;
        };

        let Some(drawable) = layer.nextDrawable() else {
            return;
        };
        let Some(command_buffer) = self.queue.commandBuffer() else {
            return;
        };

        let pass = MTLRenderPassDescriptor::new();
        // SAFETY: Attachment slot 0 always exists on a render pass descriptor.
        let attachment = unsafe { pass.colorAttachments().objectAtIndexedSubscript(0) };
        attachment.setTexture(Some(&drawable.texture()));
        attachment.setLoadAction(MTLLoadAction::Clear);
        attachment.setStoreAction(MTLStoreAction::Store);
        attachment.setClearColor(CLEAR_COLOR);

        let Some(encoder) = command_buffer.renderCommandEncoderWithDescriptor(&pass) else {
            return;
        };
        encoder.setRenderPipelineState(&self.pipeline);
        // SAFETY: The buffers are owned by the renderer and hold exactly three
        // vertices. Indices 0 and 1 match the shader's buffer attributes.
        unsafe {
            encoder.setVertexBuffer_offset_atIndex(Some(&self.positions), 0, 0);
            encoder.setVertexBuffer_offset_atIndex(Some(&self.colors), 0, 1);
            encoder.drawPrimitives_vertexStart_vertexCount(MTLPrimitiveType::Triangle, 0, 3);
        }
        encoder.endEncoding();

        let drawable_mtl: &ProtocolObject<dyn MTLDrawable> = drawable.as_ref();
        command_buffer.presentDrawable(drawable_mtl);
        command_buffer.commit();
    }
}

// Metal objects are not `Send`/`Sync`, so the renderer is stored in a
// thread-local on the main thread. That matches AppKit's threading model: all
// rendering happens on the main thread.
thread_local! {
    static RENDERER: std::cell::OnceCell<Renderer> = const { std::cell::OnceCell::new() };
}

/// Initialize the renderer once and return a reference to it.
///
/// The `'static` lifetime is sound because the value lives in a thread-local
/// for the rest of the process and is never removed or moved after being set.
/// Rendering only happens on the main thread, the same thread that reads it.
pub(crate) fn renderer() -> Option<&'static Renderer> {
    RENDERER.with(|cell| {
        if cell.get().is_none() {
            match Renderer::new() {
                Ok(renderer) => {
                    let _ = cell.set(renderer);
                }
                Err(message) => {
                    eprintln!("{message}");
                    return None;
                }
            }
        }

        cell.get().map(|renderer| {
            // SAFETY: The renderer was set above or in an earlier call, lives
            // for the rest of the process, and is never mutated.
            unsafe { &*(renderer as *const Renderer) }
        })
    })
}
