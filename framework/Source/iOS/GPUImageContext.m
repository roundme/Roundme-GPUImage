#import "GPUImageContext.h"
#import <OpenGLES/EAGLDrawable.h>
#import <AVFoundation/AVFoundation.h>

void runSynchronouslyOnVideoProcessingQueue(void (^block)(void)) {
	if (dispatch_get_specific([GPUImageContext contextKey])) {
        block();
	} else {
		dispatch_sync([GPUImageContext sharedContextQueue], block);
	}
}

void runAsynchronouslyOnVideoProcessingQueue(void (^block)(void)) {
    if (dispatch_get_specific([GPUImageContext contextKey])) {
		block();
	} else {
        dispatch_async([GPUImageContext sharedContextQueue], block);
	}
}

@interface GPUImageContext()
{
    EAGLSharegroup *_sharegroup;
}

@property(nonatomic, readwrite, strong) EAGLContext *context;

@property(nonatomic) dispatch_queue_t contextQueue;

@property(nonatomic, readwrite) CVOpenGLESTextureCacheRef coreVideoTextureCache;
@property(nonatomic, readwrite, strong) GPUImageFramebufferCache *framebufferCache;

@property(nonatomic, readwrite, strong) GLProgram *currentShaderProgram;

@end

@implementation GPUImageContext

static void *openGLESContextQueueKey;

-(instancetype) initUniqueInstance {
    if ((self = [super init])) {
        openGLESContextQueueKey = &openGLESContextQueueKey;
        self.contextQueue = dispatch_queue_create("com.sunsetlakesoftware.GPUImage.openGLESContextQueue", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(self.contextQueue, openGLESContextQueueKey, (__bridge void *)self, NULL);
    }
    return self;
}

+ (void *)contextKey {
	return openGLESContextQueueKey;
}

// Based on Colin Wheeler's example here: http://cocoasamurai.blogspot.com/2011/04/singletons-your-doing-them-wrong.html
+ (GPUImageContext *)sharedImageProcessingContext {
    static dispatch_once_t pred;
    static GPUImageContext *sharedImageProcessingContext = nil;
    
    dispatch_once(&pred, ^{
        sharedImageProcessingContext = [[super alloc] initUniqueInstance];
    });
    return sharedImageProcessingContext;
}

+ (void)clearContext {
    NSAssert(dispatch_get_specific([GPUImageContext contextKey]), @"loopTargetsWithTargetAndTextureIndex - not VideoProcessingQueue");
    GPUImageContext *singleton = [GPUImageContext sharedImageProcessingContext];
    if (singleton) {
        [singleton setContextShaderProgram:nil];
        if (singleton.coreVideoTextureCache) {
            CFRelease(singleton.coreVideoTextureCache);
            singleton.coreVideoTextureCache = NULL;
        }
        [singleton.framebufferCache clear];
        singleton.framebufferCache = nil;
    }
}

+ (dispatch_queue_t)sharedContextQueue {
    return [[self sharedImageProcessingContext] contextQueue];
}

+ (void)useImageProcessingContext {
    [[GPUImageContext sharedImageProcessingContext] useAsCurrentContext];
}

- (void)useAsCurrentContext {
  EAGLContext *imageProcessingContext = self.context;
  if (![[EAGLContext currentContext] isEqual:imageProcessingContext]) {
    [EAGLContext setCurrentContext:imageProcessingContext];
  }
}

+ (void)setActiveShaderProgram:(GLProgram *)shaderProgram {
    GPUImageContext *sharedContext = [GPUImageContext sharedImageProcessingContext];
    [sharedContext setContextShaderProgram:shaderProgram];
}

- (void)setContextShaderProgram:(GLProgram *)shaderProgram {
    [self useAsCurrentContext];
    if (self.currentShaderProgram != shaderProgram) {
        self.currentShaderProgram = shaderProgram;
        if (shaderProgram) {
            [shaderProgram use];
        } else {
            glUseProgram(0);
        }
    }
}

+ (GLProgram *)getActiveShaderProgram {
    return [[GPUImageContext sharedImageProcessingContext] getContextShaderProgram];
}

- (GLProgram *)getContextShaderProgram {
    return self.currentShaderProgram;
}

+ (BOOL)deviceSupportsOpenGLESExtension:(NSString *)extension {
    static dispatch_once_t pred;
    static NSArray *extensionNames = nil;

    // Cache extensions for later quick reference, since this won't change for a given device
    dispatch_once(&pred, ^{
        [GPUImageContext useImageProcessingContext];
        NSString *extensionsString = [NSString stringWithCString:(const char *)glGetString(GL_EXTENSIONS) encoding:NSASCIIStringEncoding];
        extensionNames = [extensionsString componentsSeparatedByString:@" "];
    });

    return [extensionNames containsObject:extension];
}


// http://www.khronos.org/registry/gles/extensions/EXT/EXT_texture_rg.txt

+ (BOOL)deviceSupportsRedTextures {
    static dispatch_once_t pred;
    static BOOL supportsRedTextures = NO;
    
    dispatch_once(&pred, ^{
        supportsRedTextures = [GPUImageContext deviceSupportsOpenGLESExtension:@"GL_EXT_texture_rg"];
    });
    
    return supportsRedTextures;
}

+ (BOOL)deviceSupportsFramebufferReads {
    static dispatch_once_t pred;
    static BOOL supportsFramebufferReads = NO;
    
    dispatch_once(&pred, ^{
        supportsFramebufferReads = [GPUImageContext deviceSupportsOpenGLESExtension:@"GL_EXT_shader_framebuffer_fetch"];
    });
    
    return supportsFramebufferReads;
}

+ (CGSize)sizeThatFitsWithinATextureForSize:(CGSize)inputSize {
    [self useImageProcessingContext];
    __block GLint maxTextureSize = 0;
    runSynchronouslyOnVideoProcessingQueue(^{
        glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxTextureSize);
    });

    if ( (inputSize.width < maxTextureSize) && (inputSize.height < maxTextureSize) ) {
        return inputSize;
    }
    
    CGSize adjustedSize;
    if (inputSize.width > inputSize.height) {
        adjustedSize.width = (GLfloat)maxTextureSize;
        adjustedSize.height = ((GLfloat)maxTextureSize / inputSize.width) * inputSize.height;
    } else {
        adjustedSize.height = (GLfloat)maxTextureSize;
        adjustedSize.width = ((GLfloat)maxTextureSize / inputSize.height) * inputSize.width;
    }

    return adjustedSize;
}

- (void)presentBufferForDisplay {
    [self.context presentRenderbuffer:GL_RENDERBUFFER];
}

- (void)useSharegroup:(EAGLSharegroup *)sharegroup {
    NSAssert(_context == nil, @"Unable to use a share group when the context has already been created. Call this method before you use the context for the first time.");
    _sharegroup = sharegroup;
}

#pragma mark -
#pragma mark Manage fast texture upload

+ (BOOL)supportsFastTextureUpload;
{
#if TARGET_IPHONE_SIMULATOR
    return NO;
#else
    return (CVOpenGLESTextureCacheCreate != NULL);
#endif
}

#pragma mark - Accessors

- (EAGLContext *)context {
  if (!_context) {
    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3 sharegroup:_sharegroup];
    if (!_context) {
      _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2 sharegroup:_sharegroup];
    }
    NSAssert(_context, @"Unable to create an OpenGL ES 2.0 context. The GPUImage framework requires OpenGL ES 2.0 support to work.");
  }
  if (![[EAGLContext currentContext] isEqual:_context]) {
    [EAGLContext setCurrentContext:_context];
    // Set up a few global settings for the image processing pipeline
    glDisable(GL_DEPTH_TEST);
  }
  return _context;
}

- (CVOpenGLESTextureCacheRef)coreVideoTextureCache {
    if (!_coreVideoTextureCache ) {
        CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, [self context], NULL, &_coreVideoTextureCache);
        if (err != kCVReturnSuccess) {
            NSAssert(NO, @"Error at CVOpenGLESTextureCacheCreate %d", err);
        }
    }
    return _coreVideoTextureCache;
}

- (GPUImageFramebufferCache *)framebufferCache {
    if (_framebufferCache == nil) {
        _framebufferCache = [[GPUImageFramebufferCache alloc] init];
    }
    return _framebufferCache;
}

+ (GPUImageFramebufferCache *)sharedFramebufferCache {
    return [[self sharedImageProcessingContext] framebufferCache];
}

@end
