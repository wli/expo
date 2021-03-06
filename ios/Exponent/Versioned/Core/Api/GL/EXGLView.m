#import "EXGLView.h"

#include <OpenGLES/ES3/gl.h>
#include <OpenGLES/ES3/glext.h>
#import <ARKit/ARKit.h>

#import <React/RCTBridgeModule.h>
#import <React/RCTUtils.h>

#import "EXUnversioned.h"

#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define SHADER_STRING(text) @ STRINGIZE2(text)

#if __has_include("EXGLARSessionManager.h")
#import "EXGLARSessionManager.h"
#else
#import "EXGLARSessionManagerStub.h"
#endif

@interface EXGLView ()

@property (nonatomic, weak) EXGLViewManager *viewManager;

@property (nonatomic, assign) GLint layerWidth;
@property (nonatomic, assign) GLint layerHeight;
@property (nonatomic, assign) GLuint viewFramebuffer;
@property (nonatomic, assign) GLuint viewColorbuffer;
@property (nonatomic, assign) GLuint viewDepthStencilbuffer;
@property (nonatomic, assign) GLuint msaaFramebuffer;
@property (nonatomic, assign) GLuint msaaRenderbuffer;
@property (nonatomic, strong) dispatch_queue_t glQueue;

@property (nonatomic, strong) CADisplayLink *displayLink;

@property (nonatomic, assign) NSNumber *msaaSamples;
@property (nonatomic, assign) BOOL renderbufferPresented;
@property (nonatomic, assign) BOOL isInitializingContext;
@property (nonatomic, assign) CGSize viewBuffersSize;

@property (nonatomic, strong) id arSessionManager;

@end


@interface RCTBridge ()

- (JSGlobalContextRef)jsContextRef;
- (void)dispatchBlock:(dispatch_block_t)block queue:(dispatch_queue_t)queue;

@end

@implementation EXGLView

RCT_NOT_IMPLEMENTED(- (instancetype)init);

// Specify that we want this UIView to be backed by a CAEAGLLayer
+ (Class)layerClass {
  return [CAEAGLLayer class];
}

- (instancetype)initWithManager:(EXGLViewManager *)viewManager
{
  if ((self = [super init])) {
    _viewManager = viewManager;
    _glQueue = dispatch_queue_create("host.exp.gl", DISPATCH_QUEUE_SERIAL);
    _renderbufferPresented = YES;
    _isInitializingContext = NO;
    _viewBuffersSize = CGSizeZero;
    
    self.contentScaleFactor = RCTScreenScale();
    
    // Initialize properties of our backing CAEAGLLayer
    CAEAGLLayer *eaglLayer = (CAEAGLLayer *) self.layer;
    eaglLayer.opaque = YES;
    eaglLayer.drawableProperties = @{
                                     kEAGLDrawablePropertyRetainedBacking: @(YES),
                                     kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8,
                                     };
    
    // Initialize GL context, view buffers will be created on layout event
    _eaglCtx = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    _uiEaglCtx = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3 sharegroup:[_eaglCtx sharegroup]];
    _msaaFramebuffer = _msaaRenderbuffer = _viewFramebuffer = _viewColorbuffer = _viewDepthStencilbuffer = 0;
    
    // Set up a draw loop
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(draw)];
    //    _displayLink.preferredFramesPerSecond = 60;
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    
    // Will fill this in later from JS thread once `onSurfaceCreate` callback is set
    _exglCtxId = 0;
  }
  return self;
}

- (void)initEXGLContext
{
  RCTBridge *bridge = _viewManager.bridge;
  if (!bridge.executorClass || [NSStringFromClass(bridge.executorClass) isEqualToString:@"RCTJSCExecutor"]) {
    // On JS thread, extract JavaScriptCore context, create EXGL context, call JS callback
    __weak __typeof__(self) weakSelf = self;
    __weak __typeof__(bridge) weakBridge = bridge;
    _isInitializingContext = YES;
    
    [bridge dispatchBlock:^{
      __typeof__(self) self = weakSelf;
      __typeof__(bridge) bridge = weakBridge;
      if (!self || !bridge || !bridge.valid) {
        return;
      }
      
      JSGlobalContextRef jsContextRef = [bridge jsContextRef];
      if (!jsContextRef) {
        RCTLogError(@"EXGL: The React Native bridge unexpectedly does not have a JavaScriptCore context.");
        return;
      }
      
      _exglCtxId = UEXGLContextCreate(jsContextRef);
      UEXGLContextSetDefaultFramebuffer(_exglCtxId, _msaaFramebuffer);
      UEXGLContextSetFlushMethodObjc(_exglCtxId, ^{
        [self flush];
      });
      _onSurfaceCreate(@{ @"exglCtxId": @(_exglCtxId) });
      _isInitializingContext = NO;
    } queue:RCTJSThread];
  } else {
    RCTLog(@"EXGL: Can only run on JavaScriptCore! Do you have 'Remote Debugging' enabled in your app's Developer Menu (https://facebook.github.io/react-native/docs/debugging.html)? EXGL is not supported while using Remote Debugging, you will need to disable it to use EXGL.");
  }
}

- (void)layoutSubviews
{
  [self resizeViewBuffersToWidth:self.contentScaleFactor * self.frame.size.width
                          height:self.contentScaleFactor * self.frame.size.height];
  
  // Initialize EXGL context on the first layout
  // If we have already received onSurfaceCreate event block
  if (_onSurfaceCreate && _exglCtxId == 0 && !_isInitializingContext) {
    [self initEXGLContext];
  }
}

- (void)setOnSurfaceCreate:(RCTDirectEventBlock)onSurfaceCreate
{
  _onSurfaceCreate = onSurfaceCreate;
  
  if (_onSurfaceCreate && _msaaFramebuffer != 0) {
    // Got non-empty onSurfaceCreate callback
    // Set up JS binding, but only if the buffers are already created
    // Otherwise, we will set it up later on layoutSubviews call
    [self initEXGLContext];
  }
}

- (void)runInEAGLContext:(EAGLContext*)context callback:(void(^)(void))callback
{
  [EAGLContext setCurrentContext:context];
  callback();
  glFlush();
  [EAGLContext setCurrentContext:nil];
}

- (void)runOnGLThreadAsync:(void(^)(void))callback
{
  if (_glQueue) {
    dispatch_async(_glQueue, ^{
      [self runInEAGLContext:_eaglCtx callback:callback];
    });
  }
}

- (void)runOnUIThread:(void(^)(void))callback
{
  dispatch_sync(dispatch_get_main_queue(), ^{
    [self runInEAGLContext:_uiEaglCtx callback:callback];
  });
}

- (void)flush
{
  [self runOnGLThreadAsync:^{
    UEXGLContextFlush(_exglCtxId);
    
    // blit framebuffers if endFrameEXP was called
    if (UEXGLContextNeedsRedraw(_exglCtxId)) {
      // actually draw isn't yet finished, but it's here to prevent blitting the same thing multiple times
      UEXGLContextDrawEnded(_exglCtxId);
      
      [self blitFramebuffers];
    }
  }];
}

- (void)deleteViewBuffers
{
  if (_viewDepthStencilbuffer != 0) {
    glDeleteRenderbuffers(1, &_viewDepthStencilbuffer);
    _viewDepthStencilbuffer = 0;
  }
  if (_viewColorbuffer != 0) {
    glDeleteRenderbuffers(1, &_viewColorbuffer);
    _viewColorbuffer = 0;
  }
  if (_viewFramebuffer != 0) {
    glDeleteFramebuffers(1, &_viewFramebuffer);
    _viewFramebuffer = 0;
  }
  if (_msaaRenderbuffer != 0) {
    glDeleteRenderbuffers(1, &_msaaRenderbuffer);
    _msaaRenderbuffer = 0;
  }
  if (_msaaFramebuffer != 0) {
    glDeleteFramebuffers(1, &_msaaFramebuffer);
    _msaaFramebuffer = 0;
  }
}

- (void)resizeViewBuffersToWidth:(short)width height:(short)height
{
  CGSize newViewBuffersSize = CGSizeMake(width, height);
  
  // Don't resize if size hasn't changed and the current size is not zero
  if (CGSizeEqualToSize(newViewBuffersSize, _viewBuffersSize) && !CGSizeEqualToSize(_viewBuffersSize, CGSizeZero)) {
    return;
  }
  
  // update viewBuffersSize on UI thread (before actual resize takes place)
  // to get rid of redundant resizes if layoutSubviews is called multiple times with the same frame size
  _viewBuffersSize = newViewBuffersSize;
  
  [self runOnGLThreadAsync:^{
    // Save surrounding framebuffer/renderbuffer
    GLint prevFramebuffer;
    GLint prevRenderbuffer;
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &prevFramebuffer);
    glGetIntegerv(GL_RENDERBUFFER_BINDING, &prevRenderbuffer);
    if (prevFramebuffer == _viewFramebuffer) {
      prevFramebuffer = 0;
    }
    
    // Delete old buffers if they exist
    [self deleteViewBuffers];
    
    // Set up view framebuffer
    glGenFramebuffers(1, &_viewFramebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _viewFramebuffer);
    
    // Set up new color renderbuffer
    glGenRenderbuffers(1, &_viewColorbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _viewColorbuffer);
    
    [self runOnUIThread:^{
      glBindRenderbuffer(GL_RENDERBUFFER, _viewColorbuffer);
      [_uiEaglCtx renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];
    }];
    
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                              GL_RENDERBUFFER, _viewColorbuffer);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_layerWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_layerHeight);
    
    // Set up MSAA framebuffer/renderbuffer
    glGenFramebuffers(1, &_msaaFramebuffer);
    glGenRenderbuffers(1, &_msaaRenderbuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _msaaFramebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _msaaRenderbuffer);
    glRenderbufferStorageMultisample(GL_RENDERBUFFER, self.msaaSamples.intValue, GL_RGBA8,
                                     _layerWidth, _layerHeight);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                              GL_RENDERBUFFER, _msaaRenderbuffer);
    
    if (_exglCtxId) {
      UEXGLContextSetDefaultFramebuffer(_exglCtxId, _msaaFramebuffer);
    }
    
    // Set up new depth+stencil renderbuffer
    glGenRenderbuffers(1, &_viewDepthStencilbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _viewDepthStencilbuffer);
    glRenderbufferStorageMultisample(GL_RENDERBUFFER, self.msaaSamples.intValue, GL_DEPTH24_STENCIL8,
                                     _layerWidth, _layerHeight);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT,
                              GL_RENDERBUFFER, _viewDepthStencilbuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_STENCIL_ATTACHMENT,
                              GL_RENDERBUFFER, _viewDepthStencilbuffer);
    
    // Resize viewport
    glViewport(0, 0, width, height);
    
    // Restore surrounding framebuffer/renderbuffer
    if (prevFramebuffer != 0) {
      glBindFramebuffer(GL_FRAMEBUFFER, prevFramebuffer);
    }
    glBindRenderbuffer(GL_RENDERBUFFER, prevRenderbuffer);
    
    // TODO(nikki): Notify JS component of resize
  }];
}

// TODO(nikki): Should all this be done in `dealloc` instead?
- (void)removeFromSuperview
{
  __strong typeof(self) strongSelf = self;
  [self runOnGLThreadAsync:^{
    // Stop AR session if running
    [strongSelf maybeStopARSession];
    
    // flush all the stuff
    UEXGLContextFlush(_exglCtxId);
    
    // Destroy JS binding
    UEXGLContextDestroy(_exglCtxId);
    
    // Destroy GL objects owned by us
    [strongSelf deleteViewBuffers];
  }];
  
  // Stop draw loop
  [_displayLink invalidate];
  _displayLink = nil;
  
  [super removeFromSuperview];
}

- (void)draw
{
  // _exglCtxId may be unset if we get here (on the UI thread) before UEXGLContextCreate(...) is
  // called on the JS thread to create the EXGL context and save its id (see init method). In
  // this case no GL work has been sent yet so we skip this frame.
  //
  // _viewFramebuffer may be 0 if we haven't had a layout event yet and so the size of the
  // framebuffer to create is unknown. In this case we have nowhere to render to so we skip
  // this frame (the GL work to run remains on the queue for next time).
  
  if (_exglCtxId != 0 && _viewFramebuffer != 0) {
    // Update AR stuff if we have an AR session running
    if (_arSessionManager) {
      [_arSessionManager updateARCamTexture];
    }
    
    // Present current state of view buffers
    // This happens exactly at `gl.endFrameEXP()` in the queue
    if (_viewColorbuffer != 0 && !_renderbufferPresented) {
      // bind renderbuffer and present it on the layer
      [self runInEAGLContext:_uiEaglCtx callback:^{
        glBindRenderbuffer(GL_RENDERBUFFER, _viewColorbuffer);
        [_uiEaglCtx presentRenderbuffer:GL_RENDERBUFFER];
      }];
      
      // mark renderbuffer as presented
      _renderbufferPresented = YES;
    }
  }
}

// [GL thread] blits framebuffers and then sets a flag that informs UI thread
// about presenting the new content of the renderbuffer on the next draw call
- (void)blitFramebuffers
{
  if (_exglCtxId != 0 && _viewFramebuffer != 0 && _viewColorbuffer != 0) {
    // Save surrounding framebuffer
    GLint prevFramebuffer;
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &prevFramebuffer);
    if (prevFramebuffer == _viewFramebuffer) {
      prevFramebuffer = 0;
    }
    
    // Resolve multisampling and present
    glBindFramebuffer(GL_READ_FRAMEBUFFER, _msaaFramebuffer);
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, _viewFramebuffer);
    glBlitFramebuffer(0,0,_layerWidth,_layerHeight, 0,0,_layerWidth,_layerHeight, GL_COLOR_BUFFER_BIT, GL_NEAREST);
    
    // Restore surrounding framebuffer
    if (prevFramebuffer != 0) {
      glBindFramebuffer(GL_FRAMEBUFFER, prevFramebuffer);
    }
    
    // mark renderbuffer as not presented
    _renderbufferPresented = NO;
  }
}

#pragma mark - maybe AR

- (NSDictionary *)maybeStartARSession
{
  Class sessionManagerClass = NSClassFromString(@"EXGLARSessionManager");
  if (sessionManagerClass) {
    _arSessionManager = [[sessionManagerClass alloc] init];
  } else {
    return @{ @"error": @"AR capabilities were not included with this build." };
  }
  return [_arSessionManager startARSessionWithGLView:self];
}

- (void)maybeStopARSession
{
  if (_arSessionManager) {
    [_arSessionManager stopARSession];
    _arSessionManager = nil;
  }
}

- (NSDictionary *)arMatricesForViewportSize:(CGSize)viewportSize zNear:(CGFloat)zNear zFar:(CGFloat)zFar
{
  if (_arSessionManager) {
    return [_arSessionManager arMatricesForViewportSize:viewportSize zNear:zNear zFar:zFar];
  }
  return @{};
}

- (NSDictionary *)arLightEstimation
{
  if (_arSessionManager) {
    return [_arSessionManager arLightEstimation];
  }
  return @{};
}

- (NSDictionary *)rawFeaturePoints
{
  if (_arSessionManager) {
    return [_arSessionManager rawFeaturePoints];
  }
  return @{};
}

- (NSDictionary *)planes
{
  if (_arSessionManager) {
    return [_arSessionManager planes];
  }
  return @{};
}

- (void)setIsPlaneDetectionEnabled:(BOOL)planeDetectionEnabled
{
  if (_arSessionManager) {
    [_arSessionManager setIsPlaneDetectionEnabled:planeDetectionEnabled];
  }
}

- (void)setIsLightEstimationEnabled:(BOOL)lightEstimationEnabled
{
  if (_arSessionManager) {
    [_arSessionManager setIsLightEstimationEnabled:lightEstimationEnabled];
  }
}

- (void)setWorldAlignment:(NSInteger)worldAlignment
{
  if (_arSessionManager) {
    [_arSessionManager setWorldAlignment:worldAlignment];
  }
}

@end
