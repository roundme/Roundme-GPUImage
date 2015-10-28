#import "GPUImageStretchDistortionFilter.h"

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
NSString *const kGPUImageStretchDistortionFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 uniform highp vec2 center;
 
 void main()
 {
     highp vec2 normCoord = 2.0 * textureCoordinate - 1.0;
     highp vec2 normCenter = 2.0 * center - 1.0;
     
     normCoord -= normCenter;
     mediump vec2 s = sign(normCoord);
     normCoord = abs(normCoord);
     normCoord = 0.5 * normCoord + 0.5 * smoothstep(0.25, 0.5, normCoord) * normCoord;
     normCoord = s * normCoord;
     
     normCoord += normCenter;
        
     mediump vec2 textureCoordinateToUse = normCoord / 2.0 + 0.5;
     
     
     gl_FragColor = texture2D(inputImageTexture, textureCoordinateToUse );
     
 }
);
#else
NSString *const kGPUImageStretchDistortionFragmentShaderString = SHADER_STRING
(
 varying vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 uniform vec2 center;
 
 void main()
 {
     vec2 normCoord = 2.0 * textureCoordinate - 1.0;
     vec2 normCenter = 2.0 * center - 1.0;
     
     normCoord -= normCenter;
     vec2 s = sign(normCoord);
     normCoord = abs(normCoord);
     normCoord = 0.5 * normCoord + 0.5 * smoothstep(0.25, 0.5, normCoord) * normCoord;
     normCoord = s * normCoord;
     
     normCoord += normCenter;
     
     vec2 textureCoordinateToUse = normCoord / 2.0 + 0.5;
     
     gl_FragColor = texture2D(inputImageTexture, textureCoordinateToUse);
 }
);
#endif

@implementation GPUImageStretchDistortionFilter

@synthesize center = _center;

#pragma mark -
#pragma mark Initialization and teardown

- (id)init;
{
    if (!(self = [super initWithFragmentShaderFromString:kGPUImageStretchDistortionFragmentShaderString]))
    {
		return nil;
    }
    
    centerUniform = [self.filterProgram uniformIndex:@"center"];
    
    self.center = CGPointMake(0.5, 0.5);
    
    return self;
}

#pragma mark -
#pragma mark Accessors

- (void)setInputRotation:(GPUImageRotationMode)value index:(NSUInteger)index {
    [super setInputRotation:value index:index];
    [self setCenter:self.center];
}

- (void)setCenter:(CGPoint)newValue {
    _center = newValue;
    [self setPoint:rotatedPoint(_center, [self getInputRotation:0]) forUniform:centerUniform program:self.filterProgram];
}

@end
