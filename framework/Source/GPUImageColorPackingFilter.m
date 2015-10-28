#import "GPUImageColorPackingFilter.h"

NSString *const kGPUImageColorPackingVertexShaderString = SHADER_STRING
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
NSString *const kGPUImageColorPackingFragmentShaderString = SHADER_STRING
(
 precision lowp float;
 
 uniform sampler2D inputImageTexture;
 
 uniform mediump mat3 convolutionMatrix;
 
 varying highp vec2 outputTextureCoordinate;
 
 varying highp vec2 upperLeftInputTextureCoordinate;
 varying highp vec2 upperRightInputTextureCoordinate;
 varying highp vec2 lowerLeftInputTextureCoordinate;
 varying highp vec2 lowerRightInputTextureCoordinate;
 
 void main()
 {
     float upperLeftIntensity = texture2D(inputImageTexture, upperLeftInputTextureCoordinate).r;
     float upperRightIntensity = texture2D(inputImageTexture, upperRightInputTextureCoordinate).r;
     float lowerLeftIntensity = texture2D(inputImageTexture, lowerLeftInputTextureCoordinate).r;
     float lowerRightIntensity = texture2D(inputImageTexture, lowerRightInputTextureCoordinate).r;
     
     gl_FragColor = vec4(upperLeftIntensity, upperRightIntensity, lowerLeftIntensity, lowerRightIntensity);
 }
);
#else
NSString *const kGPUImageColorPackingFragmentShaderString = SHADER_STRING
(
 uniform sampler2D inputImageTexture;
 
 uniform mat3 convolutionMatrix;
 
 varying vec2 outputTextureCoordinate;
 
 varying vec2 upperLeftInputTextureCoordinate;
 varying vec2 upperRightInputTextureCoordinate;
 varying vec2 lowerLeftInputTextureCoordinate;
 varying vec2 lowerRightInputTextureCoordinate;
 
 void main()
 {
     float upperLeftIntensity = texture2D(inputImageTexture, upperLeftInputTextureCoordinate).r;
     float upperRightIntensity = texture2D(inputImageTexture, upperRightInputTextureCoordinate).r;
     float lowerLeftIntensity = texture2D(inputImageTexture, lowerLeftInputTextureCoordinate).r;
     float lowerRightIntensity = texture2D(inputImageTexture, lowerRightInputTextureCoordinate).r;
     
     gl_FragColor = vec4(upperLeftIntensity, upperRightIntensity, lowerLeftIntensity, lowerRightIntensity);
 }
);
#endif

@implementation GPUImageColorPackingFilter

#pragma mark - Initialization and teardown

- (id)init {
    if ((self = [super initWithVertexShaderFromString:kGPUImageColorPackingVertexShaderString fragmentShaderFromString:kGPUImageColorPackingFragmentShaderString])) {
        texelWidthUniform = [self.filterProgram uniformIndex:@"texelWidth"];
        texelHeightUniform = [self.filterProgram uniformIndex:@"texelHeight"];
    }
    return self;
}

- (void)setupFilterForSize:(CGSize)filterFrameSize {
    CGSize inputSize = [self getInputSize:0];
    texelWidth = 0.5 / inputSize.width;
    texelHeight = 0.5 / inputSize.height;

    runSynchronouslyOnVideoProcessingQueue(^{
        [GPUImageContext setActiveShaderProgram:self.filterProgram];
        glUniform1f(texelWidthUniform, texelWidth);
        glUniform1f(texelHeightUniform, texelHeight);
    });
}

#pragma mark - Managing the display FBOs

- (CGSize)sizeOfFBO {
    CGSize outputSize = [self maximumOutputSize];
    CGSize inputSize = [self getInputSize:0];
    if ( (CGSizeEqualToSize(outputSize, CGSizeZero)) || (inputSize.width < outputSize.width)) {
        return CGSizeMake(inputSize.width / 2.0, inputSize.height / 2.0);
    } else {
        return outputSize;
    }
}

#pragma mark - Rendering

- (CGSize)outputFrameSize {
    CGSize inputSize = [self getInputSize:0];
    return CGSizeMake(inputSize.width / 2.0, inputSize.height / 2.0);;
}

@end
