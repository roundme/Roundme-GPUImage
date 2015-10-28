#import "GPUImageFramebufferCache.h"
#import "GPUImageContext.h"
#import "GPUImageOutput.h"

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#endif

@interface GPUImageFramebufferCache()

@property (nonatomic, strong) id memoryWarningObserver;

@property (nonatomic, strong) NSMutableDictionary *framebufferCache;
@property (nonatomic, strong) NSMutableDictionary *framebufferTypeCounts;
@property (nonatomic, strong) NSMutableArray *activeImageCaptureList; // Where framebuffers that may be lost by a filter, but which are still needed for a UIImage, etc., are stored

@end


@implementation GPUImageFramebufferCache

#pragma mark -
#pragma mark Initialization and teardown

- (id)init {
  if ((self = [super init])) {
    self.memoryWarningObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidReceiveMemoryWarningNotification object:nil queue:nil usingBlock:^(NSNotification *note) {

      [self purgeAllUnassignedFramebuffers];
    }];

    self.framebufferCache = [NSMutableDictionary dictionary];
    self.framebufferTypeCounts = [NSMutableDictionary dictionary];
    self.activeImageCaptureList = [NSMutableArray array];
  }
  return self;
}

- (void)dealloc {
  [self purgeAllUnassignedFramebuffers];
}

- (void)clear {
  [[NSNotificationCenter defaultCenter] removeObserver:self.memoryWarningObserver];
  self.memoryWarningObserver = nil;
}

#pragma mark -
#pragma mark Framebuffer management

- (NSString *)hashForSize:(CGSize)size textureOptions:(GPUTextureOptions)textureOptions onlyTexture:(BOOL)onlyTexture {
    if (onlyTexture) {
        return [NSString stringWithFormat:@"%.1fx%.1f-%d:%d:%d:%d:%d:%d:%d-NOFB", size.width, size.height, textureOptions.minFilter, textureOptions.magFilter, textureOptions.wrapS, textureOptions.wrapT, textureOptions.internalFormat, textureOptions.format, textureOptions.type];
    } else {
        return [NSString stringWithFormat:@"%.1fx%.1f-%d:%d:%d:%d:%d:%d:%d", size.width, size.height, textureOptions.minFilter, textureOptions.magFilter, textureOptions.wrapS, textureOptions.wrapT, textureOptions.internalFormat, textureOptions.format, textureOptions.type];
    }
}

- (GPUImageFramebuffer *)fetchFramebufferForSize:(CGSize)framebufferSize textureOptions:(GPUTextureOptions)textureOptions onlyTexture:(BOOL)onlyTexture {
    __block GPUImageFramebuffer *framebufferFromCache = nil;

    runSynchronouslyOnVideoProcessingQueue(^{
        NSString *lookupHash = [self hashForSize:framebufferSize textureOptions:textureOptions onlyTexture:onlyTexture];
        NSNumber *numberOfMatchingTexturesInCache = [self.framebufferTypeCounts objectForKey:lookupHash];

        NSInteger currentTextureID = ([numberOfMatchingTexturesInCache integerValue] - 1);
        while ((framebufferFromCache == nil) && (currentTextureID >= 0)) {
            NSString *textureHash = [NSString stringWithFormat:@"%@-%ld", lookupHash, (long)currentTextureID];
            framebufferFromCache = [self.framebufferCache objectForKey:textureHash];
            // Test the values in the cache first, to see if they got invalidated behind our back
            if (framebufferFromCache != nil) {
                // Withdraw this from the cache while it's in use
                [self.framebufferCache removeObjectForKey:textureHash];
            }
            currentTextureID--;
        }

        [self.framebufferTypeCounts setObject:[NSNumber numberWithInteger:currentTextureID+1] forKey:lookupHash];

        if (framebufferFromCache == nil) {
            framebufferFromCache = [[GPUImageFramebuffer alloc] initWithSize:framebufferSize textureOptions:textureOptions onlyTexture:onlyTexture];
        }
    });

    [framebufferFromCache lock];
    return framebufferFromCache;
}

- (GPUImageFramebuffer *)fetchFramebufferForSize:(CGSize)framebufferSize onlyTexture:(BOOL)onlyTexture {
    GPUTextureOptions defaultTextureOptions = {
        .minFilter = GL_LINEAR,
        .magFilter = GL_LINEAR,
        .wrapS = GL_CLAMP_TO_EDGE,
        .wrapT = GL_CLAMP_TO_EDGE,
        .internalFormat = GL_RGBA,
        .format = GL_BGRA,
        .type = GL_UNSIGNED_BYTE
    };

    return [self fetchFramebufferForSize:framebufferSize textureOptions:defaultTextureOptions onlyTexture:onlyTexture];
}

- (void)returnFramebufferToCache:(GPUImageFramebuffer *)framebuffer {
  [framebuffer clearAllLocks];
  __weak typeof(self) weakSelf = self;
  runAsynchronouslyOnVideoProcessingQueue(^{
    __strong typeof(weakSelf) self = weakSelf;
    if (self) {
      CGSize framebufferSize = framebuffer.size;
      GPUTextureOptions framebufferTextureOptions = framebuffer.textureOptions;
      NSString *lookupHash = [self hashForSize:framebufferSize textureOptions:framebufferTextureOptions onlyTexture:framebuffer.missingFramebuffer];
      NSNumber *numberOfMatchingTexturesInCache = [self.framebufferTypeCounts objectForKey:lookupHash];
      NSInteger numberOfMatchingTextures = [numberOfMatchingTexturesInCache integerValue];
      NSString *textureHash = [NSString stringWithFormat:@"%@-%ld", lookupHash, (long)numberOfMatchingTextures];
      [self.framebufferCache setObject:framebuffer forKey:textureHash];
      [self.framebufferTypeCounts setObject:[NSNumber numberWithInteger:(numberOfMatchingTextures + 1)] forKey:lookupHash];
    }
  });
}

- (void)purgeAllUnassignedFramebuffers {
    [self.framebufferCache removeAllObjects];
    [self.framebufferTypeCounts removeAllObjects];
    runAsynchronouslyOnVideoProcessingQueue(^{
        CVOpenGLESTextureCacheFlush([[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], 0);
    });
}

- (void)addFramebufferToActiveImageCaptureList:(GPUImageFramebuffer *)framebuffer {
  __weak typeof(self) weakSelf = self;
  runAsynchronouslyOnVideoProcessingQueue(^{
    __strong typeof(weakSelf) self = weakSelf;
    if (self) {
      [self.activeImageCaptureList addObject:framebuffer];
    }
  });
}

- (void)removeFramebufferFromActiveImageCaptureList:(GPUImageFramebuffer *)framebuffer {
  __weak typeof(self) weakSelf = self;
  runAsynchronouslyOnVideoProcessingQueue(^{
    __strong typeof(weakSelf) self = weakSelf;
    if (self) {
      [self.activeImageCaptureList removeObject:framebuffer];
    }
  });
}

@end
