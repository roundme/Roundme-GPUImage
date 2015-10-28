#import "GPUImageTextureInput.h"

@implementation GPUImageTextureInput

#pragma mark - Initialization and teardown

- (id)initWithTexture:(GLuint)newInputTexture size:(CGSize)newTextureSize {
    if ((self = [super init])) {
        runSynchronouslyOnVideoProcessingQueue(^{
            [GPUImageContext useImageProcessingContext];
            textureSize = newTextureSize;
            self.outputFramebuffer = [[GPUImageFramebuffer alloc] initWithSize:newTextureSize overriddenTexture:newInputTexture];
        });
    }
    return self;
}

#pragma mark - Image rendering

- (void)processTextureWithFrameTime:(CMTime)frameTime {
  __weak typeof(self) weakSelf = self;
  runAsynchronouslyOnVideoProcessingQueue(^{
    __strong typeof(weakSelf) self = weakSelf;
    if (self) {
      [self loopTargetsWithTargetAndTextureIndex:^(id<GPUImageInput> target, NSUInteger textureIndex) {
        [target setInputSize:textureSize index:textureIndex];
        [target setInputFramebuffer:self.outputFramebuffer index:textureIndex];
        [target newFrameReadyAtTime:frameTime atIndex:textureIndex];
      }];
    }
  });
}

@end
