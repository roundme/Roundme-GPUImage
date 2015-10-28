#import "GPUImageThreeInputFilter.h"


NSString *const kGPUImageThreeInputTextureVertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 attribute vec4 inputTextureCoordinate2;
 attribute vec4 inputTextureCoordinate3;
 
 varying vec2 textureCoordinate;
 varying vec2 textureCoordinate2;
 varying vec2 textureCoordinate3;
 
 void main()
 {
     gl_Position = position;
     textureCoordinate = inputTextureCoordinate.xy;
     textureCoordinate2 = inputTextureCoordinate2.xy;
     textureCoordinate3 = inputTextureCoordinate3.xy;
 }
);

@implementation GPUImageThreeInputFilter

#pragma mark -
#pragma mark Initialization and teardown

- (id)initWithFragmentShaderFromString:(NSString *)fragmentShaderString;
{
    if (!(self = [self initWithVertexShaderFromString:kGPUImageThreeInputTextureVertexShaderString fragmentShaderFromString:fragmentShaderString]))
    {
		return nil;
    }
    
    return self;
}

- (id)initWithVertexShaderFromString:(NSString *)vertexShaderString fragmentShaderFromString:(NSString *)fragmentShaderString;
{
    if (!(self = [super initWithVertexShaderFromString:vertexShaderString fragmentShaderFromString:fragmentShaderString]))
    {
		return nil;
    }
    
    inputRotation3 = kGPUImageNoRotation;
    
    hasSetSecondTexture = NO;
    
    hasReceivedThirdFrame = NO;
    thirdFrameWasVideo = NO;
    thirdFrameCheckDisabled = NO;
    
    thirdFrameTime = kCMTimeInvalid;
    
    runSynchronouslyOnVideoProcessingQueue(^{
        [GPUImageContext useImageProcessingContext];
        filterThirdTextureCoordinateAttribute = [self.filterProgram attributeIndex:@"inputTextureCoordinate3"];
        
        filterInputTextureUniform3 = [self.filterProgram uniformIndex:@"inputImageTexture3"]; // This does assume a name of "inputImageTexture3" for the third input texture in the fragment shader
        glEnableVertexAttribArray(filterThirdTextureCoordinateAttribute);
    });
    
    return self;
}

- (void)initializeAttributes {
    [super initializeAttributes];
    [self.filterProgram addAttribute:@"inputTextureCoordinate3"];
}

- (void)disableThirdFrameCheck {
    thirdFrameCheckDisabled = YES;
}

#pragma mark -
#pragma mark Rendering

- (void)renderToTextureWithVertices:(const GLfloat *)vertices textureCoordinates:(const GLfloat *)textureCoordinates;
{
    NSAssert(NO, @"not implemented");
//    if (self.preventRendering)
//    {
//        [self.firstInputFramebuffer unlock];
//        [self.secondInputFramebuffer unlock];
//        [thirdInputFramebuffer unlock];
//        return;
//    }
//    
//    [GPUImageContext setActiveShaderProgram:self.filterProgram];
//    self.outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:[self sizeOfFBO] textureOptions:self.outputTextureOptions onlyTexture:NO];
//    [self.outputFramebuffer activateFramebuffer];
//    if (self.usingNextFrameForImageCapture)
//    {
//        [self.outputFramebuffer lock];
//    }
//
//    [self setUniformsForProgramAtIndex:0];
//    
//    glClearColor(self.backgroundColorRed, self.backgroundColorGreen, self.backgroundColorBlue, self.backgroundColorAlpha);
//    glClear(GL_COLOR_BUFFER_BIT);
//    
//	glActiveTexture(GL_TEXTURE2);
//	glBindTexture(GL_TEXTURE_2D, [self.firstInputFramebuffer texture]);
//	glUniform1i(self.filterInputTextureUniform, 2);
//    
//    glActiveTexture(GL_TEXTURE3);
//    glBindTexture(GL_TEXTURE_2D, [self.secondInputFramebuffer texture]);
//    glUniform1i(self.filterInputTextureUniform2, 3);
//
//    glActiveTexture(GL_TEXTURE4);
//    glBindTexture(GL_TEXTURE_2D, [thirdInputFramebuffer texture]);
//    glUniform1i(filterInputTextureUniform3, 4);
//
//    glVertexAttribPointer(self.filterPositionAttribute, 2, GL_FLOAT, 0, 0, vertices);
//	glVertexAttribPointer(self.filterTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);
//    glVertexAttribPointer(self.filterSecondTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, [[self class] textureCoordinatesForRotation:self.inputRotation2]);
//    glVertexAttribPointer(filterThirdTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, [[self class] textureCoordinatesForRotation:inputRotation3]);
//    
//    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
//    [self.firstInputFramebuffer unlock];
//    [self.secondInputFramebuffer unlock];
//    [thirdInputFramebuffer unlock];
//    if (self.usingNextFrameForImageCapture)
//    {
//        dispatch_semaphore_signal(self.imageCaptureSemaphore);
//    }
}

#pragma mark -
#pragma mark GPUImageInput

//- (NSInteger)nextAvailableTextureIndex;
//{
//    if (hasSetSecondTexture)
//    {
//        return 2;
//    }
//    else if (self.hasSetFirstTexture)
//    {
//        return 1;
//    }
//    else
//    {
//        return 0;
//    }
//}

- (void)setInputFramebuffer:(GPUImageFramebuffer *)value index:(NSUInteger)index {
    NSAssert(NO, @"not implemented");
//    if (textureIndex == 0)
//    {
//        self.firstInputFramebuffer = newInputFramebuffer;
//        self.hasSetFirstTexture = YES;
//        [self.firstInputFramebuffer lock];
//    }
//    else if (textureIndex == 1)
//    {
//        self.secondInputFramebuffer = newInputFramebuffer;
//        hasSetSecondTexture = YES;
//        [self.secondInputFramebuffer lock];
//    }
//    else
//    {
//        thirdInputFramebuffer = newInputFramebuffer;
//        [thirdInputFramebuffer lock];
//    }
}

- (void)setInputSize:(CGSize)value index:(NSUInteger)index {
    NSAssert(NO, @"not implemented");
//    if (textureIndex == 0)
//    {
//        [super setInputSize:newSize atIndex:textureIndex];
//        
//        if (CGSizeEqualToSize(newSize, CGSizeZero))
//        {
//            self.hasSetFirstTexture = NO;
//        }
//    }
//    else if (textureIndex == 1)
//    {
//        if (CGSizeEqualToSize(newSize, CGSizeZero))
//        {
//            hasSetSecondTexture = NO;
//        }
//    }
}

- (void)setInputRotation:(GPUImageRotationMode)value index:(NSUInteger)index {
    NSAssert(NO, @"not implemented");
//    if (textureIndex == 0)
//    {
//        self.inputRotation = newInputRotation;
//    }
//    else if (textureIndex == 1)
//    {
//        self.inputRotation2 = newInputRotation;
//    }
//    else
//    {
//        inputRotation3 = newInputRotation;
//    }
}

- (CGSize)rotatedSize:(CGSize)sizeToRotate forIndex:(NSInteger)textureIndex;
{
    NSAssert(NO, @"not implemented");
    CGSize rotatedSize = sizeToRotate;
//
//    GPUImageRotationMode rotationToCheck;
//    if (textureIndex == 0)
//    {
//        rotationToCheck = self.inputRotation;
//    }
//    else if (textureIndex == 1)
//    {
//        rotationToCheck = self.inputRotation2;
//    }
//    else
//    {
//        rotationToCheck = inputRotation3;
//    }
//    
//    if (GPUImageRotationSwapsWidthAndHeight(rotationToCheck))
//    {
//        rotatedSize.width = sizeToRotate.height;
//        rotatedSize.height = sizeToRotate.width;
//    }
//    
    return rotatedSize;
}

- (void)newFrameReadyAtTime:(CMTime)frameTime atIndex:(NSInteger)textureIndex;
{
    NSAssert(NO, @"not implemented");
//    // You can set up infinite update loops, so this helps to short circuit them
//    if (self.hasReceivedFirstFrame && self.hasReceivedSecondFrame && hasReceivedThirdFrame)
//    {
//        return;
//    }
//    
//    BOOL updatedMovieFrameOppositeStillImage = NO;
//    
//    if (textureIndex == 0)
//    {
//        self.hasReceivedFirstFrame = YES;
//        self.firstFrameTime = frameTime;
//        if (self.secondFrameCheckDisabled)
//        {
//            self.hasReceivedSecondFrame = YES;
//        }
//        if (thirdFrameCheckDisabled)
//        {
//            hasReceivedThirdFrame = YES;
//        }
//        
//        if (!CMTIME_IS_INDEFINITE(frameTime))
//        {
//            if CMTIME_IS_INDEFINITE(self.secondFrameTime)
//            {
//                updatedMovieFrameOppositeStillImage = YES;
//            }
//        }
//    }
//    else if (textureIndex == 1)
//    {
//        self.hasReceivedSecondFrame = YES;
//        self.secondFrameTime = frameTime;
//        if (self.firstFrameCheckDisabled)
//        {
//            self.hasReceivedFirstFrame = YES;
//        }
//        if (thirdFrameCheckDisabled)
//        {
//            hasReceivedThirdFrame = YES;
//        }
//
//        if (!CMTIME_IS_INDEFINITE(frameTime))
//        {
//            if CMTIME_IS_INDEFINITE(self.firstFrameTime)
//            {
//                updatedMovieFrameOppositeStillImage = YES;
//            }
//        }
//    }
//    else
//    {
//        hasReceivedThirdFrame = YES;
//        thirdFrameTime = frameTime;
//        if (self.firstFrameCheckDisabled)
//        {
//            self.hasReceivedFirstFrame = YES;
//        }
//        if (self.secondFrameCheckDisabled)
//        {
//            self.hasReceivedSecondFrame = YES;
//        }
//        
//        if (!CMTIME_IS_INDEFINITE(frameTime))
//        {
//            if CMTIME_IS_INDEFINITE(self.firstFrameTime)
//            {
//                updatedMovieFrameOppositeStillImage = YES;
//            }
//        }
//    }
//    
//    // || (hasReceivedFirstFrame && secondFrameCheckDisabled) || (hasReceivedSecondFrame && firstFrameCheckDisabled)
//    if ((self.hasReceivedFirstFrame && self.hasReceivedSecondFrame && hasReceivedThirdFrame) || updatedMovieFrameOppositeStillImage)
//    {
//        static const GLfloat imageVertices[] = {
//            -1.0f, -1.0f,
//            1.0f, -1.0f,
//            -1.0f,  1.0f,
//            1.0f,  1.0f,
//        };
//        
//        [self renderToTextureWithVertices:imageVertices textureCoordinates:[[self class] textureCoordinatesForRotation:self.inputRotation]];
//        
//        [self informTargetsAboutNewFrameAtTime:frameTime];
//
//        self.hasReceivedFirstFrame = NO;
//        self.hasReceivedSecondFrame = NO;
//        hasReceivedThirdFrame = NO;
//    }
}

@end
