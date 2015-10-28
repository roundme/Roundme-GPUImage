#import "GPUImageAverageColor.h"

NSString *const kGPUImageColorAveragingVertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 
 uniform float texelWidth;
 uniform float texelHeight;
 
 varying vec2 upperLeftInputTextureCoordinate;
 varying vec2 upperRightInputTextureCoordinate;
 varying vec2 lowerLeftInputTextureCoordinate;
 varying vec2 lowerRightInputTextureCoordinate;
 
 void main()
 {
     gl_Position = position;
     
     upperLeftInputTextureCoordinate = inputTextureCoordinate.xy + vec2(-texelWidth, -texelHeight);
     upperRightInputTextureCoordinate = inputTextureCoordinate.xy + vec2(texelWidth, -texelHeight);
     lowerLeftInputTextureCoordinate = inputTextureCoordinate.xy + vec2(-texelWidth, texelHeight);
     lowerRightInputTextureCoordinate = inputTextureCoordinate.xy + vec2(texelWidth, texelHeight);
 }
 );

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
NSString *const kGPUImageColorAveragingFragmentShaderString = SHADER_STRING
(
 precision highp float;
 
 uniform sampler2D inputImageTexture;
 
 varying highp vec2 outputTextureCoordinate;
 
 varying highp vec2 upperLeftInputTextureCoordinate;
 varying highp vec2 upperRightInputTextureCoordinate;
 varying highp vec2 lowerLeftInputTextureCoordinate;
 varying highp vec2 lowerRightInputTextureCoordinate;
 
 void main()
 {
     highp vec4 upperLeftColor = texture2D(inputImageTexture, upperLeftInputTextureCoordinate);
     highp vec4 upperRightColor = texture2D(inputImageTexture, upperRightInputTextureCoordinate);
     highp vec4 lowerLeftColor = texture2D(inputImageTexture, lowerLeftInputTextureCoordinate);
     highp vec4 lowerRightColor = texture2D(inputImageTexture, lowerRightInputTextureCoordinate);
     
     gl_FragColor = 0.25 * (upperLeftColor + upperRightColor + lowerLeftColor + lowerRightColor);
 }
);
#else
NSString *const kGPUImageColorAveragingFragmentShaderString = SHADER_STRING
(
 uniform sampler2D inputImageTexture;
 
 varying vec2 outputTextureCoordinate;
 
 varying vec2 upperLeftInputTextureCoordinate;
 varying vec2 upperRightInputTextureCoordinate;
 varying vec2 lowerLeftInputTextureCoordinate;
 varying vec2 lowerRightInputTextureCoordinate;
 
 void main()
 {
     vec4 upperLeftColor = texture2D(inputImageTexture, upperLeftInputTextureCoordinate);
     vec4 upperRightColor = texture2D(inputImageTexture, upperRightInputTextureCoordinate);
     vec4 lowerLeftColor = texture2D(inputImageTexture, lowerLeftInputTextureCoordinate);
     vec4 lowerRightColor = texture2D(inputImageTexture, lowerRightInputTextureCoordinate);
     
     gl_FragColor = 0.25 * (upperLeftColor + upperRightColor + lowerLeftColor + lowerRightColor);
 }
);
#endif

@implementation GPUImageAverageColor

@synthesize colorAverageProcessingFinishedBlock = _colorAverageProcessingFinishedBlock;

#pragma mark -
#pragma mark Initialization and teardown

- (id)init;
{
    if (!(self = [super initWithVertexShaderFromString:kGPUImageColorAveragingVertexShaderString fragmentShaderFromString:kGPUImageColorAveragingFragmentShaderString]))
    {
        return nil;
    }
    
    texelWidthUniform = [self.filterProgram uniformIndex:@"texelWidth"];
    texelHeightUniform = [self.filterProgram uniformIndex:@"texelHeight"];
    finalStageSize = CGSizeMake(1.0, 1.0);
    
    __unsafe_unretained GPUImageAverageColor *weakSelf = self;
    [self setFrameProcessingCompletionBlock:^(GPUImageOutput *filter, CMTime frameTime) {
        [weakSelf extractAverageColorAtFrameTime:frameTime];
    }];

    return self;
}

- (void)dealloc;
{
    if (rawImagePixels != NULL)
    {
        free(rawImagePixels);
    }
}

#pragma mark -
#pragma mark Managing the display FBOs

- (void)renderToTextureWithVertices:(const GLfloat *)vertices textureCoordinates:(const GLfloat *)textureCoordinates;
{
    if (self.preventRendering) {
        [self unlockBuffers];
        return;
    }
    
    self.outputFramebuffer = nil;
    [GPUImageContext setActiveShaderProgram:self.filterProgram];

    glVertexAttribPointer(self.filterPositionAttribute, 2, GL_FLOAT, 0, 0, vertices);
    glVertexAttribPointer([self getInputTextureCoordinateAttribute:0], 2, GL_FLOAT, 0, 0, textureCoordinates);

    GLuint currentTexture = [[self getInputFramebuffer:0] texture];

    CGSize inputSize = [self getInputSize:0];
    NSUInteger numberOfReductionsInX = floor(logf(inputSize.width) / logf(4.0f));
    NSUInteger numberOfReductionsInY = floor(logf(inputSize.height) / logf(4.0f));
    NSUInteger reductionsToHitSideLimit = MIN(numberOfReductionsInX, numberOfReductionsInY);
    for (NSUInteger currentReduction = 0; currentReduction < reductionsToHitSideLimit; currentReduction++)
    {
        CGSize currentStageSize = CGSizeMake(floor(inputSize.width / powf(4.0f, currentReduction + 1.0f)), floor(inputSize.height / powf(4.0f, currentReduction + 1.0f)));
        if ( (currentStageSize.height < 2.0f) || (currentStageSize.width < 2.0f) )
        {
            // A really small last stage seems to cause significant errors in the average, so I abort and leave the rest to the CPU at this point
            break;
            //                currentStageSize.height = 2.0; // TODO: Rotate the image to account for this case, which causes FBO construction to fail
        }

        [self.outputFramebuffer unlock];
        self.outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:currentStageSize textureOptions:self.outputTextureOptions onlyTexture:NO];
        [self.outputFramebuffer activateFramebuffer];

        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        
        glActiveTexture(GL_TEXTURE2);
        glBindTexture(GL_TEXTURE_2D, currentTexture);
        
        glUniform1i([self getInputTextureUniform:0], 2);
        
        glUniform1f(texelWidthUniform, 0.5f / currentStageSize.width);
        glUniform1f(texelHeightUniform, 0.5f / currentStageSize.height);
        
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

        currentTexture = [self.outputFramebuffer texture];
        finalStageSize = currentStageSize;
    }

    [self unlockBuffers];
}

- (void)extractAverageColorAtFrameTime:(CMTime)frameTime;
{
    runSynchronouslyOnVideoProcessingQueue(^{
        // we need a normal color texture for averaging the color values
        NSAssert(self.outputTextureOptions.internalFormat == GL_RGBA, @"The output texture internal format for this filter must be GL_RGBA.");
        NSAssert(self.outputTextureOptions.type == GL_UNSIGNED_BYTE, @"The type of the output texture of this filter must be GL_UNSIGNED_BYTE.");
        
        NSUInteger totalNumberOfPixels = roundf(finalStageSize.width * finalStageSize.height);
        
        if (rawImagePixels == NULL)
        {
            rawImagePixels = (GLubyte *)malloc(totalNumberOfPixels * 4);
        }
        
        [GPUImageContext useImageProcessingContext];
        [self.outputFramebuffer activateFramebuffer];
        glReadPixels(0, 0, (int)finalStageSize.width, (int)finalStageSize.height, GL_RGBA, GL_UNSIGNED_BYTE, rawImagePixels);
        
        NSUInteger redTotal = 0, greenTotal = 0, blueTotal = 0, alphaTotal = 0;
        NSUInteger byteIndex = 0;
        for (NSUInteger currentPixel = 0; currentPixel < totalNumberOfPixels; currentPixel++)
        {
            redTotal += rawImagePixels[byteIndex++];
            greenTotal += rawImagePixels[byteIndex++];
            blueTotal += rawImagePixels[byteIndex++];
            alphaTotal += rawImagePixels[byteIndex++];
        }
        
        GLfloat normalizedRedTotal = (GLfloat)redTotal / (GLfloat)totalNumberOfPixels / 255.0f;
        GLfloat normalizedGreenTotal = (GLfloat)greenTotal / (GLfloat)totalNumberOfPixels / 255.0f;
        GLfloat normalizedBlueTotal = (GLfloat)blueTotal / (GLfloat)totalNumberOfPixels / 255.0f;
        GLfloat normalizedAlphaTotal = (GLfloat)alphaTotal / (GLfloat)totalNumberOfPixels / 255.0f;
        
        if (_colorAverageProcessingFinishedBlock != NULL)
        {
            _colorAverageProcessingFinishedBlock(normalizedRedTotal, normalizedGreenTotal, normalizedBlueTotal, normalizedAlphaTotal, frameTime);
        }
    });
}

@end
