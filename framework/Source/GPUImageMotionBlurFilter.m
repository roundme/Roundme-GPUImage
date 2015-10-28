#import "GPUImageMotionBlurFilter.h"

// Override vertex shader to remove dependent texture reads
NSString *const kGPUImageTiltedTexelSamplingVertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 
 uniform vec2 directionalTexelStep;
 
 varying vec2 textureCoordinate;
 varying vec2 oneStepBackTextureCoordinate;
 varying vec2 twoStepsBackTextureCoordinate;
 varying vec2 threeStepsBackTextureCoordinate;
 varying vec2 fourStepsBackTextureCoordinate;
 varying vec2 oneStepForwardTextureCoordinate;
 varying vec2 twoStepsForwardTextureCoordinate;
 varying vec2 threeStepsForwardTextureCoordinate;
 varying vec2 fourStepsForwardTextureCoordinate;
 
 void main()
 {
     gl_Position = position;
     
     textureCoordinate = inputTextureCoordinate.xy;
     oneStepBackTextureCoordinate = inputTextureCoordinate.xy - directionalTexelStep;
     twoStepsBackTextureCoordinate = inputTextureCoordinate.xy - 2.0 * directionalTexelStep;
     threeStepsBackTextureCoordinate = inputTextureCoordinate.xy - 3.0 * directionalTexelStep;
     fourStepsBackTextureCoordinate = inputTextureCoordinate.xy - 4.0 * directionalTexelStep;
     oneStepForwardTextureCoordinate = inputTextureCoordinate.xy + directionalTexelStep;
     twoStepsForwardTextureCoordinate = inputTextureCoordinate.xy + 2.0 * directionalTexelStep;
     threeStepsForwardTextureCoordinate = inputTextureCoordinate.xy + 3.0 * directionalTexelStep;
     fourStepsForwardTextureCoordinate = inputTextureCoordinate.xy + 4.0 * directionalTexelStep;
 }
);

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
NSString *const kGPUImageMotionBlurFragmentShaderString = SHADER_STRING
(
 precision highp float;
 
 uniform sampler2D inputImageTexture;
 
 varying vec2 textureCoordinate;
 varying vec2 oneStepBackTextureCoordinate;
 varying vec2 twoStepsBackTextureCoordinate;
 varying vec2 threeStepsBackTextureCoordinate;
 varying vec2 fourStepsBackTextureCoordinate;
 varying vec2 oneStepForwardTextureCoordinate;
 varying vec2 twoStepsForwardTextureCoordinate;
 varying vec2 threeStepsForwardTextureCoordinate;
 varying vec2 fourStepsForwardTextureCoordinate;
 
 void main()
 {
     // Box weights
//     lowp vec4 fragmentColor = texture2D(inputImageTexture, textureCoordinate) * 0.1111111;
//     fragmentColor += texture2D(inputImageTexture, oneStepBackTextureCoordinate) * 0.1111111;
//     fragmentColor += texture2D(inputImageTexture, twoStepsBackTextureCoordinate) * 0.1111111;
//     fragmentColor += texture2D(inputImageTexture, threeStepsBackTextureCoordinate) * 0.1111111;
//     fragmentColor += texture2D(inputImageTexture, fourStepsBackTextureCoordinate) * 0.1111111;
//     fragmentColor += texture2D(inputImageTexture, oneStepForwardTextureCoordinate) * 0.1111111;
//     fragmentColor += texture2D(inputImageTexture, twoStepsForwardTextureCoordinate) * 0.1111111;
//     fragmentColor += texture2D(inputImageTexture, threeStepsForwardTextureCoordinate) * 0.1111111;
//     fragmentColor += texture2D(inputImageTexture, fourStepsForwardTextureCoordinate) * 0.1111111;

     lowp vec4 fragmentColor = texture2D(inputImageTexture, textureCoordinate) * 0.18;
     fragmentColor += texture2D(inputImageTexture, oneStepBackTextureCoordinate) * 0.15;
     fragmentColor += texture2D(inputImageTexture, twoStepsBackTextureCoordinate) *  0.12;
     fragmentColor += texture2D(inputImageTexture, threeStepsBackTextureCoordinate) * 0.09;
     fragmentColor += texture2D(inputImageTexture, fourStepsBackTextureCoordinate) * 0.05;
     fragmentColor += texture2D(inputImageTexture, oneStepForwardTextureCoordinate) * 0.15;
     fragmentColor += texture2D(inputImageTexture, twoStepsForwardTextureCoordinate) *  0.12;
     fragmentColor += texture2D(inputImageTexture, threeStepsForwardTextureCoordinate) * 0.09;
     fragmentColor += texture2D(inputImageTexture, fourStepsForwardTextureCoordinate) * 0.05;

     gl_FragColor = fragmentColor;
 }
);
#else
NSString *const kGPUImageMotionBlurFragmentShaderString = SHADER_STRING
(
 uniform sampler2D inputImageTexture;
 
 varying vec2 textureCoordinate;
 varying vec2 oneStepBackTextureCoordinate;
 varying vec2 twoStepsBackTextureCoordinate;
 varying vec2 threeStepsBackTextureCoordinate;
 varying vec2 fourStepsBackTextureCoordinate;
 varying vec2 oneStepForwardTextureCoordinate;
 varying vec2 twoStepsForwardTextureCoordinate;
 varying vec2 threeStepsForwardTextureCoordinate;
 varying vec2 fourStepsForwardTextureCoordinate;
 
 void main()
 {
     // Box weights
     //     vec4 fragmentColor = texture2D(inputImageTexture, textureCoordinate) * 0.1111111;
     //     fragmentColor += texture2D(inputImageTexture, oneStepBackTextureCoordinate) * 0.1111111;
     //     fragmentColor += texture2D(inputImageTexture, twoStepsBackTextureCoordinate) * 0.1111111;
     //     fragmentColor += texture2D(inputImageTexture, threeStepsBackTextureCoordinate) * 0.1111111;
     //     fragmentColor += texture2D(inputImageTexture, fourStepsBackTextureCoordinate) * 0.1111111;
     //     fragmentColor += texture2D(inputImageTexture, oneStepForwardTextureCoordinate) * 0.1111111;
     //     fragmentColor += texture2D(inputImageTexture, twoStepsForwardTextureCoordinate) * 0.1111111;
     //     fragmentColor += texture2D(inputImageTexture, threeStepsForwardTextureCoordinate) * 0.1111111;
     //     fragmentColor += texture2D(inputImageTexture, fourStepsForwardTextureCoordinate) * 0.1111111;
     
     vec4 fragmentColor = texture2D(inputImageTexture, textureCoordinate) * 0.18;
     fragmentColor += texture2D(inputImageTexture, oneStepBackTextureCoordinate) * 0.15;
     fragmentColor += texture2D(inputImageTexture, twoStepsBackTextureCoordinate) *  0.12;
     fragmentColor += texture2D(inputImageTexture, threeStepsBackTextureCoordinate) * 0.09;
     fragmentColor += texture2D(inputImageTexture, fourStepsBackTextureCoordinate) * 0.05;
     fragmentColor += texture2D(inputImageTexture, oneStepForwardTextureCoordinate) * 0.15;
     fragmentColor += texture2D(inputImageTexture, twoStepsForwardTextureCoordinate) *  0.12;
     fragmentColor += texture2D(inputImageTexture, threeStepsForwardTextureCoordinate) * 0.09;
     fragmentColor += texture2D(inputImageTexture, fourStepsForwardTextureCoordinate) * 0.05;
     
     gl_FragColor = fragmentColor;
 }
);
#endif

@interface GPUImageMotionBlurFilter()
{
    GLint directionalTexelStepUniform;
}

- (void)recalculateTexelOffsets;

@end

@implementation GPUImageMotionBlurFilter

#pragma mark - Initialization and teardown

- (id)init;
{
    if (!(self = [super initWithVertexShaderFromString:kGPUImageTiltedTexelSamplingVertexShaderString fragmentShaderFromString:kGPUImageMotionBlurFragmentShaderString]))
    {
        return nil;
    }
    
    directionalTexelStepUniform = [self.filterProgram uniformIndex:@"directionalTexelStep"];
    
    self.blurSize = 2.5;
    self.blurAngle = 0.0;
    
    return self;
}

- (void)setInputSize:(CGSize)value index:(NSUInteger)index {
    CGSize oldInputSize = [self getInputSize:0];
    [super setInputSize:value index:index];
    
    if (!CGSizeEqualToSize(oldInputSize, [self getInputSize:0]) && (!CGSizeEqualToSize(value, CGSizeZero))) {
        [self recalculateTexelOffsets];
    }
}

- (void)recalculateTexelOffsets {
    GLfloat aspectRatio = 1.0;
    CGPoint texelOffsets;
    CGSize inputSize = [self getInputSize:0];
    if (GPUImageRotationSwapsWidthAndHeight([self getInputRotation:0])) {
        aspectRatio = (inputSize.width / inputSize.height);
        texelOffsets.x = self.blurSize * sinf(self.blurAngle * M_PI / 180.0f) * aspectRatio / inputSize.height;
        texelOffsets.y = self.blurSize * cosf(self.blurAngle * M_PI / 180.0f) / inputSize.height;
    } else {
        aspectRatio = (inputSize.height / inputSize.width);
        texelOffsets.x = self.blurSize * cosf(self.blurAngle * M_PI / 180.0f) * aspectRatio / inputSize.width;
        texelOffsets.y = self.blurSize * sinf(self.blurAngle * M_PI / 180.0f) / inputSize.width;
    }
    [self setPoint:texelOffsets forUniform:directionalTexelStepUniform program:self.filterProgram];
}

#pragma mark - Accessors

- (void)setInputRotation:(GPUImageRotationMode)value index:(NSUInteger)index {
    [super setInputRotation:value index:index];
    [self recalculateTexelOffsets];
}

- (void)setBlurAngle:(GLfloat)newValue {
    self.blurAngle = newValue;
    [self recalculateTexelOffsets];
}

- (void)setBlurSize:(GLfloat)newValue {
    self.blurSize = newValue;
    [self recalculateTexelOffsets];
}


@end
