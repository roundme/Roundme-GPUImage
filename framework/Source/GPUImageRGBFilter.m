#import "GPUImageRGBFilter.h"

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
NSString *const kGPUImageRGBFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 uniform highp float redAdjustment;
 uniform highp float greenAdjustment;
 uniform highp float blueAdjustment;
 
 void main()
 {
     highp vec4 textureColor = texture2D(inputImageTexture, textureCoordinate);
     
     gl_FragColor = vec4(textureColor.r * redAdjustment, textureColor.g * greenAdjustment, textureColor.b * blueAdjustment, textureColor.a);
 }
);
#else
NSString *const kGPUImageRGBFragmentShaderString = SHADER_STRING
(
 varying vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 uniform float redAdjustment;
 uniform float greenAdjustment;
 uniform float blueAdjustment;
 
 void main()
 {
     vec4 textureColor = texture2D(inputImageTexture, textureCoordinate);
     
     gl_FragColor = vec4(textureColor.r * redAdjustment, textureColor.g * greenAdjustment, textureColor.b * blueAdjustment, textureColor.a);
 }
 );
#endif

@implementation GPUImageRGBFilter

@synthesize red = _red, blue = _blue, green = _green;

#pragma mark -
#pragma mark Initialization and teardown

- (id)init;
{
    if (!(self = [super initWithFragmentShaderFromString:kGPUImageRGBFragmentShaderString]))
    {
		return nil;
    }
    
    redUniform = [self.filterProgram uniformIndex:@"redAdjustment"];
    self.red = 1.0;
    
    greenUniform = [self.filterProgram uniformIndex:@"greenAdjustment"];
    self.green = 1.0;
    
    blueUniform = [self.filterProgram uniformIndex:@"blueAdjustment"];
    self.blue = 1.0;
    
    return self;
}

#pragma mark -
#pragma mark Accessors

- (void)setRed:(GLfloat)newValue;
{
    _red = newValue;
    
    [self setFloat:_red forUniform:redUniform program:self.filterProgram];
}

- (void)setGreen:(GLfloat)newValue;
{
    _green = newValue;

    [self setFloat:_green forUniform:greenUniform program:self.filterProgram];
}

- (void)setBlue:(GLfloat)newValue;
{
    _blue = newValue;

    [self setFloat:_blue forUniform:blueUniform program:self.filterProgram];
}

@end