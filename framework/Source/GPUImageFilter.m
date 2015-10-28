#import "GPUImageFilter.h"
#import "GPUImagePicture.h"
#import <AVFoundation/AVFoundation.h>

static const GLuint NUMBER_OF_INPUT_FRAME_BUFFERS = 1;

// Hardcode the vertex shader for standard filters, but this can be overridden
NSString *const kGPUImageVertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 
 varying vec2 textureCoordinate;
 
 void main()
 {
     gl_Position = position;
     textureCoordinate = inputTextureCoordinate.xy;
 }
 );

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE

NSString *const kGPUImagePassthroughFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 void main()
 {
     gl_FragColor = texture2D(inputImageTexture, textureCoordinate);
 }
);

#else

NSString *const kGPUImagePassthroughFragmentShaderString = SHADER_STRING
(
 varying vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 void main()
 {
     gl_FragColor = texture2D(inputImageTexture, textureCoordinate);
 }
);
#endif

typedef NS_ENUM(NSUInteger, SizeOverride) {
  SIZE_NO_LIMIT,
  SIZE_LIMIT,
  SIZE_LIMIT_AR
};

@interface GPUImageFilter()

@property (nonatomic, assign) BOOL isEndProcessing;

@property (nonatomic, assign) CGSize currentFilterSize;

@property (nonatomic, assign) SizeOverride sizeOverride;
@property (nonatomic, assign) CGSize sizeOverrideLimit;

@end

@implementation GPUImageFilter

#pragma mark - Initialization and teardown

- (id)initWithVertexShaderFromString:(NSString *)vertexShaderString fragmentShaderFromString:(NSString *)fragmentShaderString {
  if ((self = [super init])) {
    self.uniformStateRestorationBlocks = [NSMutableDictionary dictionaryWithCapacity:10];
    self.sizeOverride = SIZE_NO_LIMIT;
    self.preventRendering = NO;
    self.backgroundColorRed = 0.0;
    self.backgroundColorGreen = 0.0;
    self.backgroundColorBlue = 0.0;
    self.backgroundColorAlpha = 0.0;

    [self initFrameBuffers];

    self.imageCaptureSemaphore = dispatch_semaphore_create(0);
    dispatch_semaphore_signal(self.imageCaptureSemaphore);

    runSynchronouslyOnVideoProcessingQueue(^{
      [GPUImageContext useImageProcessingContext];

      self.filterProgram = [[GLProgram alloc] initWithVertexShaderString:vertexShaderString fragmentShaderString:fragmentShaderString];
      NSAssert(self.filterProgram, @"filter program init error");

      if (!self.filterProgram.initialized) {
        [self initializeAttributes];
        [self.filterProgram link];
      }

      [self configGL];
    });
  }

  return self;
}

- (void)initNumberOfInputs {
  self.numberOfInputs = NUMBER_OF_INPUT_FRAME_BUFFERS;
}

- (void)initFrameBuffers {
  [self initNumberOfInputs];
  self.inputs = [NSMutableArray arrayWithCapacity:self.numberOfInputs];
}

#pragma mark - Setup

- (void)configGL {
  [GPUImageContext setActiveShaderProgram:self.filterProgram];
  self.filterPositionAttribute = [self.filterProgram attributeIndex:@"position"];
  glEnableVertexAttribArray(self.filterPositionAttribute);

  GLuint textureCoordinateAttribute = [self.filterProgram attributeIndex:@"inputTextureCoordinate"];
  [self setInputTextureCoordinateAttribute:textureCoordinateAttribute index:0];
  glEnableVertexAttribArray(textureCoordinateAttribute);

  GLuint textureUniform = [self.filterProgram uniformIndex:@"inputImageTexture"];
  [self setInputTextureUniform:textureUniform index:0];
  glUniform1i(textureUniform, 2);

  for (NSUInteger rotation = 0; rotation < self.numberOfInputs; rotation++) {
    [self setInputRotation:kGPUImageNoRotation index:rotation];
  }
}

- (void)setupVerticesAndTextureCoordinates {
  if ([self.inputs count] == self.numberOfInputs) {
    [self clearVerticesAndTextureCoordinates];
    runSynchronouslyOnVideoProcessingQueue(^{
      for (NSUInteger input = 0; input < self.numberOfInputs; input++) {
        GLuint vertexBuffer;
        glGenBuffers(1, &vertexBuffer);
        glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
        glBufferData(GL_ARRAY_BUFFER, 4 * sizeof(Vertex2D), verticesAndTextureCoordinatesForRotation([self getInputRotation:input]), GL_STATIC_DRAW);

        glBindBuffer(GL_ARRAY_BUFFER, 0);
        [self setInputVertexBuffer:vertexBuffer index:input];
        [self setInputIndexBuffer:0 index:input];
      }
    });
  }
}

- (void)clearVerticesAndTextureCoordinates {
  runSynchronouslyOnVideoProcessingQueue(^{
    for (NSUInteger input = 0; input < self.numberOfInputs; input++) {
      GLuint vertexBuffer = [self getInputVertexBuffer:input];
      if (vertexBuffer != 0) {
        glDeleteBuffers(1, &vertexBuffer);
        [self setInputVertexBuffer:0 index:input];
      }
      GLuint indexBuffer = [self getInputIndexBuffer:input];
      if (indexBuffer != 0) {
        glDeleteBuffers(1, &indexBuffer);
        [self setInputIndexBuffer:0 index:input];
      }
    }
  });
}

- (id)initWithFragmentShaderFromString:(NSString *)fragmentShaderString {
  self = [self initWithVertexShaderFromString:kGPUImageVertexShaderString fragmentShaderFromString:fragmentShaderString];
  return self;
}

- (id)initWithFragmentShaderFromFile:(NSString *)fragmentShaderFilename {
  NSString *fragmentShaderPathname = [[NSBundle mainBundle] pathForResource:fragmentShaderFilename ofType:@"fsh"];
  NSString *fragmentShaderString = [NSString stringWithContentsOfFile:fragmentShaderPathname encoding:NSUTF8StringEncoding error:nil];

  self = [self initWithFragmentShaderFromString:fragmentShaderString];
  return self;
}

- (id)init {
  self = [self initWithFragmentShaderFromString:kGPUImagePassthroughFragmentShaderString];
  return self;
}

- (void)initializeAttributes {
  [self.filterProgram addAttribute:@"position"];
  [self.filterProgram addAttribute:@"inputTextureCoordinate"];
  // Override this, calling back to this super method, in order to add new attributes to your vertex shader
}

- (void)setupFilterForSize:(CGSize)filterFrameSize {
  // This is where you can override to provide some custom setup, if your filter has a size-dependent element
}

- (void)dealloc {
  [self clearVerticesAndTextureCoordinates];
}

#pragma mark - Inputs

- (GPUImageFilterInput *)getInput:(NSUInteger)index {
  NSAssert(index < self.numberOfInputs, @"Invalid input requested");
  GPUImageFilterInput *input = nil;
  if (index < [self.inputs count]) {
    input = self.inputs[index];
  }
  if (input == nil) {
    input = [[GPUImageFilterInput alloc] init];
    [self.inputs setObject:input atIndexedSubscript:index];
  }
  return input;
}

- (GPUImageFramebuffer *)getInputFramebuffer:(NSUInteger)index {
  return [self getInput:index].framebuffer;
}

- (void)setInputFramebuffer:(GPUImageFramebuffer *)value index:(NSUInteger)index {
  GPUImageFilterInput *input = [self getInput:index];
  input.framebuffer = value;
  [value lock];
}

- (GLuint)getInputVertexBuffer:(NSUInteger)index {
  return [self getInput:index].vertexbuffer;
}

- (void)setInputVertexBuffer:(GLuint)value index:(NSUInteger)index {
  GPUImageFilterInput *input = [self getInput:index];
  input.vertexbuffer = value;
}

- (GLuint)getInputIndexBuffer:(NSUInteger)index {
  return [self getInput:index].indexbuffer;
}

- (void)setInputIndexBuffer:(GLuint)value index:(NSUInteger)index {
  GPUImageFilterInput *input = [self getInput:index];
  input.indexbuffer = value;
}

- (GLuint)getInputTextureCoordinateAttribute:(NSUInteger)index {
  return [self getInput:index].textureCoordinateAttribute;
}

- (void)setInputTextureCoordinateAttribute:(GLuint)value index:(NSUInteger)index {
  GPUImageFilterInput *input = [self getInput:index];
  input.textureCoordinateAttribute = value;
}

- (GLuint)getInputTextureUniform:(NSUInteger)index {
  return [self getInput:index].textureUniform;
}

- (void)setInputTextureUniform:(GLuint)value index:(NSUInteger)index {
  GPUImageFilterInput *input = [self getInput:index];
  input.textureUniform = value;
}

- (BufferState)getInputReceivedFlag:(NSUInteger)index {
  return [self getInput:index].receivedFlag;
}

- (void)setInputReceivedFlag:(BufferState)value index:(NSUInteger)index {
  GPUImageFilterInput *input = [self getInput:index];
  input.receivedFlag = value;
}

- (GPUImageRotationMode)getInputRotation:(NSUInteger)index {
  return [self getInput:index].rotation;
}

- (void)setInputRotation:(GPUImageRotationMode)value index:(NSUInteger)index {
  GPUImageFilterInput *input = [self getInput:index];
  input.rotation = value;
  [self setInputSize:rotatedSize(input.size, value) index:index];
  [self setupVerticesAndTextureCoordinates];
}

- (CGSize)getInputSize:(NSUInteger)index {
  return [self getInput:index].size;
}

- (void)setInputSize:(CGSize)value index:(NSUInteger)index {
  if (!self.preventRendering) {
    CGSize newSize;
    GPUImageFilterInput *input = [self getInput:index];
    switch (self.sizeOverride) {
      case SIZE_NO_LIMIT:
        newSize = value;
        break;
      case SIZE_LIMIT:
        NSAssert(self.sizeOverrideLimit.width * self.sizeOverrideLimit.height > 0.0, @"Invalid input size");
        newSize = self.sizeOverrideLimit;
        break;
      case SIZE_LIMIT_AR:
        NSAssert(value.width * value.height > 0.0, @"Invalid input size");
        NSAssert(self.sizeOverrideLimit.width * self.sizeOverrideLimit.height > 0.0, @"Invalid input size");
        CGRect insetRect = AVMakeRectWithAspectRatioInsideRect(value, CGRectMake(0.0, 0.0, self.sizeOverrideLimit.width, self.sizeOverrideLimit.height));
        newSize = insetRect.size;
        break;
    }
    input.size = newSize;
    if (index == 0) {
      [self setupFilterForSize:[self sizeOfFBO]];
    }
  }
}

#pragma mark - Still image processing

- (void)useNextFrameForImageCapture {
  self.usingNextFrameForImageCapture = YES;
}

- (CGImageRef)newCGImageFromCurrentlyProcessedOutput {
  // Give it three seconds to process, then abort if they forgot to set up the image capture properly
  double timeoutForImageCapture = 3.0;
  dispatch_time_t convertedTimeout = dispatch_time(DISPATCH_TIME_NOW, timeoutForImageCapture * NSEC_PER_SEC);

  if (dispatch_semaphore_wait(self.imageCaptureSemaphore, convertedTimeout) != 0) {
    return NULL;
  }

  self.usingNextFrameForImageCapture = NO;
  dispatch_semaphore_signal(self.imageCaptureSemaphore);

  // All image output is now managed by the framebuffer itself
  return [self.outputFramebuffer newCGImageFromFramebufferContents];
}

#pragma mark - Vertices & Indices

-(void)bindVerticesAndIndices {
  NSAssert([self.inputs count] == self.numberOfInputs, @"Invalid number of inputs");
  glBindBuffer(GL_ARRAY_BUFFER, [self getInputVertexBuffer:0]);
  glVertexAttribPointer(self.filterPositionAttribute, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex2D), 0);

  for (NSUInteger input = 0; input < self.numberOfInputs; input++) {
    glBindBuffer(GL_ARRAY_BUFFER, [self getInputVertexBuffer:input]);
    GLuint textureCoordinateAttribure = [self getInputTextureCoordinateAttribute:input];
    glVertexAttribPointer(textureCoordinateAttribure, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex2D), (GLvoid*)(sizeof(GLfloat) * 2));
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, [self getInputIndexBuffer:input]);
  }
}

-(void)unbindVerticesAndIndices {
  glBindBuffer(GL_ARRAY_BUFFER, 0);
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
}

#pragma mark - Rendering

- (BOOL)preRender {
  if (self.preventRendering) {
    [self unlockBuffers];
    return NO;
  }

  [GPUImageContext setActiveShaderProgram:self.filterProgram];

  self.outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:[self sizeOfFBO] textureOptions:self.outputTextureOptions onlyTexture:NO];
  [self.outputFramebuffer activateFramebuffer];
  if (self.usingNextFrameForImageCapture) {
    [self.outputFramebuffer lock];
  }

  [self setUniformsForProgramAtIndex:0];

  glClearColor(self.backgroundColorRed, self.backgroundColorGreen, self.backgroundColorBlue, self.backgroundColorAlpha);
  glClear(GL_COLOR_BUFFER_BIT);

  [self bindVerticesAndIndices];

  return YES;
}

- (void)render {
  for (GLenum frameIndex = 0; frameIndex < self.numberOfInputs; frameIndex++) {
    glActiveTexture(GL_TEXTURE2 + frameIndex);
    glBindTexture(GL_TEXTURE_2D, [[self getInputFramebuffer:frameIndex] texture]);
  }
  glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

- (void)postRender {
  [self unbindVerticesAndIndices];

  [self unlockBuffers];

  if (self.usingNextFrameForImageCapture) {
    dispatch_semaphore_signal(self.imageCaptureSemaphore);
  }
}

#pragma mark - Frames management

- (void)setFrame:(NSInteger)textureIndex {
  NSAssert(textureIndex >= 0 && textureIndex < self.numberOfInputs, @"invalid texture index");
  [self setInputReceivedFlag:SET index:textureIndex];
}

- (BOOL)hasReceivedAllFrames {
  for (NSUInteger frameIndex = 0; frameIndex < self.numberOfInputs; frameIndex++) {
    if ([self getInputReceivedFlag:frameIndex] != SET) {
      return NO;
    }
  }
  return YES;
}

- (void)dropFrames {
  for (NSUInteger frameIndex = 0; frameIndex < self.numberOfInputs; frameIndex++) {
    [self setInputReceivedFlag:FREE index:frameIndex];
  }
}

- (BOOL)isFilterReady {
  for (NSUInteger frameIndex = 0; frameIndex < self.numberOfInputs; frameIndex++) {
    if ([self getInputReceivedFlag:frameIndex] != FREE) {
      return NO;
    }
  }
  return YES;
}

#pragma mark - Buffers management

- (void)unlockBuffers {
  for (GPUImageFilterInput *input in self.inputs) {
    GPUImageFramebuffer *framebuffer = input.framebuffer;
    [framebuffer disableReferenceCounting];
    [framebuffer unlock];
  }
}

- (CGSize)maximumOutputSize {
  // I'm temporarily disabling adjustments for smaller output sizes until I figure out how to make this work better
  return CGSizeZero;

  /*
   if (CGSizeEqualToSize(cachedMaximumOutputSize, CGSizeZero))
   {
   for (id<GPUImageInput> currentTarget in targets)
   {
   if ([currentTarget maximumOutputSize].width > cachedMaximumOutputSize.width)
   {
   cachedMaximumOutputSize = [currentTarget maximumOutputSize];
   }
   }
   }

   return cachedMaximumOutputSize;
   */
}

- (CGSize)outputFrameSize {
  return [self getInputSize:0];
}

- (CGSize)sizeOfFBO {
  CGSize outputSize = [self maximumOutputSize];
  CGSize inputSize = [self getInputSize:0];
  if ((CGSizeEqualToSize(outputSize, CGSizeZero)) || (inputSize.width < outputSize.width)) {
    return inputSize;
  } else {
    return outputSize;
  }
}

#pragma mark - GPUImageInput

- (NSInteger)nextAvailableTextureIndex {
  NSUInteger nt = NSNotFound;
  for (NSUInteger index = 0; index < self.numberOfInputs; index++) {
    if ([self getInputReceivedFlag:index] == FREE) {
      nt = index;
      break;
    }
  }
  NSAssert(nt != NSNotFound, @"invalid texture index");
  [self setInputReceivedFlag:RESERVED index:nt];
  return nt;
}

- (void)newFrameReadyAtTime:(CMTime)frameTime atIndex:(NSInteger)textureIndex {
  runSynchronouslyOnVideoProcessingQueue(^{
    [self setFrame:textureIndex];
    if ([self hasReceivedAllFrames]) {
      if ([self preRender]) {
        [self render];
        [self postRender];
      }
      [self informTargetsAboutNewFrameAtTime:frameTime];
      [self dropFrames];
    }
  });
}

- (void)forceProcessingAtSize:(CGSize)frameSize {
  NSAssert(frameSize.width * frameSize.height > 0.0, @"Invalid input size");
  self.sizeOverride = SIZE_LIMIT;
  self.sizeOverrideLimit = frameSize;
  [self updateOldSizes];
}

- (void)forceProcessingAtSizeRespectingAspectRatio:(CGSize)frameSize {
  NSAssert(frameSize.width * frameSize.height > 0.0, @"Invalid input size");
  self.sizeOverride = SIZE_LIMIT_AR;
  self.sizeOverrideLimit = frameSize;
  [self updateOldSizes];
}

- (void)updateOldSizes {
  for (NSUInteger input = 0; input < self.numberOfInputs; input++) {
    [self setInputSize:[self getInputSize:input] index:input];
  }
}

- (void)endProcessing {
  if (!self.isEndProcessing) {
    self.isEndProcessing = YES;
    [self loopTargetsWithTargetAndTextureIndex:^(id<GPUImageInput> target, NSUInteger textureIndex) {
      [target endProcessing];
    }];
  }
}

#pragma mark - Input parameters

- (void)setBackgroundColorRed:(GLfloat)redComponent green:(GLfloat)greenComponent blue:(GLfloat)blueComponent alpha:(GLfloat)alphaComponent {
  self.backgroundColorRed = redComponent;
  self.backgroundColorGreen = greenComponent;
  self.backgroundColorBlue = blueComponent;
  self.backgroundColorAlpha = alphaComponent;
}

- (void)setInteger:(GLint)newInteger forUniformName:(NSString *)uniformName {
  GLint uniformIndex = [self.filterProgram uniformIndex:uniformName];
  [self setInteger:newInteger forUniform:uniformIndex program:self.filterProgram];
}

- (void)setFloat:(GLfloat)newFloat forUniformName:(NSString *)uniformName {
  GLint uniformIndex = [self.filterProgram uniformIndex:uniformName];
  [self setFloat:newFloat forUniform:uniformIndex program:self.filterProgram];
}

- (void)setSize:(CGSize)newSize forUniformName:(NSString *)uniformName {
  GLint uniformIndex = [self.filterProgram uniformIndex:uniformName];
  [self setSize:newSize forUniform:uniformIndex program:self.filterProgram];
}

- (void)setPoint:(CGPoint)newPoint forUniformName:(NSString *)uniformName {
  GLint uniformIndex = [self.filterProgram uniformIndex:uniformName];
  [self setPoint:newPoint forUniform:uniformIndex program:self.filterProgram];
}

- (void)setFloatVec3:(GPUVector3)newVec3 forUniformName:(NSString *)uniformName {
  GLint uniformIndex = [self.filterProgram uniformIndex:uniformName];
  [self setVec3:newVec3 forUniform:uniformIndex program:self.filterProgram];
}

- (void)setFloatVec4:(GPUVector4)newVec4 forUniform:(NSString *)uniformName {
  GLint uniformIndex = [self.filterProgram uniformIndex:uniformName];
  [self setVec4:newVec4 forUniform:uniformIndex program:self.filterProgram];
}

- (void)setFloatArray:(GLfloat *)array length:(GLsizei)count forUniform:(NSString*)uniformName {
  GLint uniformIndex = [self.filterProgram uniformIndex:uniformName];
  [self setFloatArray:array length:count forUniform:uniformIndex program:self.filterProgram];
}

- (void)setMatrix3f:(GPUMatrix3x3)matrix forUniform:(GLint)uniform program:(GLProgram *)shaderProgram {
  __weak typeof(self) weakSelf = self;
  runAsynchronouslyOnVideoProcessingQueue(^{
    __strong typeof(weakSelf) self = weakSelf;
    if (self) {
      [GPUImageContext setActiveShaderProgram:shaderProgram];
      [self setAndExecuteUniformStateCallbackAtIndex:uniform forProgram:shaderProgram toBlock:^{
        glUniformMatrix3fv(uniform, 1, GL_FALSE, (GLfloat *)&matrix);
      }];
    }
  });
}

- (void)setMatrix4f:(GPUMatrix4x4)matrix forUniform:(GLint)uniform program:(GLProgram *)shaderProgram {
  __weak typeof(self) weakSelf = self;
  runAsynchronouslyOnVideoProcessingQueue(^{
    __strong typeof(weakSelf) self = weakSelf;
    if (self) {
      [GPUImageContext setActiveShaderProgram:shaderProgram];
      [self setAndExecuteUniformStateCallbackAtIndex:uniform forProgram:shaderProgram toBlock:^{
        glUniformMatrix4fv(uniform, 1, GL_FALSE, (GLfloat *)&matrix);
      }];
    }
  });
}

- (void)setFloat:(GLfloat)floatValue forUniform:(GLint)uniform program:(GLProgram *)shaderProgram {
  __weak typeof(self) weakSelf = self;
  runAsynchronouslyOnVideoProcessingQueue(^{
    __strong typeof(weakSelf) self = weakSelf;
    if (self) {
      [GPUImageContext setActiveShaderProgram:shaderProgram];
      [self setAndExecuteUniformStateCallbackAtIndex:uniform forProgram:shaderProgram toBlock:^{
        glUniform1f(uniform, floatValue);
      }];
    }
  });
}

- (void)setPoint:(CGPoint)pointValue forUniform:(GLint)uniform program:(GLProgram *)shaderProgram {
  __weak typeof(self) weakSelf = self;
  runAsynchronouslyOnVideoProcessingQueue(^{
    __strong typeof(weakSelf) self = weakSelf;
    if (self) {
      [GPUImageContext setActiveShaderProgram:shaderProgram];
      [self setAndExecuteUniformStateCallbackAtIndex:uniform forProgram:shaderProgram toBlock:^{
        GLfloat positionArray[2];
        positionArray[0] = pointValue.x;
        positionArray[1] = pointValue.y;
        glUniform2fv(uniform, 1, positionArray);
      }];
    }
  });
}

- (void)setSize:(CGSize)sizeValue forUniform:(GLint)uniform program:(GLProgram *)shaderProgram {
  __weak typeof(self) weakSelf = self;
  runAsynchronouslyOnVideoProcessingQueue(^{
    __strong typeof(weakSelf) self = weakSelf;
    if (self) {
      [GPUImageContext setActiveShaderProgram:shaderProgram];
      [self setAndExecuteUniformStateCallbackAtIndex:uniform forProgram:shaderProgram toBlock:^{
        GLfloat sizeArray[2];
        sizeArray[0] = sizeValue.width;
        sizeArray[1] = sizeValue.height;
        glUniform2fv(uniform, 1, sizeArray);
      }];
    }
  });
}

- (void)setVec3:(GPUVector3)vectorValue forUniform:(GLint)uniform program:(GLProgram *)shaderProgram {
  __weak typeof(self) weakSelf = self;
  runAsynchronouslyOnVideoProcessingQueue(^{
    __strong typeof(weakSelf) self = weakSelf;
    if (self) {
      [GPUImageContext setActiveShaderProgram:shaderProgram];
      [self setAndExecuteUniformStateCallbackAtIndex:uniform forProgram:shaderProgram toBlock:^{
        glUniform3fv(uniform, 1, (GLfloat *)&vectorValue);
      }];
    }
  });
}

- (void)setVec4:(GPUVector4)vectorValue forUniform:(GLint)uniform program:(GLProgram *)shaderProgram {
  __weak typeof(self) weakSelf = self;
  runAsynchronouslyOnVideoProcessingQueue(^{
    __strong typeof(weakSelf) self = weakSelf;
    if (self) {
      [GPUImageContext setActiveShaderProgram:shaderProgram];
      [self setAndExecuteUniformStateCallbackAtIndex:uniform forProgram:shaderProgram toBlock:^{
        glUniform4fv(uniform, 1, (GLfloat *)&vectorValue);
      }];
    }
  });
}

- (void)setFloatArray:(GLfloat *)arrayValue length:(GLsizei)arrayLength forUniform:(GLint)uniform program:(GLProgram *)shaderProgram {
  // Make a copy of the data, so it doesn't get overwritten before async call executes
  NSData* arrayData = [NSData dataWithBytes:arrayValue length:arrayLength * sizeof(arrayValue[0])];
  __weak typeof(self) weakSelf = self;
  runAsynchronouslyOnVideoProcessingQueue(^{
    __strong typeof(weakSelf) self = weakSelf;
    if (self) {
      [GPUImageContext setActiveShaderProgram:shaderProgram];
      [self setAndExecuteUniformStateCallbackAtIndex:uniform forProgram:shaderProgram toBlock:^{
        glUniform1fv(uniform, arrayLength, [arrayData bytes]);
      }];
    }
  });
}

- (void)setInteger:(GLint)intValue forUniform:(GLint)uniform program:(GLProgram *)shaderProgram {
  __weak typeof(self) weakSelf = self;
  runAsynchronouslyOnVideoProcessingQueue(^{
    __strong typeof(weakSelf) self = weakSelf;
    if (self) {
      [GPUImageContext setActiveShaderProgram:shaderProgram];
      [self setAndExecuteUniformStateCallbackAtIndex:uniform forProgram:shaderProgram toBlock:^{
        glUniform1i(uniform, intValue);
      }];
    }
  });
}

- (void)setAndExecuteUniformStateCallbackAtIndex:(GLint)uniform forProgram:(GLProgram *)shaderProgram toBlock:(dispatch_block_t)uniformStateBlock {
  [self.uniformStateRestorationBlocks setObject:[uniformStateBlock copy] forKey:[NSNumber numberWithInt:uniform]];
  uniformStateBlock();
}

- (void)setUniformsForProgramAtIndex:(NSUInteger)programIndex {
  [self.uniformStateRestorationBlocks enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop){
    dispatch_block_t currentBlock = obj;
    currentBlock();
  }];
}

@end
