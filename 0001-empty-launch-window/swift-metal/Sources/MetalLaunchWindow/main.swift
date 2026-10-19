import AppKit
import Metal
import QuartzCore

// MARK: - GPU-backed view

/// A layer-hosting view whose backing layer is a `CAMetalLayer`.
///
/// AppKit still owns the window and the event loop; only the pixels change hands.
/// Instead of AppKit asking the view to fill a CPU bitmap in `draw(_:)`, we ask
/// the layer for its next drawable texture and the GPU renders into it.
final class MetalView: NSView {
    private let commandQueue: MTLCommandQueue
    private let metalLayer: CAMetalLayer

    /// The color written by the GPU's clear operation. It is deliberately not
    /// black, so the Metal path is visibly distinct from the AppKit variant.
    private let clearColor = MTLClearColor(
        red: 0.04,
        green: 0.10,
        blue: 0.18,
        alpha: 1.0
    )

    init(frame frameRect: NSRect, device: MTLDevice, commandQueue: MTLCommandQueue) {
        self.commandQueue = commandQueue

        // A CAMetalLayer owns the pool of drawable textures that the window
        // server composites. It is the bridge between AppKit and Metal.
        let layer = CAMetalLayer()
        layer.device = device
        layer.pixelFormat = .bgra8Unorm // common 8-bit non-sRGB drawable format
        layer.framebufferOnly = true    // drawable textures are render targets only
        layer.isOpaque = true
        layer.maximumDrawableCount = 3  // pool size; a frame loop needs a semaphore
        self.metalLayer = layer

        super.init(frame: frameRect)

        // Layer-hosting: we supply the layer instead of letting AppKit create a
        // backing layer for us. Setting `wantsLayer` is what activates layout and
        // compositing through Core Animation.
        wantsLayer = true
        self.layer = layer

        updateDrawableSize()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateDrawableSize()
        render()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateDrawableSize()
        render()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateDrawableSize()
        render()
    }

    /// Drawable size is in *pixels*, not points. A Retina window needs twice the
    /// resolution, and moving the window between displays can change the scale.
    private func updateDrawableSize() {
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1
        metalLayer.contentsScale = scale

        let pixelSize = convertToBacking(bounds).size
        if pixelSize.width > 0, pixelSize.height > 0 {
            metalLayer.drawableSize = pixelSize
        }
    }

    /// Produces one frame and hands it to the window server.
    ///
    /// This is a complete Metal frame, minus any geometry: acquire a drawable,
    /// encode a render pass that clears it, present it, and submit the work.
    func render() {
        guard bounds.width > 0, bounds.height > 0,
              let drawable = metalLayer.nextDrawable(),
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }

        // A render pass describes which textures are written and how they are
        // initialized. Here the only attachment is the drawable's color texture.
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = drawable.texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = clearColor

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else {
            return
        }

        // No draw calls yet: clearing is the entire frame. The same encoder will
        // later carry pipeline state, vertex buffers, and draw commands.
        encoder.endEncoding()

        // Present after the GPU work is encoded. The command buffer schedules
        // the hand-off of the drawable to Core Animation.
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    override func keyDown(with event: NSEvent) {
        // Escape quits the app.
        if event.keyCode == 53 {
            NSApp.terminate(nil)
        } else {
            super.keyDown(with: event)
        }
    }
}

// MARK: - App lifecycle

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()

        // MTLCreateSystemDefaultDevice returns the GPU macOS wants the app to
        // use: the integrated GPU on Apple silicon, or the preferred GPU on an
        // Intel Mac with more than one.
        guard let device = MTLCreateSystemDefaultDevice() else {
            fail("No Metal device is available on this Mac.")
            return
        }

        // The queue serializes command buffers submitted to one device. Create
        // one per app (or per rendering context) and reuse it.
        guard let commandQueue = device.makeCommandQueue() else {
            fail("Could not create a Metal command queue.")
            return
        }

        let contentRect = NSRect(x: 0, y: 0, width: 1280, height: 720)
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Metal Game"
        window.contentMinSize = NSSize(width: 320, height: 180)

        let view = MetalView(
            frame: contentRect,
            device: device,
            commandQueue: commandQueue
        )
        window.contentView = view
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)
        view.render()

        self.window = window
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// A programmatic app has no menu bar by default, so ⌘Q would not be handled.
    /// Install the minimal application menu needed for the standard Quit item.
    @MainActor
    private func installMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        appMenuItem.title = ProcessInfo.processInfo.processName
        appMenu.addItem(quitItem)
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        NSApp.mainMenu = mainMenu
    }

    @MainActor
    private func fail(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Metal unavailable"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.runModal()
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
