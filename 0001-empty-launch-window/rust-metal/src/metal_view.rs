use objc2::rc::Retained;
use objc2::runtime::ProtocolObject;
use objc2::{DefinedClass, MainThreadMarker, MainThreadOnly, define_class, msg_send};
use objc2_app_kit::{NSApplication, NSEvent, NSView};
use objc2_foundation::{NSRect, NSSize};
use objc2_metal::{
    MTLClearColor, MTLCommandBuffer, MTLCommandEncoder, MTLCommandQueue, MTLDevice, MTLDrawable,
    MTLLoadAction, MTLPixelFormat, MTLRenderPassDescriptor, MTLStoreAction,
};
use objc2_quartz_core::{CAMetalDrawable, CAMetalLayer};

const CLEAR_COLOR: MTLClearColor = MTLClearColor {
    red: 0.04,
    green: 0.10,
    blue: 0.18,
    alpha: 1.0,
};

pub(crate) struct MetalViewIvars {
    command_queue: Retained<ProtocolObject<dyn MTLCommandQueue>>,
    metal_layer: Retained<CAMetalLayer>,
}

define_class!(
    // SAFETY: `NSView` is a normal AppKit view with no subclassing requirements.
    // The ivars own the Metal objects; AppKit owns the view itself.
    #[unsafe(super = NSView)]
    #[thread_kind = MainThreadOnly]
    #[ivars = MetalViewIvars]
    pub(crate) struct MetalView;

    impl MetalView {
        /// AppKit calls this when the view is resized. The drawable must match
        /// the new size in pixels, then a fresh frame is presented.
        #[unsafe(method(setFrameSize:))]
        fn set_frame_size(&self, new_size: NSSize) {
            // SAFETY: `setFrameSize:` is NSView's designated geometry setter, and
            // `new_size` is a valid NSSize supplied by AppKit.
            let _: () = unsafe { msg_send![super(self), setFrameSize: new_size] };
            self.update_drawable_size();
            self.render();
        }

        #[unsafe(method(viewDidMoveToWindow))]
        fn view_did_move_to_window(&self) {
            // SAFETY: We call the superclass implementation on the main thread.
            let _: () = unsafe { msg_send![super(self), viewDidMoveToWindow] };
            self.update_drawable_size();
            self.render();
        }

        #[unsafe(method(viewDidChangeBackingProperties))]
        fn view_did_change_backing_properties(&self) {
            // SAFETY: We call the superclass implementation on the main thread.
            let _: () = unsafe { msg_send![super(self), viewDidChangeBackingProperties] };
            self.update_drawable_size();
            self.render();
        }

        #[unsafe(method(acceptsFirstResponder))]
        fn accepts_first_responder(&self) -> bool {
            true
        }

        #[unsafe(method(keyDown:))]
        fn key_down(&self, event: &NSEvent) {
            if event.keyCode() == 53 {
                let app = NSApplication::sharedApplication(self.mtm());
                app.terminate(None);
            }
        }
    }
);

impl MetalView {
    pub(crate) fn new(
        mtm: MainThreadMarker,
        frame: NSRect,
        device: &ProtocolObject<dyn MTLDevice>,
        command_queue: Retained<ProtocolObject<dyn MTLCommandQueue>>,
    ) -> Retained<Self> {
        // A CAMetalLayer owns the drawable pool composited by the window server.
        // This is the Rust equivalent of the Swift `MetalView` layer setup.
        let metal_layer = CAMetalLayer::new();
        metal_layer.setDevice(Some(device));
        metal_layer.setPixelFormat(MTLPixelFormat::BGRA8Unorm);
        metal_layer.setFramebufferOnly(true);
        metal_layer.setOpaque(true);
        metal_layer.setMaximumDrawableCount(3);

        let view = Self::alloc(mtm).set_ivars(MetalViewIvars {
            command_queue,
            metal_layer,
        });

        // SAFETY: `initWithFrame:` is NSView's designated initializer and the
        // receiver is a freshly allocated MetalView.
        let view: Retained<Self> = unsafe { msg_send![super(view), initWithFrame: frame] };

        view.setWantsLayer(true);
        view.setLayer(Some(&view.ivars().metal_layer));
        view.update_drawable_size();
        view
    }

    /// Drawable size is in pixels, not points. A Retina window needs twice the
    /// resolution, and moving between displays can change the scale.
    fn update_drawable_size(&self) {
        let scale = self
            .window()
            .map_or(1.0, |window| window.backingScaleFactor());
        let layer = &self.ivars().metal_layer;
        layer.setContentsScale(scale);

        let pixel_size = self.convertRectToBacking(self.bounds()).size;
        if pixel_size.width > 0.0 && pixel_size.height > 0.0 {
            layer.setDrawableSize(pixel_size);
        }
    }

    /// Encode and submit one clear-only frame. No shader or pipeline is needed:
    /// a render pass can clear its color attachment as a fixed-function step.
    pub(crate) fn render(&self) {
        let bounds = self.bounds();
        if bounds.size.width <= 0.0 || bounds.size.height <= 0.0 {
            return;
        }

        let layer = &self.ivars().metal_layer;
        let Some(drawable) = layer.nextDrawable() else {
            return;
        };
        let Some(command_buffer) = self.ivars().command_queue.commandBuffer() else {
            return;
        };

        let pass = MTLRenderPassDescriptor::new();
        // SAFETY: Attachment index 0 is always present on a render pass
        // descriptor; Metal defines a fixed set of color attachment slots.
        let attachment = unsafe { pass.colorAttachments().objectAtIndexedSubscript(0) };
        attachment.setTexture(Some(&drawable.texture()));
        attachment.setLoadAction(MTLLoadAction::Clear);
        attachment.setStoreAction(MTLStoreAction::Store);
        attachment.setClearColor(CLEAR_COLOR);

        let Some(encoder) = command_buffer.renderCommandEncoderWithDescriptor(&pass) else {
            return;
        };
        encoder.endEncoding();

        // Present after the GPU work is encoded. The command buffer schedules
        // the hand-off of the drawable to Core Animation.
        let drawable_mtl: &ProtocolObject<dyn MTLDrawable> = drawable.as_ref();
        command_buffer.presentDrawable(drawable_mtl);
        command_buffer.commit();
    }
}
