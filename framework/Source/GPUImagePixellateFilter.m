#import "GPUImagePixellateFilter.h"

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
NSString *const kGPUImagePixellationFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 uniform highp float fractionalWidthOfPixel;
 uniform highp float aspectRatio;

 void main()
 {
     highp vec2 sampleDivisor = vec2(fractionalWidthOfPixel, fractionalWidthOfPixel / aspectRatio);
     
     highp vec2 samplePos = textureCoordinate - mod(textureCoordinate, sampleDivisor) + 0.5 * sampleDivisor;
     gl_FragColor = texture2D(inputImageTexture, samplePos );
 }
);
#else
NSString *const kGPUImagePixellationFragmentShaderString = SHADER_STRING
(
 varying vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 uniform float fractionalWidthOfPixel;
 uniform float aspectRatio;
 
 void main()
 {
     vec2 sampleDivisor = vec2(fractionalWidthOfPixel, fractionalWidthOfPixel / aspectRatio);
     
     vec2 samplePos = textureCoordinate - mod(textureCoordinate, sampleDivisor) + 0.5 * sampleDivisor;
     gl_FragColor = texture2D(inputImageTexture, samplePos );
 }
);
#endif

@interface GPUImagePixellateFilter ()

@property (readwrite, nonatomic) GLfloat aspectRatio;

@end

@implementation GPUImagePixellateFilter

#pragma mark -
#pragma mark Initialization and teardown

- (id)init;
{
    if (!(self = [self initWithFragmentShaderFromString:kGPUImagePixellationFragmentShaderString]))
    {
		return nil;
    }
    
    return self;
}

- (id)initWithFragmentShaderFromString:(NSString *)fragmentShaderString;
{
    if (!(self = [super initWithFragmentShaderFromString:fragmentShaderString]))
    {
		return nil;
    }
    
    fractionalWidthOfAPixelUniform = [self.filterProgram uniformIndex:@"fractionalWidthOfPixel"];
    aspectRatioUniform = [self.filterProgram uniformIndex:@"aspectRatio"];

    self.fractionalWidthOfAPixel = 0.05;
    
    return self;
}

#pragma mark -
#pragma mark Accessors

- (void)setFractionalWidthOfAPixel:(GLfloat)newValue {
    GLfloat singlePixelSpacing;
    CGSize inputSize = [self getInputSize:0];
    if (inputSize.width != 0.0) {
        singlePixelSpacing = 1.0 / inputSize.width;
    } else {
        singlePixelSpacing = 1.0 / 2048.0;
    }
    
    if (newValue < singlePixelSpacing) {
        _fractionalWidthOfAPixel = singlePixelSpacing;
    } else {
        _fractionalWidthOfAPixel = newValue;
    }
    
    [self setFloat:_fractionalWidthOfAPixel forUniform:fractionalWidthOfAPixelUniform program:self.filterProgram];
}

- (void)setAspectRatio:(GLfloat)newValue {
    [self setFloat:newValue forUniform:aspectRatioUniform program:self.filterProgram];
}

@end
