use objc2::rc::Retained;
use objc2::runtime::ProtocolObject;
use objc2::{DefinedClass, MainThreadMarker, MainThreadOnly, define_class, msg_send};
use objc2_app_kit::{NSApplication, NSEvent, NSView};
use objc2_foundation::{NSObject, NSObjectProtocol, NSRect, NSSize};
use objc2_metal::MTLDevice;
use objc2_quartz_core::{CADisplayLink, CAMetalLayer};

use crate::renderer::renderer;

/// The display link target. It keeps only the layer; the renderer is created
/// once at startup and shared through a process-wide cell.
struct TickIvars {
    layer: Retained<CAMetalLayer>,
    /// The display link. AppKit retains its target and only weakly retains the
    /// link itself, so the view keeps a strong reference and invalidates it when
    /// it is dropped.
    link: std::cell::OnceCell<Retained<CADisplayLink>>,
}

define_class!(
    // SAFETY: NSObject is a normal root class; the ivars own the layer.
    #[unsafe(super(NSObject))]
    #[thread_kind = MainThreadOnly]
    #[ivars = TickIvars]
    struct TickTarget;

    // SAFETY: NSObjectProtocol has no safety requirements.
    unsafe impl NSObjectProtocol for TickTarget {}

    impl TickTarget {
        #[unsafe(method(tick:))]
        fn tick(&self, _display_link: &CADisplayLink) {
            if let Some(renderer) = renderer() {
                renderer.draw(&self.ivars().layer);
            }
        }
    }
);

impl TickTarget {
    fn new(mtm: MainThreadMarker, layer: Retained<CAMetalLayer>) -> Retained<Self> {
        let this = Self::alloc(mtm).set_ivars(TickIvars {
            layer,
            link: std::cell::OnceCell::new(),
        });
        // SAFETY: `init` is NSObject's designated initializer.
        unsafe { msg_send![super(this), init] }
    }
}

/// A layer-hosting view whose layer is a CAMetalLayer. The view owns the layer,
/// the tick target, and the display link, so they live exactly as long as it.
pub(crate) struct LayerViewIvars {
    layer: Retained<CAMetalLayer>,
    /// Kept alive for the lifetime of the view; the display link retains it and
    /// the view must outlive the link's target.
    #[allow(dead_code)]
    target: Retained<TickTarget>,
}

define_class!(
    // SAFETY: NSView has no subclassing requirements, and the ivars own every
    // object used by the view.
    #[unsafe(super(NSView))]
    #[thread_kind = MainThreadOnly]
    #[ivars = LayerViewIvars]
    pub(crate) struct LayerView;

    // SAFETY: NSObjectProtocol has no safety requirements.
    unsafe impl NSObjectProtocol for LayerView {}

    impl LayerView {
        /// AppKit calls this when the view is resized. The drawable must match
        /// the new size in pixels.
        #[unsafe(method(setFrameSize:))]
        fn set_frame_size(&self, new_size: NSSize) {
            // SAFETY: `setFrameSize:` is NSView's designated geometry setter.
            let _: () = unsafe { msg_send![super(self), setFrameSize: new_size] };
            self.update_drawable_size();
        }

        #[unsafe(method(viewDidMoveToWindow))]
        fn view_did_move_to_window(&self) {
            // SAFETY: We call the superclass implementation on the main thread.
            let _: () = unsafe { msg_send![super(self), viewDidMoveToWindow] };
            self.update_drawable_size();
        }

        #[unsafe(method(viewDidChangeBackingProperties))]
        fn view_did_change_backing_properties(&self) {
            // SAFETY: We call the superclass implementation on the main thread.
            let _: () = unsafe { msg_send![super(self), viewDidChangeBackingProperties] };
            self.update_drawable_size();
        }

        #[unsafe(method(acceptsFirstResponder))]
        fn accepts_first_responder(&self) -> bool {
            true
        }

        #[unsafe(method(keyDown:))]
        fn key_down(&self, event: &NSEvent) {
            // Escape quits, matching the rest of the repository.
            if event.keyCode() == 53 {
                NSApplication::sharedApplication(self.mtm()).terminate(None);
            }
        }
    }
);

impl LayerView {
    pub(crate) fn new(
        mtm: MainThreadMarker,
        frame: NSRect,
        device: &ProtocolObject<dyn MTLDevice>,
        pixel_format: objc2_metal::MTLPixelFormat,
    ) -> Option<Retained<Self>> {
        // The CAMetalLayer owns the drawable pool composited by the window
        // server. Three drawables match the renderer's in-flight limit.
        let layer = CAMetalLayer::new();
        layer.setDevice(Some(device));
        layer.setPixelFormat(pixel_format);
        layer.setFramebufferOnly(true);
        layer.setOpaque(true);
        layer.setMaximumDrawableCount(3);

        let target = TickTarget::new(mtm, layer.clone());
        let view = Self::alloc(mtm).set_ivars(LayerViewIvars {
            layer: layer.clone(),
            target: target.clone(),
        });
        // SAFETY: `initWithFrame:` is NSView's designated initializer.
        let view: Retained<Self> = unsafe { msg_send![super(view), initWithFrame: frame] };

        view.setWantsLayer(true);
        view.setLayer(Some(&layer));
        view.update_drawable_size();

        // SAFETY: The target is a live Objective-C object implementing `tick:`.
        let any: &objc2::runtime::AnyObject =
            unsafe { &*(Retained::as_ptr(&target) as *const objc2::runtime::AnyObject) };
        // SAFETY: `any` points to a live TickTarget that implements `tick:`,
        // and the view was created on the main thread.
        let link = unsafe { view.displayLinkWithTarget_selector(any, objc2::sel!(tick:)) };
        // SAFETY: `addToRunLoop:forMode:` is called on the main thread.
        unsafe {
            link.addToRunLoop_forMode(
                &objc2_foundation::NSRunLoop::mainRunLoop(),
                objc2_foundation::NSRunLoopCommonModes,
            );
        }
        // AppKit holds a weak reference to display links, so the tick target
        // keeps the link alive until the view is released.
        let _ = target.ivars().link.set(link);

        // Draw one frame before the display link fires.
        if let Some(renderer) = renderer() {
            renderer.draw(&layer);
        }

        Some(view)
    }

    fn update_drawable_size(&self) {
        let scale = self
            .window()
            .map_or(1.0, |window| window.backingScaleFactor());
        self.ivars().layer.setContentsScale(scale);
        let pixel_size = self.convertRectToBacking(self.bounds()).size;
        if pixel_size.width > 0.0 && pixel_size.height > 0.0 {
            self.ivars().layer.setDrawableSize(pixel_size);
        }
    }
}
