#import "GPUImageBulgeDistortionFilter.h"

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
NSString *const kGPUImageBulgeDistortionFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 uniform highp float aspectRatio;
 uniform highp vec2 center;
 uniform highp float radius;
 uniform highp float scale;

 void main()
 {
    highp vec2 textureCoordinateToUse = vec2(textureCoordinate.x, (textureCoordinate.y * aspectRatio + 0.5 - 0.5 * aspectRatio));
    highp float dist = distance(center, textureCoordinateToUse);
    textureCoordinateToUse = textureCoordinate;
    
    if (dist < radius)
    {
        textureCoordinateToUse -= center;
        highp float percent = 1.0 - ((radius - dist) / radius) * scale;
        percent = percent * percent;
        
        textureCoordinateToUse = textureCoordinateToUse * percent;
        textureCoordinateToUse += center;
    }
    
    gl_FragColor = texture2D(inputImageTexture, textureCoordinateToUse );    
 }
);
#else
NSString *const kGPUImageBulgeDistortionFragmentShaderString = SHADER_STRING
(
 varying vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 uniform float aspectRatio;
 uniform vec2 center;
 uniform float radius;
 uniform float scale;
 
 void main()
 {
    vec2 textureCoordinateToUse = vec2(textureCoordinate.x, (textureCoordinate.y * aspectRatio + 0.5 - 0.5 * aspectRatio));
    float dist = distance(center, textureCoordinateToUse);
    textureCoordinateToUse = textureCoordinate;
    
    if (dist < radius)
    {
        textureCoordinateToUse -= center;
        float percent = 1.0 - ((radius - dist) / radius) * scale;
        percent = percent * percent;
        
        textureCoordinateToUse = textureCoordinateToUse * percent;
        textureCoordinateToUse += center;
    }
    
    gl_FragColor = texture2D(inputImageTexture, textureCoordinateToUse );
 }
);
#endif


@interface GPUImageBulgeDistortionFilter ()

@property (readwrite, nonatomic) GLfloat aspectRatio;

@end

@implementation GPUImageBulgeDistortionFilter

@synthesize center = _center;
@synthesize radius = _radius;
@synthesize scale = _scale;

#pragma mark -
#pragma mark Initialization and teardown

- (id)init;
{
    if (!(self = [super initWithFragmentShaderFromString:kGPUImageBulgeDistortionFragmentShaderString]))
    {
		return nil;
    }
    
    aspectRatioUniform = [self.filterProgram uniformIndex:@"aspectRatio"];
    radiusUniform = [self.filterProgram uniformIndex:@"radius"];
    scaleUniform = [self.filterProgram uniformIndex:@"scale"];
    centerUniform = [self.filterProgram uniformIndex:@"center"];

    self.radius = 0.25;
    self.scale = 0.5;
    self.center = CGPointMake(0.5, 0.5);
    
    return self;
}

#pragma mark -
#pragma mark Accessors

- (void)setAspectRatio:(GLfloat)newValue {
    [self setFloat:newValue forUniform:aspectRatioUniform program:self.filterProgram];
}

- (void)setInputRotation:(GPUImageRotationMode)value index:(NSUInteger)index {
    [super setInputRotation:value index:index];
    [self setCenter:self.center];
}

- (void)setRadius:(GLfloat)newValue;
{
    _radius = newValue;
    
    [self setFloat:_radius forUniform:radiusUniform program:self.filterProgram];
}

- (void)setScale:(GLfloat)newValue;
{
    _scale = newValue;

    [self setFloat:_scale forUniform:scaleUniform program:self.filterProgram];
}

- (void)setCenter:(CGPoint)newValue {
    _center = newValue;
    [self setPoint:rotatedPoint(_center, [self getInputRotation:0]) forUniform:centerUniform program:self.filterProgram];
}

@end
