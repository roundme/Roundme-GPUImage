#import "GPUImageParallelCoordinateLineTransformFilter.h"

NSString *const kGPUImageHoughAccumulationVertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 
 void main()
 {
     gl_Position = position;
 }
);

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
NSString *const kGPUImageHoughAccumulationFragmentShaderString = SHADER_STRING
(
 const lowp float scalingFactor = 1.0 / 256.0;
 
 void main()
 {
     gl_FragColor = vec4(0.004, 0.004, 0.004, 1.0);
 }
);

// highp - 16-bit, floating point range: -2^62 to 2^62, integer range: -2^16 to 2^16
// NOTE: See below for where I'm tacking on the required extension as a prefix
NSString *const kGPUImageHoughAccumulationFBOReadFragmentShaderString = SHADER_STRING
(
// const lowp float scalingFactor = 0.004;
 const lowp float scalingFactor = 0.1;

 void main()
 {
     mediump vec4 fragmentData = gl_LastFragData[0];
     
     fragmentData.r = fragmentData.r + scalingFactor;
     fragmentData.g = scalingFactor * floor(fragmentData.r) + fragmentData.g;
     fragmentData.b = scalingFactor * floor(fragmentData.g) + fragmentData.b;
     fragmentData.a = scalingFactor * floor(fragmentData.b) + fragmentData.a;
     
     fragmentData = fract(fragmentData);
     
     gl_FragColor = vec4(fragmentData.rgb, 1.0);
 }
);

#else
NSString *const kGPUImageHoughAccumulationFragmentShaderString = SHADER_STRING
(
 const float scalingFactor = 1.0 / 256.0;
 
 void main()
 {
     gl_FragColor = vec4(0.004, 0.004, 0.004, 1.0);
 }
);

NSString *const kGPUImageHoughAccumulationFBOReadFragmentShaderString = SHADER_STRING
(
 const float scalingFactor = 1.0 / 256.0;
 
 void main()
 {
     //     gl_FragColor = vec4(scalingFactor, scalingFactor, scalingFactor, 1.0);
     gl_FragColor = vec4(0.004, 0.004, 0.004, 1.0);
 }
);
#endif

@interface GPUImageParallelCoordinateLineTransformFilter()
// Rendering
- (void)generateLineCoordinates;

@end

@implementation GPUImageParallelCoordinateLineTransformFilter

#pragma mark -
#pragma mark Initialization and teardown

- (id)init;
{
    NSString *fragmentShaderToUse = nil;
    
    if ([GPUImageContext deviceSupportsFramebufferReads])
    {
        fragmentShaderToUse = [NSString stringWithFormat:@"#extension GL_EXT_shader_framebuffer_fetch : require\n %@",kGPUImageHoughAccumulationFBOReadFragmentShaderString];
    }
    else
    {
        fragmentShaderToUse = kGPUImageHoughAccumulationFragmentShaderString;
    }

    if (!(self = [super initWithVertexShaderFromString:kGPUImageHoughAccumulationVertexShaderString fragmentShaderFromString:fragmentShaderToUse]))
    {
        return nil;
    }
    
    
    return self;
}

// TODO: have this be regenerated on change of image size
- (void)dealloc;
{
    free(rawImagePixels);
    free(lineCoordinates);
}

- (void)initializeAttributes;
{
    [self.filterProgram addAttribute:@"position"];
}

#pragma mark -
#pragma mark Rendering

#define MAXLINESCALINGFACTOR 4

- (void)generateLineCoordinates {
    CGSize inputSize = [self getInputSize:0];

    unsigned int imageByteSize = inputSize.width * inputSize.height * 4;
    rawImagePixels = (GLubyte *)malloc(imageByteSize);

    maxLinePairsToRender = (inputSize.width * inputSize.height) / MAXLINESCALINGFACTOR;
    lineCoordinates = calloc(maxLinePairsToRender * 8, sizeof(GLfloat));
}

- (void)newFrameReadyAtTime:(CMTime)frameTime atIndex:(NSInteger)textureIndex;
{
    if (lineCoordinates == NULL)
    {
        [self generateLineCoordinates];
    }
    
    [self renderToTextureWithVertices:NULL textureCoordinates:NULL];
    
    [self informTargetsAboutNewFrameAtTime:frameTime];
}

- (void)renderToTextureWithVertices:(const GLfloat *)vertices textureCoordinates:(const GLfloat *)textureCoordinates;
{
    // we need a normal color texture for this filter
    NSAssert(self.outputTextureOptions.internalFormat == GL_RGBA, @"The output texture format for this filter must be GL_RGBA.");
    NSAssert(self.outputTextureOptions.type == GL_UNSIGNED_BYTE, @"The type of the output texture of this filter must be GL_UNSIGNED_BYTE.");
    
    if (self.preventRendering)
    {
        [self unlockBuffers];
        return;
    }
    
    [GPUImageContext useImageProcessingContext];
    
    // Grab the edge points from the previous frame and create the parallel coordinate lines for them
    // This would be a great place to have a working histogram pyramid implementation
    glFinish();

    CGSize inputSize = [self getInputSize:0];
    glReadPixels(0, 0, inputSize.width, inputSize.height, GL_RGBA, GL_UNSIGNED_BYTE, rawImagePixels);
    
    GLfloat xAspectMultiplier = 1.0f, yAspectMultiplier = 1.0f;
    
//    if (self.inputTextureSize.width > self.inputTextureSize.height)
//    {
//        yAspectMultiplier = self.inputTextureSize.height / self.inputTextureSize.width;
//    }
//    else
//    {
//        xAspectMultiplier = self.inputTextureSize.width / self.inputTextureSize.height;
//    }
    
//    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    
    unsigned int imageByteSize = inputSize.width * inputSize.height * 4;
    unsigned int imageWidth = inputSize.width * 4;
    
    linePairsToRender = 0;
    unsigned int currentByte = 0;
    unsigned int lineStorageIndex = 0;
    unsigned int maxLineStorageIndex = maxLinePairsToRender * 8 - 8;
    
    GLfloat minY = 100, maxY = -100, minX = 100, maxX = -100;
    while (currentByte < imageByteSize)
    {
        GLubyte colorByte = rawImagePixels[currentByte];        
        
        if (colorByte > 0)
        {
            unsigned int xCoordinate = currentByte % imageWidth;
            unsigned int yCoordinate = currentByte / imageWidth;
            
            GLfloat normalizedXCoordinate = (-1.0f + 2.0f * (GLfloat)(xCoordinate / 4) / inputSize.width) * xAspectMultiplier;
            GLfloat normalizedYCoordinate = (-1.0f + 2.0f * (GLfloat)(yCoordinate) / inputSize.height) * yAspectMultiplier;
            
            minY = MIN(minY, normalizedYCoordinate);
            maxY = MAX(maxY, normalizedYCoordinate);
            minX = MIN(minX, normalizedXCoordinate);
            maxX = MAX(maxX, normalizedXCoordinate);
            
//            NSLog(@"Parallel line coordinates: (%f, %f) - (%f, %f) - (%f, %f)", -1.0f, -normalizedYCoordinate, 0.0f, normalizedXCoordinate, 1.0f, normalizedYCoordinate);
            // T space coordinates, (-d, -y) to (0, x)
            lineCoordinates[lineStorageIndex++] = -1.0f;
            lineCoordinates[lineStorageIndex++] = -normalizedYCoordinate;
            lineCoordinates[lineStorageIndex++] = 0.0f;
            lineCoordinates[lineStorageIndex++] = normalizedXCoordinate;

            // S space coordinates, (0, x) to (d, y)
            lineCoordinates[lineStorageIndex++] = 0.0f;
            lineCoordinates[lineStorageIndex++] = normalizedXCoordinate;
            lineCoordinates[lineStorageIndex++] = 1.0f;
            lineCoordinates[lineStorageIndex++] = normalizedYCoordinate;

            linePairsToRender++;
            
            linePairsToRender = MIN(linePairsToRender, maxLinePairsToRender);
            lineStorageIndex = MIN(lineStorageIndex, maxLineStorageIndex);
        }
        currentByte +=8;
    }
    
//    NSLog(@"Line pairs to render: %d out of max: %d", linePairsToRender, maxLinePairsToRender);
    
//    CFAbsoluteTime currentFrameTime = (CFAbsoluteTimeGetCurrent() - startTime);
//    NSLog(@"Line generation processing time : %f ms", 1000.0f * currentFrameTime);

    self.outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:[self sizeOfFBO] textureOptions:self.outputTextureOptions onlyTexture:NO];
    [self.outputFramebuffer activateFramebuffer];
    
    [GPUImageContext setActiveShaderProgram:self.filterProgram];
    
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    if (![GPUImageContext deviceSupportsFramebufferReads])
    {
        glBlendEquation(GL_FUNC_ADD);
        glBlendFunc(GL_ONE, GL_ONE);
        glEnable(GL_BLEND);
    }
    else
    {
        glLineWidth(1);
    }
    
	glVertexAttribPointer(self.filterPositionAttribute, 2, GL_FLOAT, 0, 0, lineCoordinates);
    glDrawArrays(GL_LINES, 0, (linePairsToRender * 4));
    
    if (![GPUImageContext deviceSupportsFramebufferReads])
    {
        glDisable(GL_BLEND);
    }
    [self unlockBuffers];
}

@end
