#import "GPUImageRawDataInput.h"

@interface GPUImageRawDataInput()
- (void)uploadBytes:(GLubyte *)bytesToUpload;
@end

@implementation GPUImageRawDataInput

@synthesize pixelFormat = _pixelFormat;
@synthesize pixelType = _pixelType;

#pragma mark -
#pragma mark Initialization and teardown

- (id)initWithBytes:(GLubyte *)bytesToUpload size:(CGSize)imageSize;
{
    if (!(self = [self initWithBytes:bytesToUpload size:imageSize pixelFormat:GPUPixelFormatBGRA type:GPUPixelTypeUByte]))
    {
		return nil;
    }
	
	return self;
}

- (id)initWithBytes:(GLubyte *)bytesToUpload size:(CGSize)imageSize pixelFormat:(GPUPixelFormat)pixelFormat;
{
    if (!(self = [self initWithBytes:bytesToUpload size:imageSize pixelFormat:pixelFormat type:GPUPixelTypeUByte]))
    {
		return nil;
    }
	
	return self;
}

- (id)initWithBytes:(GLubyte *)bytesToUpload size:(CGSize)imageSize pixelFormat:(GPUPixelFormat)pixelFormat type:(GPUPixelType)pixelType;
{
    if (!(self = [super init]))
    {
		return nil;
    }
    
	dataUpdateSemaphore = dispatch_semaphore_create(1);

    uploadedImageSize = imageSize;
	self.pixelFormat = pixelFormat;
	self.pixelType = pixelType;
        
    [self uploadBytes:bytesToUpload];
    
    return self;
}

#pragma mark - Image rendering

- (void)uploadBytes:(GLubyte *)bytesToUpload {
    [GPUImageContext useImageProcessingContext];

    // TODO: This probably isn't right, and will need to be corrected
    self.outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:uploadedImageSize textureOptions:self.outputTextureOptions onlyTexture:YES];
    
    glBindTexture(GL_TEXTURE_2D, [self.outputFramebuffer texture]);
    glTexImage2D(GL_TEXTURE_2D, 0, _pixelFormat==GPUPixelFormatRGB ? GL_RGB : GL_RGBA, (int)uploadedImageSize.width, (int)uploadedImageSize.height, 0, (GLint)_pixelFormat, (GLenum)_pixelType, bytesToUpload);
}

- (void)updateDataFromBytes:(GLubyte *)bytesToUpload size:(CGSize)imageSize;
{
    uploadedImageSize = imageSize;

    [self uploadBytes:bytesToUpload];
}

- (void)processData {
    [self processDataForTimestamp:kCMTimeInvalid];
}

- (void)processDataForTimestamp:(CMTime)frameTime {
  if (dispatch_semaphore_wait(dataUpdateSemaphore, DISPATCH_TIME_NOW) == 0) {
    CGSize pixelSizeOfImage = [self outputImageSize];
    __weak typeof(self) weakSelf = self;
    runAsynchronouslyOnVideoProcessingQueue(^{
      __strong typeof(weakSelf) self = weakSelf;
      if (self) {
        [self loopTargetsWithTargetAndTextureIndex:^(id<GPUImageInput> target, NSUInteger textureIndex) {
          [target setInputSize:pixelSizeOfImage index:textureIndex];
          [target newFrameReadyAtTime:frameTime atIndex:textureIndex];
        }];
      }
      dispatch_semaphore_signal(dataUpdateSemaphore);
    });
  }
}

- (CGSize)outputImageSize {
    return uploadedImageSize;
}

@end
