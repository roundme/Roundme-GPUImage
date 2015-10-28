#import "GPUImageOutput.h"
#import "GPUImageMovieWriter.h"
#import "GPUImagePicture.h"
#import <mach/mach.h>

void reportAvailableMemoryForGPUImage(NSString *tag) {
    if (!tag) {
        tag = @"Default";
    }
    struct task_basic_info info;
    mach_msg_type_number_t size = sizeof(info);
    kern_return_t kerr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &size);
    if( kerr == KERN_SUCCESS ) {
        NSLog(@"%@ - Memory used: %u", tag, (unsigned int)info.resident_size); //in bytes
    } else {        
        NSLog(@"%@ - Error: %s", tag, mach_error_string(kerr));        
    }    
}

@interface GPUImageOutput()

@property (nonatomic, strong) NSMutableArray *targets;
@property (nonatomic, strong) NSMutableArray *targetTextureIndices;

@property (nonatomic, assign) CGSize cachedMaximumOutputSize;

@end

@implementation GPUImageOutput

#pragma mark - Initialization and teardown

- (id)init {
	if ((self = [super init])) {
        self.targets = [NSMutableArray array];
        self.targetTextureIndices = [NSMutableArray array];

        self.usingNextFrameForImageCapture = NO;

        // set default texture options
        GPUTextureOptions options = {
            .minFilter = GL_LINEAR,
            .magFilter = GL_LINEAR,
            .wrapS = GL_CLAMP_TO_EDGE,
            .wrapT = GL_CLAMP_TO_EDGE,
            .internalFormat = GL_RGBA,
            .format = GL_BGRA,
            .type = GL_UNSIGNED_BYTE
        };
        self.outputTextureOptions = options;
    }
    return self;
}

- (void)dealloc {
    [self removeAllTargets];
}

#pragma mark - Looping targets

- (void)loopTargetsWithTargetAndTextureIndex:(void (^)(id<GPUImageInput> target, NSUInteger textureIndex))block {
    NSAssert(dispatch_get_specific([GPUImageContext contextKey]), @"loopTargetsWithTargetAndTextureIndex - not VideoProcessingQueue");
    for (id<GPUImageInput> currentTarget in self.targets) {
        if (currentTarget != self.targetToIgnoreForUpdates) {
            NSInteger textureIndex = [self getTargetTextureIndex:currentTarget];
            block(currentTarget, textureIndex);
        }
    }
}

#pragma mark - Managing the display FBOs

- (CGSize)outputFrameSize {
    NSAssert(NO, @"Must inherit");
    return CGSizeZero;
}

- (void)informTargetsAboutNewFrameAtTime:(CMTime)frameTime {
    if (self.frameProcessingCompletionBlock != NULL) {
        self.frameProcessingCompletionBlock(self, frameTime);
    }

    // Get all targets the framebuffer so they can grab a lock on it
    [self loopTargetsWithTargetAndTextureIndex:^(id<GPUImageInput> target, NSUInteger textureIndex) {
        [self setInputFramebufferForTarget:target atIndex:textureIndex];
        [target setInputSize:[self outputFrameSize] index:textureIndex];
    }];

    // Release our hold so it can return to the cache immediately upon processing
    [self.outputFramebuffer unlock];

    if (!self.usingNextFrameForImageCapture) {
        self.outputFramebuffer = nil;
    }

    // Trigger processing last, so that our unlock comes first in serial execution, avoiding the need for a callback
    [self loopTargetsWithTargetAndTextureIndex:^(id<GPUImageInput> target, NSUInteger textureIndex) {
        [target newFrameReadyAtTime:frameTime atIndex:textureIndex];
    }];
}

#pragma mark - Managing targets

- (NSInteger)getTargetTextureIndex:(id<GPUImageInput>)target {
    NSInteger indexOfObject = [self.targets indexOfObject:target];
    NSInteger textureIndex = [[self.targetTextureIndices objectAtIndex:indexOfObject] integerValue];
    return textureIndex;
}

- (void)setInputFramebufferForTarget:(id<GPUImageInput>)target atIndex:(NSUInteger)inputTextureIndex {
    if (self.outputFramebuffer) {
        [target setInputFramebuffer:self.outputFramebuffer index:inputTextureIndex];
    }
}

- (void)notifyTargetsAboutNewOutputTexture {
    [self loopTargetsWithTargetAndTextureIndex:^(id<GPUImageInput> target, NSUInteger textureIndex) {
        [self setInputFramebufferForTarget:target atIndex:textureIndex];
    }];
}

- (void)addTarget:(id<GPUImageInput>)newTarget {
    NSInteger nextAvailableTextureIndex = [newTarget nextAvailableTextureIndex];
    [self addTarget:newTarget atTextureLocation:nextAvailableTextureIndex];
}

- (void)addTarget:(id<GPUImageInput>)newTarget atTextureLocation:(NSInteger)textureLocation {
    runSynchronouslyOnVideoProcessingQueue(^{
        if(![self.targets containsObject:newTarget]) {
            self.cachedMaximumOutputSize = CGSizeZero;

            [self setInputFramebufferForTarget:newTarget atIndex:textureLocation];
            [self.targets addObject:newTarget];
            [self.targetTextureIndices addObject:@(textureLocation)];
        }
        if ([newTarget shouldIgnoreUpdatesToThisTarget]) {
            self.targetToIgnoreForUpdates = newTarget;
        }
    });
}

- (void)removeTarget:(id<GPUImageInput>)targetToRemove {
    runSynchronouslyOnVideoProcessingQueue(^{
        if([self.targets containsObject:targetToRemove]) {
            if (self.targetToIgnoreForUpdates == targetToRemove) {
                self.targetToIgnoreForUpdates = nil;
            }

            self.cachedMaximumOutputSize = CGSizeZero;

//            NSInteger textureIndex = [self getTargetTextureIndex:targetToRemove];
//            [targetToRemove setInputSize:CGSizeZero atIndex:textureIndex];
            [targetToRemove endProcessing];

            NSInteger indexOfObject = [self.targets indexOfObject:targetToRemove];
            [self.targetTextureIndices removeObjectAtIndex:indexOfObject];
            [self.targets removeObject:targetToRemove];
        }
    });
}

- (void)removeAllTargets {
    runSynchronouslyOnVideoProcessingQueue(^{
        while ([self.targets count]) {
            [self removeTarget:[self.targets firstObject]];
        }
    });
}

#pragma mark - Manage the output texture

- (void)forceProcessingAtSize:(CGSize)frameSize {
}

- (void)forceProcessingAtSizeRespectingAspectRatio:(CGSize)frameSize {
}

#pragma mark - Still image processing

- (void)useNextFrameForImageCapture {
}

- (CGImageRef)newCGImageFromCurrentlyProcessedOutput {
    return nil;
}

- (CGImageRef)newCGImageByFilteringCGImage:(CGImageRef)imageToFilter;
{
    GPUImagePicture *stillImageSource = [[GPUImagePicture alloc] initWithCGImage:imageToFilter];
    
    [self useNextFrameForImageCapture];
    [stillImageSource addTarget:(id<GPUImageInput>)self];
    [stillImageSource processImage];
    
    CGImageRef processedImage = [self newCGImageFromCurrentlyProcessedOutput];
    
    [stillImageSource removeTarget:(id<GPUImageInput>)self];
    return processedImage;
}

- (BOOL)providesMonochromeOutput;
{
    return NO;
}

#pragma mark -
#pragma mark Platform-specific image output methods

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE

- (UIImage *)imageFromCurrentFramebuffer {
	UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
    UIImageOrientation imageOrientation = UIImageOrientationLeft;
	switch (deviceOrientation) {
		case UIDeviceOrientationPortrait:
			imageOrientation = UIImageOrientationUp;
			break;
		case UIDeviceOrientationPortraitUpsideDown:
			imageOrientation = UIImageOrientationDown;
			break;
		case UIDeviceOrientationLandscapeLeft:
			imageOrientation = UIImageOrientationLeft;
			break;
		case UIDeviceOrientationLandscapeRight:
			imageOrientation = UIImageOrientationRight;
			break;
		default:
			imageOrientation = UIImageOrientationUp;
			break;
	}
    
    return [self imageFromCurrentFramebufferWithOrientation:imageOrientation];
}

- (UIImage *)imageFromCurrentFramebufferWithOrientation:(UIImageOrientation)imageOrientation;
{
    CGImageRef cgImageFromBytes = [self newCGImageFromCurrentlyProcessedOutput];
    UIImage *finalImage = [UIImage imageWithCGImage:cgImageFromBytes scale:1.0 orientation:imageOrientation];
    CGImageRelease(cgImageFromBytes);
    
    return finalImage;
}

- (UIImage *)imageByFilteringImage:(UIImage *)imageToFilter;
{
    CGImageRef image = [self newCGImageByFilteringCGImage:[imageToFilter CGImage]];
    UIImage *processedImage = [UIImage imageWithCGImage:image scale:[imageToFilter scale] orientation:[imageToFilter imageOrientation]];
    CGImageRelease(image);
    return processedImage;
}

- (CGImageRef)newCGImageByFilteringImage:(UIImage *)imageToFilter
{
    return [self newCGImageByFilteringCGImage:[imageToFilter CGImage]];
}

#else

- (NSImage *)imageFromCurrentFramebuffer;
{
    return [self imageFromCurrentFramebufferWithOrientation:UIImageOrientationLeft];
}

- (NSImage *)imageFromCurrentFramebufferWithOrientation:(UIImageOrientation)imageOrientation;
{
    CGImageRef cgImageFromBytes = [self newCGImageFromCurrentlyProcessedOutput];
    NSImage *finalImage = [[NSImage alloc] initWithCGImage:cgImageFromBytes size:NSZeroSize];
    CGImageRelease(cgImageFromBytes);
    
    return finalImage;
}

- (NSImage *)imageByFilteringImage:(NSImage *)imageToFilter;
{
    CGImageRef image = [self newCGImageByFilteringCGImage:[imageToFilter CGImageForProposedRect:NULL context:[NSGraphicsContext currentContext] hints:nil]];
    NSImage *processedImage = [[NSImage alloc] initWithCGImage:image size:NSZeroSize];
    CGImageRelease(image);
    return processedImage;
}

- (CGImageRef)newCGImageByFilteringImage:(NSImage *)imageToFilter
{
    return [self newCGImageByFilteringCGImage:[imageToFilter CGImageForProposedRect:NULL context:[NSGraphicsContext currentContext] hints:nil]];
}

#endif

#pragma mark - Accessors

- (void)setAudioEncodingTarget:(GPUImageMovieWriter *)newValue;
{    
    _audioEncodingTarget = newValue;
    if( ! _audioEncodingTarget.hasAudioTrack )
    {
        _audioEncodingTarget.hasAudioTrack = YES;
    }
}

@end
