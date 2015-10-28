#import "GPUImagePolarPixellateFilter.h"

// @fattjake based on vid by toneburst

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
NSString *const kGPUImagePolarPixellateFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 uniform highp vec2 center;
 uniform highp vec2 pixelSize;

 
 void main()
 {
     highp vec2 normCoord = 2.0 * textureCoordinate - 1.0;
     highp vec2 normCenter = 2.0 * center - 1.0;
     
     normCoord -= normCenter;
     
     highp float r = length(normCoord); // to polar coords 
     highp float phi = atan(normCoord.y, normCoord.x); // to polar coords 
     
     r = r - mod(r, pixelSize.x) + 0.03;
     phi = phi - mod(phi, pixelSize.y);
           
     normCoord.x = r * cos(phi);
     normCoord.y = r * sin(phi);
      
     normCoord += normCenter;
     
     mediump vec2 textureCoordinateToUse = normCoord / 2.0 + 0.5;
     
     gl_FragColor = texture2D(inputImageTexture, textureCoordinateToUse );
     
 }
);
#else
NSString *const kGPUImagePolarPixellateFragmentShaderString = SHADER_STRING
(
 varying vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 uniform vec2 center;
 uniform vec2 pixelSize;
 
 
 void main()
 {
     vec2 normCoord = 2.0 * textureCoordinate - 1.0;
     vec2 normCenter = 2.0 * center - 1.0;
     
     normCoord -= normCenter;
     
     float r = length(normCoord); // to polar coords
     float phi = atan(normCoord.y, normCoord.x); // to polar coords
     
     r = r - mod(r, pixelSize.x) + 0.03;
     phi = phi - mod(phi, pixelSize.y);
     
     normCoord.x = r * cos(phi);
     normCoord.y = r * sin(phi);
     
     normCoord += normCenter;
     
     vec2 textureCoordinateToUse = normCoord / 2.0 + 0.5;
     
     gl_FragColor = texture2D(inputImageTexture, textureCoordinateToUse );
     
 }
);
#endif


@implementation GPUImagePolarPixellateFilter

@synthesize center = _center;

@synthesize pixelSize = _pixelSize;

#pragma mark -
#pragma mark Initialization and teardown

- (id)init;
{
    if (!(self = [super initWithFragmentShaderFromString:kGPUImagePolarPixellateFragmentShaderString]))
    {
		return nil;
    }
    
    pixelSizeUniform = [self.filterProgram uniformIndex:@"pixelSize"];
    centerUniform = [self.filterProgram uniformIndex:@"center"];
    
    
    self.pixelSize = CGSizeMake(0.05, 0.05);
    self.center = CGPointMake(0.5, 0.5);
    
    return self;
}

#pragma mark - Accessors

- (void)setInputRotation:(GPUImageRotationMode)value index:(NSUInteger)index {
    [super setInputRotation:value index:index];
    [self setCenter:self.center];
}

- (void)setPixelSize:(CGSize)pixelSize 
{
    _pixelSize = pixelSize;
    
    [self setSize:_pixelSize forUniform:pixelSizeUniform program:self.filterProgram];
}

- (void)setCenter:(CGPoint)newValue {
    _center = newValue;
    [self setPoint:rotatedPoint(_center, [self getInputRotation:0]) forUniform:centerUniform program:self.filterProgram];
}

@end
