#import "GPUImageDirectionalNonMaximumSuppressionFilter.h"

@implementation GPUImageDirectionalNonMaximumSuppressionFilter

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
NSString *const kGPUImageDirectionalNonmaximumSuppressionFragmentShaderString = SHADER_STRING
(
 precision mediump float;
 
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 uniform highp float texelWidth; 
 uniform highp float texelHeight; 
 uniform mediump float upperThreshold; 
 uniform mediump float lowerThreshold; 

 void main()
 {
     vec3 currentGradientAndDirection = texture2D(inputImageTexture, textureCoordinate).rgb;
     vec2 gradientDirection = ((currentGradientAndDirection.gb * 2.0) - 1.0) * vec2(texelWidth, texelHeight);
     
     float firstSampledGradientMagnitude = texture2D(inputImageTexture, textureCoordinate + gradientDirection).r;
     float secondSampledGradientMagnitude = texture2D(inputImageTexture, textureCoordinate - gradientDirection).r;
     
     float multiplier = step(firstSampledGradientMagnitude, currentGradientAndDirection.r);
     multiplier = multiplier * step(secondSampledGradientMagnitude, currentGradientAndDirection.r);
     
     float thresholdCompliance = smoothstep(lowerThreshold, upperThreshold, currentGradientAndDirection.r);
     multiplier = multiplier * thresholdCompliance;
     
     gl_FragColor = vec4(multiplier, multiplier, multiplier, 1.0);
 }
);
#else
NSString *const kGPUImageDirectionalNonmaximumSuppressionFragmentShaderString = SHADER_STRING
(
 varying vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 uniform float texelWidth;
 uniform float texelHeight;
 uniform float upperThreshold;
 uniform float lowerThreshold;
 
 void main()
 {
     vec3 currentGradientAndDirection = texture2D(inputImageTexture, textureCoordinate).rgb;
     vec2 gradientDirection = ((currentGradientAndDirection.gb * 2.0) - 1.0) * vec2(texelWidth, texelHeight);
     
     float firstSampledGradientMagnitude = texture2D(inputImageTexture, textureCoordinate + gradientDirection).r;
     float secondSampledGradientMagnitude = texture2D(inputImageTexture, textureCoordinate - gradientDirection).r;
     
     float multiplier = step(firstSampledGradientMagnitude, currentGradientAndDirection.r);
     multiplier = multiplier * step(secondSampledGradientMagnitude, currentGradientAndDirection.r);
     
     float thresholdCompliance = smoothstep(lowerThreshold, upperThreshold, currentGradientAndDirection.r);
     multiplier = multiplier * thresholdCompliance;
     
     gl_FragColor = vec4(multiplier, multiplier, multiplier, 1.0);
 }
);
#endif

@synthesize texelWidth = _texelWidth; 
@synthesize texelHeight = _texelHeight; 
@synthesize upperThreshold = _upperThreshold;
@synthesize lowerThreshold = _lowerThreshold;

#pragma mark -
#pragma mark Initialization and teardown

- (id)init;
{
    if (!(self = [super initWithFragmentShaderFromString:kGPUImageDirectionalNonmaximumSuppressionFragmentShaderString]))
    {
        return nil;
    }
    
    texelWidthUniform = [self.filterProgram uniformIndex:@"texelWidth"];
    texelHeightUniform = [self.filterProgram uniformIndex:@"texelHeight"];
    upperThresholdUniform = [self.filterProgram uniformIndex:@"upperThreshold"];
    lowerThresholdUniform = [self.filterProgram uniformIndex:@"lowerThreshold"];
    
    self.upperThreshold = 0.5f;
    self.lowerThreshold = 0.1f;
    
    return self;
}

- (void)setupFilterForSize:(CGSize)filterFrameSize;
{
    if (!hasOverriddenImageSizeFactor)
    {
        _texelWidth = 1.0f / filterFrameSize.width;
        _texelHeight = 1.0f / filterFrameSize.height;
        
        runSynchronouslyOnVideoProcessingQueue(^{
            [GPUImageContext setActiveShaderProgram:self.filterProgram];
            glUniform1f(texelWidthUniform, _texelWidth);
            glUniform1f(texelHeightUniform, _texelHeight);
        });
    }
}

#pragma mark -
#pragma mark Accessors

- (void)setTexelWidth:(GLfloat)newValue;
{
    hasOverriddenImageSizeFactor = YES;
    _texelWidth = newValue;
    
    [self setFloat:_texelWidth forUniform:texelWidthUniform program:self.filterProgram];
}

- (void)setTexelHeight:(GLfloat)newValue;
{
    hasOverriddenImageSizeFactor = YES;
    _texelHeight = newValue;
    
    [self setFloat:_texelHeight forUniform:texelHeightUniform program:self.filterProgram];
}

- (void)setLowerThreshold:(GLfloat)newValue;
{
    _lowerThreshold = newValue;
    
    [self setFloat:_lowerThreshold forUniform:lowerThresholdUniform program:self.filterProgram];
}

- (void)setUpperThreshold:(GLfloat)newValue;
{
    _upperThreshold = newValue;

    [self setFloat:_upperThreshold forUniform:upperThresholdUniform program:self.filterProgram];
}



@end
