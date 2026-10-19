#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#include <vector>

static constexpr unsigned short kEscapeKeyCode = 53;
static constexpr NSUInteger kMaxFramesInFlight = 3;

static const MTLClearColor kClearColor = {
    .red = 0.04,
    .green = 0.10,
    .blue = 0.18,
    .alpha = 1.0,
};

// The same shader source as ../shaders/triangle.metal. It lives here as a
// string so the pipeline setup and the shader can be read side by side. The
// Rust variant includes the identical file at compile time.
static NSString *const kShaderSource =
    @""
     "#include <metal_stdlib>\n"
     "using namespace metal;\n"
     "struct VertexOut { float4 position [[position]]; float4 color; };\n"
     "vertex VertexOut vertex_main(uint vertexID [[vertex_id]],\n"
     "                             constant float2 *positions [[buffer(0)]],\n"
     "                             constant float4 *colors [[buffer(1)]]) {\n"
     "    VertexOut out;\n"
     "    out.position = float4(positions[vertexID], 0.0, 1.0);\n"
     "    out.color = colors[vertexID];\n"
     "    return out;\n"
     "}\n"
     "fragment float4 fragment_main(VertexOut in [[stage_in]]) { return in.color; }\n";

/// Everything that persists across frames: device, queue, pipeline, and vertex
/// data. Built once because pipeline compilation is expensive.
@interface Renderer : NSObject {
    id<MTLDevice> _device;
    id<MTLCommandQueue> _queue;
    id<MTLRenderPipelineState> _pipeline;
    id<MTLBuffer> _positions;
    id<MTLBuffer> _colors;
    dispatch_semaphore_t _framesInFlight;
}

- (BOOL)prepare;
- (id<MTLDevice>)device;
- (void)drawInLayer:(CAMetalLayer *)layer;

@end

@implementation Renderer

- (BOOL)prepare {
    _device = MTLCreateSystemDefaultDevice();
    if (_device == nil) {
        NSLog(@"No Metal device is available on this Mac.");
        return NO;
    }
    _queue = [_device newCommandQueue];
    if (_queue == nil) {
        NSLog(@"Could not create a Metal command queue.");
        return NO;
    }

    // Shader compilation is a runtime call here. Production builds usually
    // precompile this file into a .metallib with the Metal toolchain.
    NSError *error = nil;
    id<MTLLibrary> library = [_device newLibraryWithSource:kShaderSource options:nil error:&error];
    if (library == nil) {
        NSLog(@"Shader compilation failed: %@", error);
        return NO;
    }
    id<MTLFunction> vertexFunction = [library newFunctionWithName:@"vertex_main"];
    id<MTLFunction> fragmentFunction = [library newFunctionWithName:@"fragment_main"];
    if (vertexFunction == nil || fragmentFunction == nil) {
        NSLog(@"Shader is missing vertex_main or fragment_main.");
        return NO;
    }

    MTLRenderPipelineDescriptor *descriptor = [MTLRenderPipelineDescriptor new];
    descriptor.vertexFunction = vertexFunction;
    descriptor.fragmentFunction = fragmentFunction;
    // The pipeline must declare the format of every attachment it writes, and
    // it must match the CAMetalLayer pixel format.
    descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;

    error = nil;
    _pipeline = [_device newRenderPipelineStateWithDescriptor:descriptor error:&error];
    if (_pipeline == nil) {
        NSLog(@"Pipeline creation failed: %@", error);
        return NO;
    }

    // Three vertices in counter-clockwise order. Positions are in clip space
    // (-1..1 on both axes); colors are RGBA and interpolated by the GPU.
    const float positions[] = {0.0f, 0.8f, -0.8f, -0.8f, 0.8f, -0.8f};
    const float colors[] = {
        1.0f, 0.2f, 0.3f, 1.0f, 0.2f, 1.0f, 0.3f, 1.0f, 0.3f, 0.4f, 1.0f, 1.0f,
    };
    _positions = [_device newBufferWithBytes:positions
                                      length:sizeof(positions)
                                     options:MTLResourceStorageModeShared];
    _colors = [_device newBufferWithBytes:colors
                                   length:sizeof(colors)
                                  options:MTLResourceStorageModeShared];
    if (_positions == nil || _colors == nil) {
        NSLog(@"Could not allocate vertex buffers.");
        return NO;
    }

    // Three slots, matching the drawable pool size.
    _framesInFlight = dispatch_semaphore_create((long)kMaxFramesInFlight);
    return YES;
}

- (id<MTLDevice>)device {
    return _device;
}

/// Acquire, record, present, submit. This is the complete GPU frame.
- (void)drawInLayer:(CAMetalLayer *)layer {
    // Wait for an in-flight slot. The GPU signals it when the command buffer
    // completes, not when the CPU returns from this call.
    dispatch_semaphore_wait(_framesInFlight, DISPATCH_TIME_FOREVER);

    id<CAMetalDrawable> drawable = [layer nextDrawable];
    id<MTLCommandBuffer> commandBuffer = [_queue commandBuffer];
    if (drawable == nil || commandBuffer == nil) {
        dispatch_semaphore_signal(_framesInFlight);
        return;
    }

    MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
    pass.colorAttachments[0].texture = drawable.texture;
    pass.colorAttachments[0].loadAction = MTLLoadActionClear;
    pass.colorAttachments[0].storeAction = MTLStoreActionStore;
    pass.colorAttachments[0].clearColor = kClearColor;

    id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:pass];
    if (encoder == nil) {
        dispatch_semaphore_signal(_framesInFlight);
        return;
    }
    [encoder setRenderPipelineState:_pipeline];
    // Indices 0 and 1 match the [[buffer(0)]] and [[buffer(1)]] attributes in
    // the shader. Offsets are zero because each buffer holds one array.
    [encoder setVertexBuffer:_positions offset:0 atIndex:0];
    [encoder setVertexBuffer:_colors offset:0 atIndex:1];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
    [encoder endEncoding];

    // Release the slot after the GPU finishes this frame, not after the CPU
    // finishes recording it.
    dispatch_semaphore_t semaphore = _framesInFlight;
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
        (void)buffer;
        dispatch_semaphore_signal(semaphore);
    }];

    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
}

@end

/// A layer-hosting view whose layer is a CAMetalLayer. The display link targets
/// this view, so the link retains it for as long as frames are driven.
@interface MetalView : NSView {
    CAMetalLayer *_metalLayer;
    Renderer *_renderer;
}

- (instancetype)initWithFrame:(NSRect)frameRect renderer:(Renderer *)renderer;
- (void)startFrameLoop;
- (void)updateDrawableSize;

@end

@interface MetalView ()

- (void)tick:(CADisplayLink *)displayLink;

@end

@implementation MetalView

- (instancetype)initWithFrame:(NSRect)frameRect renderer:(Renderer *)renderer {
    self = [super initWithFrame:frameRect];
    if (self == nil) {
        return nil;
    }
    _renderer = renderer;

    // The CAMetalLayer owns the drawable pool composited by the window server.
    _metalLayer = [CAMetalLayer layer];
    _metalLayer.device = [renderer device];
    _metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    _metalLayer.framebufferOnly = YES;
    _metalLayer.opaque = YES;
    _metalLayer.maximumDrawableCount = kMaxFramesInFlight;

    self.wantsLayer = YES;
    self.layer = _metalLayer;
    [self updateDrawableSize];
    return self;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    [self updateDrawableSize];
}

- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    [self updateDrawableSize];
}

- (void)viewDidChangeBackingProperties {
    [super viewDidChangeBackingProperties];
    [self updateDrawableSize];
}

/// Drawable size is in pixels, not points.
- (void)updateDrawableSize {
    CGFloat scale = self.window != nil ? self.window.backingScaleFactor : 1.0;
    _metalLayer.contentsScale = scale;
    NSSize pixelSize = [self convertRectToBacking:self.bounds].size;
    if (pixelSize.width > 0.0 && pixelSize.height > 0.0) {
        _metalLayer.drawableSize = pixelSize;
    }
}

/// One frame per display refresh. AppKit's NSView returns a display link
/// already synchronized to the screen this view is on.
- (void)startFrameLoop {
    CADisplayLink *link = [self displayLinkWithTarget:self selector:@selector(tick:)];
    [link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    // AppKit holds a weak reference to display links; keep it alive here.
    objc_setAssociatedObject(self, "triangle.displayLink", link, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // Draw one frame immediately so the window never flashes an empty surface.
    [_renderer drawInLayer:_metalLayer];
}

- (void)tick:(CADisplayLink *)displayLink {
    (void)displayLink;
    [_renderer drawInLayer:_metalLayer];
}

- (void)keyDown:(NSEvent *)event {
    if (event.keyCode == kEscapeKeyCode) {
        [NSApp terminate:nil];
        return;
    }
    [super keyDown:event];
}

@end

@interface AppDelegate : NSObject <NSApplicationDelegate>
@end

@interface AppDelegate () {
    NSWindow *_window;
}

- (void)installMainMenu;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    [self installMainMenu];

    Renderer *renderer = [[Renderer alloc] init];
    if (![renderer prepare]) {
        [NSApp terminate:nil];
        return;
    }

    NSRect contentRect = NSMakeRect(0.0, 0.0, 1280.0, 720.0);
    NSWindowStyleMask style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                              NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable;
    _window = [[NSWindow alloc] initWithContentRect:contentRect
                                          styleMask:style
                                            backing:NSBackingStoreBuffered
                                              defer:NO];
    _window.title = @"Triangle";
    _window.contentMinSize = NSMakeSize(320.0, 180.0);
    _window.backgroundColor = [NSColor blackColor];
    _window.releasedWhenClosed = NO;

    MetalView *view = [[MetalView alloc] initWithFrame:contentRect renderer:renderer];
    _window.contentView = view;
    [_window center];
    [_window makeKeyAndOrderFront:nil];
    [_window makeFirstResponder:view];
    [view startFrameLoop];

    [NSApp activate];
}

// A programmatic AppKit app has no menu bar, so install the standard Quit item
// that makes Command-Q work.
- (void)installMainMenu {
    NSMenu *mainMenu = [[NSMenu alloc] init];
    NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
    NSMenu *appMenu = [[NSMenu alloc] init];
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit"
                                                      action:@selector(terminate:)
                                               keyEquivalent:@"q"];
    appMenuItem.title = NSProcessInfo.processInfo.processName;
    [appMenu addItem:quitItem];
    appMenuItem.submenu = appMenu;
    [mainMenu addItem:appMenuItem];
    NSApp.mainMenu = mainMenu;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    (void)sender;
    return YES;
}

@end

int main(void) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        __attribute__((objc_precise_lifetime)) AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        [app run];
        (void)delegate;
    }
    return 0;
}
