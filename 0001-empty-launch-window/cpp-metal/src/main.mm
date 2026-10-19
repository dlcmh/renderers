#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>

static constexpr unsigned short kEscapeKeyCode = 53;

static const MTLClearColor kClearColor = {
    .red = 0.04,
    .green = 0.10,
    .blue = 0.18,
    .alpha = 1.0,
};

/// A layer-hosting view whose layer is a CAMetalLayer. AppKit owns the window
/// and event loop; Metal owns the drawable and the clear pass.
@interface MetalView : NSView {
    id<MTLCommandQueue> _commandQueue;
    CAMetalLayer *_metalLayer;
}

- (instancetype)initWithFrame:(NSRect)frameRect
                       device:(id<MTLDevice>)device
                 commandQueue:(id<MTLCommandQueue>)commandQueue;
- (void)render;

@end

@interface MetalView ()

- (void)updateDrawableSize;

@end

@implementation MetalView

- (instancetype)initWithFrame:(NSRect)frameRect
                       device:(id<MTLDevice>)device
                 commandQueue:(id<MTLCommandQueue>)commandQueue {
    self = [super initWithFrame:frameRect];
    if (self == nil) {
        return nil;
    }

    _commandQueue = commandQueue;
    _metalLayer = [CAMetalLayer layer];
    _metalLayer.device = device;
    _metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    _metalLayer.framebufferOnly = YES;
    _metalLayer.opaque = YES;
    _metalLayer.maximumDrawableCount = 3;

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
    [self render];
}

- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    [self updateDrawableSize];
    [self render];
}

- (void)viewDidChangeBackingProperties {
    [super viewDidChangeBackingProperties];
    [self updateDrawableSize];
    [self render];
}

/// Drawable size is in pixels, not points. A Retina window needs twice the
/// resolution, and moving between displays can change the scale.
- (void)updateDrawableSize {
    CGFloat scale = self.window != nil ? self.window.backingScaleFactor : 1.0;
    _metalLayer.contentsScale = scale;

    NSSize pixelSize = [self convertRectToBacking:self.bounds].size;
    if (pixelSize.width > 0.0 && pixelSize.height > 0.0) {
        _metalLayer.drawableSize = pixelSize;
    }
}

- (void)render {
    NSSize size = self.bounds.size;
    if (size.width <= 0.0 || size.height <= 0.0) {
        return;
    }

    id<CAMetalDrawable> drawable = [_metalLayer nextDrawable];
    if (drawable == nil) {
        return;
    }

    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    if (commandBuffer == nil) {
        return;
    }

    MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
    pass.colorAttachments[0].texture = drawable.texture;
    pass.colorAttachments[0].loadAction = MTLLoadActionClear;
    pass.colorAttachments[0].storeAction = MTLStoreActionStore;
    pass.colorAttachments[0].clearColor = kClearColor;

    id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:pass];
    if (encoder == nil) {
        return;
    }
    [encoder endEncoding];

    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
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

    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (device == nil) {
        NSLog(@"No Metal device is available on this Mac.");
        [NSApp terminate:nil];
        return;
    }

    id<MTLCommandQueue> commandQueue = [device newCommandQueue];
    if (commandQueue == nil) {
        NSLog(@"Could not create a Metal command queue.");
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
    _window.title = @"Metal Game";
    _window.contentMinSize = NSMakeSize(320.0, 180.0);
    _window.backgroundColor = [NSColor blackColor];

    // We own the window from C++; AppKit must not release it when it closes.
    _window.releasedWhenClosed = NO;

    MetalView *view = [[MetalView alloc] initWithFrame:contentRect
                                                device:device
                                          commandQueue:commandQueue];
    _window.contentView = view;
    [_window center];
    [_window makeKeyAndOrderFront:nil];
    [_window makeFirstResponder:view];
    [view render];

    [NSApp activate];
}

// A programmatic AppKit app starts with no menu bar. Without the Quit item,
// Command-Q is never registered as a key equivalent.
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
        // Keep the delegate alive for the whole run loop. NSApplication's
        // delegate property is weak.
        (void)delegate;
    }
    return 0;
}
