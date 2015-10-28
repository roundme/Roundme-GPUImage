#import "GPUImagePixellatePositionFilter.h"

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
NSString *const kGPUImagePixellationPositionFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 uniform highp float fractionalWidthOfPixel;
 uniform highp float aspectRatio;
 uniform lowp vec2 pixelateCenter;
 uniform highp float pixelateRadius;
 
 void main()
 {
     highp vec2 textureCoordinateToUse = vec2(textureCoordinate.x, (textureCoordinate.y * aspectRatio + 0.5 - 0.5 * aspectRatio));
     highp float dist = distance(pixelateCenter, textureCoordinateToUse);

     if (dist < pixelateRadius)
     {
         highp vec2 sampleDivisor = vec2(fractionalWidthOfPixel, fractionalWidthOfPixel / aspectRatio);
         highp vec2 samplePos = textureCoordinate - mod(textureCoordinate, sampleDivisor) + 0.5 * sampleDivisor;
         gl_FragColor = texture2D(inputImageTexture, samplePos );
     }
     else
     {
         gl_FragColor = texture2D(inputImageTexture, textureCoordinate );
     }
 }
);
#else
NSString *const kGPUImagePixellationPositionFragmentShaderString = SHADER_STRING
(
 varying vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 uniform float fractionalWidthOfPixel;
 uniform float aspectRatio;
 uniform vec2 pixelateCenter;
 uniform float pixelateRadius;
 
 void main()
 {
     vec2 textureCoordinateToUse = vec2(textureCoordinate.x, (textureCoordinate.y * aspectRatio + 0.5 - 0.5 * aspectRatio));
     float dist = distance(pixelateCenter, textureCoordinateToUse);
     
     if (dist < pixelateRadius)
     {
         vec2 sampleDivisor = vec2(fractionalWidthOfPixel, fractionalWidthOfPixel / aspectRatio);
         vec2 samplePos = textureCoordinate - mod(textureCoordinate, sampleDivisor) + 0.5 * sampleDivisor;
         gl_FragColor = texture2D(inputImageTexture, samplePos );
     }
     else
     {
         gl_FragColor = texture2D(inputImageTexture, textureCoordinate );
     }
 }
);
#endif

@interface GPUImagePixellatePositionFilter ()

@property (readwrite, nonatomic) GLfloat aspectRatio;

@end

@implementation GPUImagePixellatePositionFilter

#pragma mark -
#pragma mark Initialization and teardown

- (id)init;
{
    if (!(self = [self initWithFragmentShaderFromString:kGPUImagePixellationPositionFragmentShaderString]))
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
    centerUniform = [self.filterProgram uniformIndex:@"pixelateCenter"];
    radiusUniform = [self.filterProgram uniformIndex:@"pixelateRadius"];
    
    self.fractionalWidthOfAPixel = 0.05;
    self.center = CGPointMake(0.5f, 0.5f);
    self.radius = 0.25f;
    
    return self;
}

#pragma mark -
#pragma mark Accessors

- (void)setInputRotation:(GPUImageRotationMode)value index:(NSUInteger)index {
    [super setInputRotation:value index:index];
    [self setCenter:self.center];
}

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

- (void)setCenter:(CGPoint)center {
    _center = center;
    [self setPoint:rotatedPoint(_center, [self getInputRotation:0]) forUniform:centerUniform program:self.filterProgram];
}

- (void)setRadius:(GLfloat)radius
{
    _radius = radius;
    
    [self setFloat:_radius forUniform:radiusUniform program:self.filterProgram];
}

@end
