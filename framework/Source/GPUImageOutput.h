#import "GPUImageContext.h"
#import "GPUImageFramebuffer.h"

#import <UIKit/UIKit.h>

void reportAvailableMemoryForGPUImage(NSString *tag);

@class GPUImageMovieWriter;

/** GPUImage's base source object
 
 Images or frames of video are uploaded from source objects, which are subclasses of GPUImageOutput. These include:
 
 - GPUImageVideoCamera (for live video from an iOS camera) 
 - GPUImageStillCamera (for taking photos with the camera)
 - GPUImagePicture (for still images)
 - GPUImageMovie (for movies)
 
 Source objects upload still image frames to OpenGL ES as textures, then hand those textures off to the next objects in the processing chain.
 */
@interface GPUImageOutput : NSObject

@property (nonatomic, strong) GPUImageFramebuffer *outputFramebuffer;
@property (nonatomic, strong) GPUImageMovieWriter *audioEncodingTarget;
@property (nonatomic, weak) id<GPUImageInput> targetToIgnoreForUpdates;
@property (nonatomic, copy) void(^frameProcessingCompletionBlock)(GPUImageOutput*, CMTime);
@property (nonatomic, assign) GPUTextureOptions outputTextureOptions;
@property (nonatomic, assign) BOOL shouldSmoothlyScaleOutput;
@property (nonatomic, assign) BOOL shouldIgnoreUpdatesToThisTarget;
@property (nonatomic, assign) BOOL usingNextFrameForImageCapture;

#pragma mark - Looping targets

- (void)loopTargetsWithTargetAndTextureIndex:(void (^)(id<GPUImageInput> target, NSUInteger textureIndex))block;

#pragma mark - Managing targets

- (void)setInputFramebufferForTarget:(id<GPUImageInput>)target atIndex:(NSUInteger)inputTextureIndex;
//- (GPUImageFramebuffer *)framebufferForOutput;
//- (void)removeOutputFramebuffer;
- (void)notifyTargetsAboutNewOutputTexture;

/** Returns an array of the current targets.
 */
//- (NSArray*)targets;

/** Adds a target to receive notifications when new frames are available.
 
 The target will be asked for its next available texture.
 
 See [GPUImageInput newFrameReadyAtTime:]
 
 @param newTarget Target to be added
 */
- (void)addTarget:(id<GPUImageInput>)newTarget;

/** Adds a target to receive notifications when new frames are available.
 
 See [GPUImageInput newFrameReadyAtTime:]
 
 @param newTarget Target to be added
 */
- (void)addTarget:(id<GPUImageInput>)newTarget atTextureLocation:(NSInteger)textureLocation;

/** Removes a target. The target will no longer receive notifications when new frames are available.
 
 @param targetToRemove Target to be removed
 */
- (void)removeTarget:(id<GPUImageInput>)targetToRemove;

/** Removes all targets.
 */
- (void)removeAllTargets;

/// @name Manage the output texture

- (void)informTargetsAboutNewFrameAtTime:(CMTime)frameTime;

- (void)forceProcessingAtSize:(CGSize)frameSize;
- (void)forceProcessingAtSizeRespectingAspectRatio:(CGSize)frameSize;

/// @name Still image processing

- (void)useNextFrameForImageCapture;
- (CGImageRef)newCGImageFromCurrentlyProcessedOutput;
- (CGImageRef)newCGImageByFilteringCGImage:(CGImageRef)imageToFilter;

// Platform-specific image output methods
// If you're trying to use these methods, remember that you need to set -useNextFrameForImageCapture before running -processImage or running video and calling any of these methods, or you will get a nil image
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
- (UIImage *)imageFromCurrentFramebuffer;
- (UIImage *)imageFromCurrentFramebufferWithOrientation:(UIImageOrientation)imageOrientation;
- (UIImage *)imageByFilteringImage:(UIImage *)imageToFilter;
- (CGImageRef)newCGImageByFilteringImage:(UIImage *)imageToFilter;
#else
- (NSImage *)imageFromCurrentFramebuffer;
- (NSImage *)imageFromCurrentFramebufferWithOrientation:(UIImageOrientation)imageOrientation;
- (NSImage *)imageByFilteringImage:(NSImage *)imageToFilter;
- (CGImageRef)newCGImageByFilteringImage:(NSImage *)imageToFilter;
#endif

- (BOOL)providesMonochromeOutput;

@end
