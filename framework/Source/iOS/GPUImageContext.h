#import "GLProgram.h"
#import "GPUImageFramebuffer.h"
#import "GPUImageFramebufferCache.h"

@interface GPUImageContext : NSObject

@property(nonatomic, readonly, strong) EAGLContext *context;

@property(nonatomic, readonly) CVOpenGLESTextureCacheRef coreVideoTextureCache;
@property(nonatomic, readonly) GPUImageFramebufferCache *framebufferCache;

+ (void *)contextKey;
+ (GPUImageContext *)sharedImageProcessingContext;
+ (void)clearContext;
+ (dispatch_queue_t)sharedContextQueue;
+ (GPUImageFramebufferCache *)sharedFramebufferCache;
+ (void)useImageProcessingContext;
- (void)useAsCurrentContext;
+ (void)setActiveShaderProgram:(GLProgram *)shaderProgram;
- (void)setContextShaderProgram:(GLProgram *)shaderProgram;
+ (GLProgram *)getActiveShaderProgram;
- (GLProgram *)getContextShaderProgram;
+ (BOOL)deviceSupportsOpenGLESExtension:(NSString *)extension;
+ (BOOL)deviceSupportsRedTextures;
+ (BOOL)deviceSupportsFramebufferReads;
+ (CGSize)sizeThatFitsWithinATextureForSize:(CGSize)inputSize;

- (void)presentBufferForDisplay;

- (void)useSharegroup:(EAGLSharegroup *)sharegroup;

// Manage fast texture upload
+ (BOOL)supportsFastTextureUpload;

+(instancetype) alloc __attribute__((unavailable("alloc not available, call sharedImageProcessingContext instead")));
-(instancetype) init __attribute__((unavailable("init not available, call sharedImageProcessingContext instead")));
+(instancetype) new __attribute__((unavailable("new not available, call sharedImageProcessingContext instead")));

@end

@protocol GPUImageInput <NSObject>
- (void)newFrameReadyAtTime:(CMTime)frameTime atIndex:(NSInteger)textureIndex;
- (void)setInputFramebuffer:(GPUImageFramebuffer *)value index:(NSUInteger)index;
- (NSInteger)nextAvailableTextureIndex;

- (void)setInputSize:(CGSize)value index:(NSUInteger)index;
- (void)setInputRotation:(GPUImageRotationMode)value index:(NSUInteger)index;

- (void)endProcessing;
- (BOOL)shouldIgnoreUpdatesToThisTarget;
@end

void runSynchronouslyOnVideoProcessingQueue(void (^block)(void));
void runAsynchronouslyOnVideoProcessingQueue(void (^block)(void));
