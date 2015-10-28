#import "GPUImageFramebuffer.h"
#import "GPUImageOutput.h"

@interface GPUImageFramebuffer()

@property (nonatomic, assign) CVPixelBufferRef renderTarget;
@property (nonatomic, assign) CVOpenGLESTextureRef renderTexture;
@property (nonatomic, assign) NSUInteger readLockCount;
@property (nonatomic, assign) NSUInteger framebufferReferenceCount;
@property (nonatomic, assign) BOOL referenceCountingDisabled;

@property(nonatomic, readwrite, assign) CGSize size;
@property(nonatomic, readwrite, assign) GPUTextureOptions textureOptions;
@property(nonatomic, readwrite, assign) BOOL missingFramebuffer;

@property(nonatomic, readwrite, assign) GLuint texture;
@property(nonatomic, assign) GLuint framebuffer;

@end

void dataProviderReleaseCallback (void *info, const void *data, size_t size);
void dataProviderUnlockCallback (void *info, const void *data, size_t size);

@implementation GPUImageFramebuffer

#pragma mark -
#pragma mark Initialization and teardown

- (id)initWithSize:(CGSize)framebufferSize textureOptions:(GPUTextureOptions)fboTextureOptions onlyTexture:(BOOL)onlyGenerateTexture {
  if ((self = [super init])) {
    self.textureOptions = fboTextureOptions;
    self.size = framebufferSize;
    self.framebufferReferenceCount = 0;
    self.referenceCountingDisabled = NO;
    self.missingFramebuffer = onlyGenerateTexture;

    if (self.missingFramebuffer) {
      runSynchronouslyOnVideoProcessingQueue(^{
        [GPUImageContext useImageProcessingContext];
        [self generateTexture];
        self.framebuffer = 0;
      });
    } else {
      [self generateFramebuffer];
    }
  }
  return self;
}

- (id)initWithSize:(CGSize)framebufferSize overriddenTexture:(GLuint)inputTexture {
  if ((self = [super init])) {
    GPUTextureOptions defaultTextureOptions = {
      .minFilter = GL_LINEAR,
      .magFilter = GL_LINEAR,
      .wrapS = GL_CLAMP_TO_EDGE,
      .wrapT = GL_CLAMP_TO_EDGE,
      .internalFormat = GL_RGBA,
      .format = GL_BGRA,
      .type = GL_UNSIGNED_BYTE
    };
    self.textureOptions = defaultTextureOptions;
    self.size = framebufferSize;
    self.framebufferReferenceCount = 0;
    self.referenceCountingDisabled = YES;
    self.texture = inputTexture;
  }
  return self;
}

- (id)initWithSize:(CGSize)framebufferSize {
  GPUTextureOptions defaultTextureOptions = {
    .minFilter = GL_LINEAR,
    .magFilter = GL_LINEAR,
    .wrapS = GL_CLAMP_TO_EDGE,
    .wrapT = GL_CLAMP_TO_EDGE,
    .internalFormat = GL_RGBA,
    .format = GL_BGRA,
    .type = GL_UNSIGNED_BYTE
  };
  return [self initWithSize:framebufferSize textureOptions:defaultTextureOptions onlyTexture:NO];
}

- (void)dealloc {
  [self destroyFramebuffer];
}

#pragma mark -
#pragma mark Internal

- (void)generateTexture {
  glActiveTexture(GL_TEXTURE1);
  glGenTextures(1, &_texture);
  glBindTexture(GL_TEXTURE_2D, self.texture);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, self.textureOptions.minFilter);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, self.textureOptions.magFilter);
  // This is necessary for non-power-of-two textures
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, self.textureOptions.wrapS);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, self.textureOptions.wrapT);
  // TODO: Handle mipmaps
}

- (void)generateFramebuffer {
  runSynchronouslyOnVideoProcessingQueue(^{
    [GPUImageContext useImageProcessingContext];

    glGenFramebuffers(1, &_framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, self.framebuffer);

    // By default, all framebuffers on iOS 5.0+ devices are backed by texture caches, using one shared cache
    if ([GPUImageContext supportsFastTextureUpload]) {
      CVOpenGLESTextureCacheRef coreVideoTextureCache = [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache];
      // Code originally sourced from http://allmybrain.com/2011/12/08/rendering-to-a-texture-with-ios-5-texture-cache-api/

      CFDictionaryRef empty = CFDictionaryCreate(kCFAllocatorDefault, NULL, NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks); // our empty IOSurface properties dictionary
      CFMutableDictionaryRef attrs = CFDictionaryCreateMutable(kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
      CFDictionarySetValue(attrs, kCVPixelBufferIOSurfacePropertiesKey, empty);

      CVReturn err = CVPixelBufferCreate(kCFAllocatorDefault,  self.size.width,  self.size.height, kCVPixelFormatType_32BGRA, attrs, &_renderTarget);
      NSAssert(err == kCVReturnSuccess, @"FBO size: %f, %f\nError at CVPixelBufferCreate %d", self.size.width, self.size.height, err);

      err = CVOpenGLESTextureCacheCreateTextureFromImage (kCFAllocatorDefault, coreVideoTextureCache, self.renderTarget,
                                                          NULL, // texture attributes
                                                          GL_TEXTURE_2D,
                                                          self.textureOptions.internalFormat, // opengl format
                                                          self.size.width,
                                                          self.size.height,
                                                          self.textureOptions.format, // native iOS format
                                                          self.textureOptions.type,
                                                          0,
                                                          &_renderTexture);
      NSAssert(err == kCVReturnSuccess, @"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);

      CFRelease(attrs);
      CFRelease(empty);

      glBindTexture(CVOpenGLESTextureGetTarget(self.renderTexture), CVOpenGLESTextureGetName(self.renderTexture));
      self.texture = CVOpenGLESTextureGetName(self.renderTexture);
      glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, self.textureOptions.wrapS);
      glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, self.textureOptions.wrapT);

      glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, CVOpenGLESTextureGetName(self.renderTexture), 0);

      CVOpenGLESTextureCacheFlush(coreVideoTextureCache, 0);
    } else {
      [self generateTexture];

      glBindTexture(GL_TEXTURE_2D, self.texture);

      glTexImage2D(GL_TEXTURE_2D, 0, self.textureOptions.internalFormat,  self.size.width,  self.size.height, 0, self.textureOptions.format, self.textureOptions.type, 0);
      glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, self.texture, 0);
    }

#ifndef NS_BLOCK_ASSERTIONS
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    NSAssert(status == GL_FRAMEBUFFER_COMPLETE, @"Incomplete filter FBO: %d", status);
#endif
    glBindTexture(GL_TEXTURE_2D, 0);
  });
}

- (void)destroyFramebuffer {
  runSynchronouslyOnVideoProcessingQueue(^{
    [GPUImageContext useImageProcessingContext];
    if (self.framebuffer) {
      glDeleteFramebuffers(1, &_framebuffer);
      self.framebuffer = 0;
    }
    if ([GPUImageContext supportsFastTextureUpload] && (!_missingFramebuffer)) {
      if (self.renderTarget) {
        CFRelease(self.renderTarget);
        self.renderTarget = NULL;
      }
      if (self.renderTexture) {
        CFRelease(self.renderTexture);
        self.renderTexture = NULL;
      }
    } else {
      glDeleteTextures(1, &_texture);
    }
  });
}

#pragma mark -
#pragma mark Usage

- (void)activateFramebuffer {
  glBindFramebuffer(GL_FRAMEBUFFER, self.framebuffer);
}

#pragma mark -
#pragma mark Reference counting

- (void)lock {
  if (!self.referenceCountingDisabled) {
    self.framebufferReferenceCount++;
  }
}

- (void)unlock {
  if (!self.referenceCountingDisabled) {
    NSAssert(self.framebufferReferenceCount > 0, @"Tried to overrelease a framebuffer, did you forget to call -useNextFrameForImageCapture before using -imageFromCurrentFramebuffer?");
    self.framebufferReferenceCount--;
    if (self.framebufferReferenceCount < 1) {
      [[GPUImageContext sharedFramebufferCache] returnFramebufferToCache:self];
    }
  }
}

- (void)clearAllLocks {
  self.framebufferReferenceCount = 0;
}

- (void)disableReferenceCounting {
  self.referenceCountingDisabled = YES;
}

- (void)enableReferenceCounting {
  self.referenceCountingDisabled = NO;
}

#pragma mark -
#pragma mark Image capture

void dataProviderReleaseCallback (void *info, const void *data, size_t size) {
  free((void *)data);
}

void dataProviderUnlockCallback (void *info, const void *data, size_t size) {
  GPUImageFramebuffer *framebuffer = (__bridge_transfer GPUImageFramebuffer*)info;
  [framebuffer restoreRenderTarget];
  [framebuffer unlock];
  [[GPUImageContext sharedFramebufferCache] removeFramebufferFromActiveImageCaptureList:framebuffer];
}

- (CGImageRef)newCGImageFromFramebufferContents {
  // a CGImage can only be created from a 'normal' color texture
  NSAssert(self.textureOptions.internalFormat == GL_RGBA, @"For conversion to a CGImage the output texture format for this filter must be GL_RGBA.");
  NSAssert(self.textureOptions.type == GL_UNSIGNED_BYTE, @"For conversion to a CGImage the type of the output texture of this filter must be GL_UNSIGNED_BYTE.");

  __block CGImageRef cgImageFromBytes;

  runSynchronouslyOnVideoProcessingQueue(^{
    [GPUImageContext useImageProcessingContext];

    NSUInteger totalBytesForImage =  self.size.width *  self.size.height * 4;
    // It appears that the width of a texture must be padded out to be a multiple of 8 (32 bytes) if reading from it using a texture cache

    GLubyte *rawImagePixels;

    CGDataProviderRef dataProvider = NULL;
    if ([GPUImageContext supportsFastTextureUpload]) {
      NSUInteger paddedWidthOfImage = CVPixelBufferGetBytesPerRow(self.renderTarget) / 4.0;
      NSUInteger paddedBytesForImage = paddedWidthOfImage *  self.size.height * 4;

      glFinish();
      CFRetain(self.renderTarget); // I need to retain the pixel buffer here and release in the data source callback to prevent its bytes from being prematurely deallocated during a photo write operation
      [self lockForReading];
      rawImagePixels = (GLubyte *)CVPixelBufferGetBaseAddress(self.renderTarget);
      dataProvider = CGDataProviderCreateWithData((__bridge_retained void*)self, rawImagePixels, paddedBytesForImage, dataProviderUnlockCallback);
      [[GPUImageContext sharedFramebufferCache] addFramebufferToActiveImageCaptureList:self]; // In case the framebuffer is swapped out on the filter, need to have a strong reference to it somewhere for it to hang on while the image is in existence
    } else {
      [self activateFramebuffer];
      rawImagePixels = (GLubyte *)malloc(totalBytesForImage);
      glReadPixels(0, 0,  self.size.width,  self.size.height, GL_RGBA, GL_UNSIGNED_BYTE, rawImagePixels);
      dataProvider = CGDataProviderCreateWithData(NULL, rawImagePixels, totalBytesForImage, dataProviderReleaseCallback);
      [self unlock]; // Don't need to keep this around anymore
    }

    CGColorSpaceRef defaultRGBColorSpace = CGColorSpaceCreateDeviceRGB();

    if ([GPUImageContext supportsFastTextureUpload]) {
      cgImageFromBytes = CGImageCreate( self.size.width,  self.size.height, 8, 32, CVPixelBufferGetBytesPerRow(self.renderTarget), defaultRGBColorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst, dataProvider, NULL, NO, kCGRenderingIntentDefault);
    } else {
      cgImageFromBytes = CGImageCreate( self.size.width,  self.size.height, 8, 32, 4 *  self.size.width, defaultRGBColorSpace, kCGBitmapByteOrderDefault | kCGImageAlphaLast, dataProvider, NULL, NO, kCGRenderingIntentDefault);
    }

    // Capture image with current device orientation
    CGDataProviderRelease(dataProvider);
    CGColorSpaceRelease(defaultRGBColorSpace);
  });

  return cgImageFromBytes;
}

- (void)restoreRenderTarget {
  [self unlockAfterReading];
  CFRelease(self.renderTarget);
}

#pragma mark -
#pragma mark Raw data bytes

- (void)lockForReading {
  if ([GPUImageContext supportsFastTextureUpload]) {
    if (self.readLockCount == 0) {
      CVPixelBufferLockBaseAddress(self.renderTarget, 0);
    }
    self.readLockCount++;
  }
}

- (void)unlockAfterReading {
  if ([GPUImageContext supportsFastTextureUpload]) {
    NSAssert(self.readLockCount > 0, @"Unbalanced call to -[GPUImageFramebuffer unlockAfterReading]");
    self.readLockCount--;
    if (self.readLockCount == 0) {
      CVPixelBufferUnlockBaseAddress(self.renderTarget, 0);
    }
  }
}

- (NSUInteger)bytesPerRow {
  if ([GPUImageContext supportsFastTextureUpload]) {
    return CVPixelBufferGetBytesPerRow(self.renderTarget);
  } else {
    return self.size.width * 4;
  }
}

- (GLubyte *)byteBuffer {
  [self lockForReading];
  GLubyte * bufferBytes = CVPixelBufferGetBaseAddress(self.renderTarget);
  [self unlockAfterReading];
  return bufferBytes;
}

@end
