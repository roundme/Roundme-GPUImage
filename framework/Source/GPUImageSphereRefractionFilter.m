#import "GPUImageSphereRefractionFilter.h"

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
NSString *const kGPUImageSphereRefractionFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 uniform highp vec2 center;
 uniform highp float radius;
 uniform highp float aspectRatio;
 uniform highp float refractiveIndex;
 
 void main()
 {
     highp vec2 textureCoordinateToUse = vec2(textureCoordinate.x, (textureCoordinate.y * aspectRatio + 0.5 - 0.5 * aspectRatio));
     highp float distanceFromCenter = distance(center, textureCoordinateToUse);
     lowp float checkForPresenceWithinSphere = step(distanceFromCenter, radius);
     
     distanceFromCenter = distanceFromCenter / radius;
     
     highp float normalizedDepth = radius * sqrt(1.0 - distanceFromCenter * distanceFromCenter);
     highp vec3 sphereNormal = normalize(vec3(textureCoordinateToUse - center, normalizedDepth));
     
     highp vec3 refractedVector = refract(vec3(0.0, 0.0, -1.0), sphereNormal, refractiveIndex);
     
     gl_FragColor = texture2D(inputImageTexture, (refractedVector.xy + 1.0) * 0.5) * checkForPresenceWithinSphere;     
 }
);
#else
NSString *const kGPUImageSphereRefractionFragmentShaderString = SHADER_STRING
(
 varying vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 uniform vec2 center;
 uniform float radius;
 uniform float aspectRatio;
 uniform float refractiveIndex;
 
 void main()
 {
     vec2 textureCoordinateToUse = vec2(textureCoordinate.x, (textureCoordinate.y * aspectRatio + 0.5 - 0.5 * aspectRatio));
     float distanceFromCenter = distance(center, textureCoordinateToUse);
     float checkForPresenceWithinSphere = step(distanceFromCenter, radius);
     
     distanceFromCenter = distanceFromCenter / radius;
     
     float normalizedDepth = radius * sqrt(1.0 - distanceFromCenter * distanceFromCenter);
     vec3 sphereNormal = normalize(vec3(textureCoordinateToUse - center, normalizedDepth));
     
     vec3 refractedVector = refract(vec3(0.0, 0.0, -1.0), sphereNormal, refractiveIndex);
     
     gl_FragColor = texture2D(inputImageTexture, (refractedVector.xy + 1.0) * 0.5) * checkForPresenceWithinSphere;
 }
);
#endif

@interface GPUImageSphereRefractionFilter ()

@property (readwrite, nonatomic) GLfloat aspectRatio;

@end


@implementation GPUImageSphereRefractionFilter

#pragma mark -
#pragma mark Initialization and teardown

- (id)init;
{
    if (!(self = [self initWithFragmentShaderFromString:kGPUImageSphereRefractionFragmentShaderString]))
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
    
    radiusUniform = [self.filterProgram uniformIndex:@"radius"];
    aspectRatioUniform = [self.filterProgram uniformIndex:@"aspectRatio"];
    centerUniform = [self.filterProgram uniformIndex:@"center"];
    refractiveIndexUniform = [self.filterProgram uniformIndex:@"refractiveIndex"];
    
    self.radius = 0.25;
    self.center = CGPointMake(0.5, 0.5);
    self.refractiveIndex = 0.71;
    
    [self setBackgroundColorRed:0.0 green:0.0 blue:0.0 alpha:0.0];
    
    return self;
}

#pragma mark - Accessors

- (void)setInputRotation:(GPUImageRotationMode)value index:(NSUInteger)index {
    [super setInputRotation:value index:index];
    [self setCenter:self.center];
}

- (void)setRadius:(GLfloat)newValue;
{
    _radius = newValue;
    
    [self setFloat:_radius forUniform:radiusUniform program:self.filterProgram];
}

- (void)setCenter:(CGPoint)newValue {
    _center = newValue;
    [self setPoint:rotatedPoint(_center, [self getInputRotation:0]) forUniform:centerUniform program:self.filterProgram];
}

- (void)setAspectRatio:(GLfloat)newValue {
    [self setFloat:newValue forUniform:aspectRatioUniform program:self.filterProgram];
}

- (void)setRefractiveIndex:(GLfloat)newValue;
{
    _refractiveIndex = newValue;

    [self setFloat:_refractiveIndex forUniform:refractiveIndexUniform program:self.filterProgram];
}

@end
