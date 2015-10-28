#import "GPUImageTwoPassFilter.h"

@implementation GPUImageTwoPassFilter

#pragma mark -
#pragma mark Initialization and teardown

- (id)initWithFirstStageVertexShaderFromString:(NSString *)firstStageVertexShaderString firstStageFragmentShaderFromString:(NSString *)firstStageFragmentShaderString secondStageVertexShaderFromString:(NSString *)secondStageVertexShaderString secondStageFragmentShaderFromString:(NSString *)secondStageFragmentShaderString;
{
    if (!(self = [super initWithVertexShaderFromString:firstStageVertexShaderString fragmentShaderFromString:firstStageFragmentShaderString]))
    {
		return nil;
    }
    
    secondProgramUniformStateRestorationBlocks = [NSMutableDictionary dictionaryWithCapacity:10];

    runSynchronouslyOnVideoProcessingQueue(^{
        [GPUImageContext useImageProcessingContext];

        secondFilterProgram = [[GLProgram alloc] initWithVertexShaderString:secondStageVertexShaderString fragmentShaderString:secondStageFragmentShaderString];

        if (!secondFilterProgram.initialized)
        {
            [self initializeSecondaryAttributes];

            [secondFilterProgram link];
        }
        
        secondFilterPositionAttribute = [secondFilterProgram attributeIndex:@"position"];
        secondFilterTextureCoordinateAttribute = [secondFilterProgram attributeIndex:@"inputTextureCoordinate"];
        secondFilterInputTextureUniform = [secondFilterProgram uniformIndex:@"inputImageTexture"]; // This does assume a name of "inputImageTexture" for the fragment shader
        secondFilterInputTextureUniform2 = [secondFilterProgram uniformIndex:@"inputImageTexture2"]; // This does assume a name of "inputImageTexture2" for second input texture in the fragment shader
        
        [GPUImageContext setActiveShaderProgram:secondFilterProgram];
        
        glEnableVertexAttribArray(secondFilterPositionAttribute);
        glEnableVertexAttribArray(secondFilterTextureCoordinateAttribute);
    });

    return self;
}

- (id)initWithFirstStageFragmentShaderFromString:(NSString *)firstStageFragmentShaderString secondStageFragmentShaderFromString:(NSString *)secondStageFragmentShaderString;
{
    if (!(self = [self initWithFirstStageVertexShaderFromString:kGPUImageVertexShaderString firstStageFragmentShaderFromString:firstStageFragmentShaderString secondStageVertexShaderFromString:kGPUImageVertexShaderString secondStageFragmentShaderFromString:secondStageFragmentShaderString]))
    {
		return nil;
    }
    
    return self;
}

- (void)initializeSecondaryAttributes;
{
    [secondFilterProgram addAttribute:@"position"];
	[secondFilterProgram addAttribute:@"inputTextureCoordinate"];
}

#pragma mark -
#pragma mark Managing targets

- (GPUImageFramebuffer *)framebufferForOutput;
{
    return secondOutputFramebuffer;
}

- (void)removeOutputFramebuffer;
{
    secondOutputFramebuffer = nil;
}

#pragma mark -
#pragma mark Rendering

- (void)renderToTextureWithVertices:(const GLfloat *)vertices textureCoordinates:(const GLfloat *)textureCoordinates;
{
    NSAssert(NO, @"not implemented");
//    if (self.preventRendering)
//    {
//        [self.firstInputFramebuffer unlock];
//        return;
//    }
//    
//    [GPUImageContext setActiveShaderProgram:self.filterProgram];
//    
//    self.outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:[self sizeOfFBO] textureOptions:self.outputTextureOptions onlyTexture:NO];
//    [self.outputFramebuffer activateFramebuffer];
//    
//    [self setUniformsForProgramAtIndex:0];
//    
//    glClearColor(self.backgroundColorRed, self.backgroundColorGreen, self.backgroundColorBlue, self.backgroundColorAlpha);
//    glClear(GL_COLOR_BUFFER_BIT);
//    
//	glActiveTexture(GL_TEXTURE2);
//	glBindTexture(GL_TEXTURE_2D, [self.firstInputFramebuffer texture]);
//	
//	glUniform1i(self.filterInputTextureUniform, 2);
//    
//    glVertexAttribPointer(self.filterPositionAttribute, 2, GL_FLOAT, 0, 0, vertices);
//	glVertexAttribPointer(self.filterTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);
//    
//    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
//    
//    [self.firstInputFramebuffer unlock];
//    self.firstInputFramebuffer = nil;
//    
//    // This assumes that any two-pass filter that says it desires monochrome input is using the first pass for a luminance conversion, which can be dropped
////    if (!currentlyReceivingMonochromeInput)
////    {
//        // Run the first stage of the two-pass filter
////        [super renderToTextureWithVertices:vertices textureCoordinates:textureCoordinates];
////    }
//
//    // Run the second stage of the two-pass filter
//    secondOutputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:[self sizeOfFBO] textureOptions:self.outputTextureOptions onlyTexture:NO];
//    [secondOutputFramebuffer activateFramebuffer];
//    [GPUImageContext setActiveShaderProgram:secondFilterProgram];
//    if (self.usingNextFrameForImageCapture)
//    {
//        [secondOutputFramebuffer lock];
//    }
//
//    [self setUniformsForProgramAtIndex:1];
//    
//    glActiveTexture(GL_TEXTURE3);
//    glBindTexture(GL_TEXTURE_2D, [self.outputFramebuffer texture]);
//    glVertexAttribPointer(secondFilterTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, [[self class] textureCoordinatesForRotation:kGPUImageNoRotation]);
//
//    // TODO: Re-enable this monochrome optimization
////    if (!currentlyReceivingMonochromeInput)
////    {
////        glActiveTexture(GL_TEXTURE3);
////        glBindTexture(GL_TEXTURE_2D, outputTexture);
////        glVertexAttribPointer(secondFilterTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, [[self class] textureCoordinatesForRotation:kGPUImageNoRotation]);
////    }
////    else
////    {
////        glActiveTexture(GL_TEXTURE3);
////        glBindTexture(GL_TEXTURE_2D, sourceTexture);
////        glVertexAttribPointer(secondFilterTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);
////    }
//    
//	glUniform1i(secondFilterInputTextureUniform, 3);
//    
//    glVertexAttribPointer(secondFilterPositionAttribute, 2, GL_FLOAT, 0, 0, vertices);
//
//    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
//    glClear(GL_COLOR_BUFFER_BIT);
//
//    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
//    [self.outputFramebuffer unlock];
//    self.outputFramebuffer = nil;
//    
//    if (self.usingNextFrameForImageCapture)
//    {
//        dispatch_semaphore_signal(self.imageCaptureSemaphore);
//    }
}

- (void)setAndExecuteUniformStateCallbackAtIndex:(GLint)uniform forProgram:(GLProgram *)shaderProgram toBlock:(dispatch_block_t)uniformStateBlock;
{
// TODO: Deal with the fact that two-pass filters may have the same shader program identifier
    if (shaderProgram == self.filterProgram)
    {
        [self.uniformStateRestorationBlocks setObject:[uniformStateBlock copy] forKey:[NSNumber numberWithInt:uniform]];
    }
    else
    {
        [secondProgramUniformStateRestorationBlocks setObject:[uniformStateBlock copy] forKey:[NSNumber numberWithInt:uniform]];
    }
    uniformStateBlock();
}

- (void)setUniformsForProgramAtIndex:(NSUInteger)programIndex;
{
    if (programIndex == 0)
    {
        [self.uniformStateRestorationBlocks enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop){
            dispatch_block_t currentBlock = obj;
            currentBlock();
        }];
    }
    else
    {
        [secondProgramUniformStateRestorationBlocks enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop){
            dispatch_block_t currentBlock = obj;
            currentBlock();
        }];
    }
}

@end
