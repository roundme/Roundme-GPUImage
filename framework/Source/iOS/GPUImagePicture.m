#import "GPUImagePicture.h"

@interface GPUImagePicture()

@property (nonatomic, assign) GLenum format;

@property (nonatomic, assign) CGSize pixelSizeOfImage;
@property (nonatomic, assign) CGSize pixelSizeToUseForTexture;

@end

@implementation GPUImagePicture

#pragma mark - Initialization and teardown

- (id)initWithURL:(NSURL *)url {
    self = [self initWithData:[[NSData alloc] initWithContentsOfURL:url]];
    return self;
}

- (id)initWithData:(NSData *)imageData {
    self = [self initWithImage:[[UIImage alloc] initWithData:imageData]];
    return self;
}

- (id)initWithImage:(UIImage *)newImageSource {
    self = [self initWithImage:newImageSource smoothlyScaleOutput:NO];
    return self;
}

- (id)initWithCGImage:(CGImageRef)newImageSource {
    self = [self initWithCGImage:newImageSource smoothlyScaleOutput:NO];
    return self;
}

- (id)initWithImage:(UIImage *)newImageSource smoothlyScaleOutput:(BOOL)smoothlyScaleOutput {
    return [self initWithCGImage:[newImageSource CGImage] smoothlyScaleOutput:smoothlyScaleOutput];
}

- (id)initWithCGImage:(CGImageRef)newImageSource smoothlyScaleOutput:(BOOL)smoothlyScaleOutput {
    if ((self = [super init])) {
        [self createFromCGImage:newImageSource smoothlyScaleOutput:smoothlyScaleOutput];
    }
    return self;
}

- (void)createFromCGImage:(CGImageRef)newImageSource smoothlyScaleOutput:(BOOL)smoothlyScaleOutput {
    self.shouldSmoothlyScaleOutput = smoothlyScaleOutput;
    imageUpdateSemaphore = dispatch_semaphore_create(0);

    // TODO: Dispatch this whole thing asynchronously to move image loading off main thread
    GLfloat widthOfImage = CGImageGetWidth(newImageSource);
    GLfloat heightOfImage = CGImageGetHeight(newImageSource);

    // If passed an empty image reference, CGContextDrawImage will fail in future versions of the SDK.
    NSAssert( widthOfImage > 0 && heightOfImage > 0, @"Passed image must not be empty - it should be at least 1px tall and wide");

    self.pixelSizeOfImage = CGSizeMake(widthOfImage, heightOfImage);
    self.pixelSizeToUseForTexture = self.pixelSizeOfImage;

    self.format = GL_BGRA;

    CGColorSpaceRef genericRGBColorspace = CGColorSpaceCreateDeviceRGB();

    CGContextRef imageContext = CGBitmapContextCreate(NULL, (size_t)self.pixelSizeToUseForTexture.width, (size_t)self.pixelSizeToUseForTexture.height, 8, (size_t)self.pixelSizeToUseForTexture.width * 4, genericRGBColorspace,  kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGContextDrawImage(imageContext, CGRectMake(0.0, 0.0, self.pixelSizeToUseForTexture.width, self.pixelSizeToUseForTexture.height), newImageSource);

    GLubyte *imageData = (GLubyte *)CGBitmapContextGetData(imageContext);
    [self bindTexture:imageData];

    CGContextRelease(imageContext);
    CGColorSpaceRelease(genericRGBColorspace);

    dispatch_semaphore_signal(imageUpdateSemaphore);
}

- (void)bindTexture:(GLubyte *)imageData {
    runSynchronouslyOnVideoProcessingQueue(^{
        [GPUImageContext useImageProcessingContext];

        self.outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:self.pixelSizeToUseForTexture onlyTexture:YES];
        [self.outputFramebuffer disableReferenceCounting];

        glBindTexture(GL_TEXTURE_2D, [self.outputFramebuffer texture]);
        if (self.shouldSmoothlyScaleOutput) {
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
        }
        // no need to use self.outputTextureOptions here since pictures need this texture formats and type
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (int)self.pixelSizeToUseForTexture.width, (int)self.pixelSizeToUseForTexture.height, 0, self.format, GL_UNSIGNED_BYTE, imageData);

        if (self.shouldSmoothlyScaleOutput) {
            glGenerateMipmap(GL_TEXTURE_2D);
        }
        glBindTexture(GL_TEXTURE_2D, 0);
    });
}

- (void)dealloc {
    [[GPUImageContext sharedFramebufferCache] returnFramebufferToCache:self.outputFramebuffer];
}

#pragma mark - Image rendering

- (void)process {
    [self loopTargetsWithTargetAndTextureIndex:^(id<GPUImageInput> target, NSUInteger textureIndex) {
        [target setInputSize:self.pixelSizeOfImage index:textureIndex];
        [target setInputFramebuffer:self.outputFramebuffer index:textureIndex];
        [target newFrameReadyAtTime:kCMTimeIndefinite atIndex:textureIndex];
    }];

    dispatch_semaphore_signal(imageUpdateSemaphore);
}

- (void)processImage {
    [self processImageWithCompletionHandler:nil];
}

- (void)processImageSync {
    if (dispatch_semaphore_wait(imageUpdateSemaphore, DISPATCH_TIME_NOW) == 0) {
        runSynchronouslyOnVideoProcessingQueue(^{
            [self process];
        });
    }
}

- (void)processImageWithCompletionHandler:(void (^)(void))completion {
  if (dispatch_semaphore_wait(imageUpdateSemaphore, DISPATCH_TIME_NOW) == 0) {
    __weak typeof(self) weakSelf = self;
    runAsynchronouslyOnVideoProcessingQueue(^{
      __strong typeof(weakSelf) self = weakSelf;
      if (self) {
        [self process];
        if (completion) {
          completion();
        }
      }
    });
  }
}

- (void)processImageUpToFilter:(GPUImageOutput<GPUImageInput> *)finalFilterInChain withCompletionHandler:(void (^)(UIImage *processedImage))block {
    [finalFilterInChain useNextFrameForImageCapture];
    [self processImageWithCompletionHandler:^{
        UIImage *imageFromFilter = [finalFilterInChain imageFromCurrentFramebuffer];
        block(imageFromFilter);
    }];
}

- (CGSize)outputImageSize {
    return self.pixelSizeOfImage;
}

- (void)addTarget:(id<GPUImageInput>)newTarget atTextureLocation:(NSInteger)textureLocation {
    [super addTarget:newTarget atTextureLocation:textureLocation];

    [newTarget setInputSize:self.pixelSizeOfImage index:textureLocation];
    [newTarget newFrameReadyAtTime:kCMTimeIndefinite atIndex:textureLocation];
}

@end
