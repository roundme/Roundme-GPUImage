#import "GPUImageVignetteFilter.h"

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
NSString *const kGPUImageVignetteFragmentShaderString = SHADER_STRING
(
 uniform sampler2D inputImageTexture;
 varying highp vec2 textureCoordinate;
 
 uniform lowp vec2 vignetteCenter;
 uniform lowp vec3 vignetteColor;
 uniform highp float vignetteStart;
 uniform highp float vignetteEnd;
 
 void main()
 {
     lowp vec4 sourceImageColor = texture2D(inputImageTexture, textureCoordinate);
     lowp float d = distance(textureCoordinate, vec2(vignetteCenter.x, vignetteCenter.y));
     lowp float percent = smoothstep(vignetteStart, vignetteEnd, d);
     gl_FragColor = vec4(mix(sourceImageColor.rgb, vignetteColor, percent), sourceImageColor.a);
 }
);
#else
NSString *const kGPUImageVignetteFragmentShaderString = SHADER_STRING
(
 uniform sampler2D inputImageTexture;
 varying vec2 textureCoordinate;
 
 uniform vec2 vignetteCenter;
 uniform vec3 vignetteColor;
 uniform float vignetteStart;
 uniform float vignetteEnd;
 
 void main()
 {
     vec4 sourceImageColor = texture2D(inputImageTexture, textureCoordinate);
     float d = distance(textureCoordinate, vec2(vignetteCenter.x, vignetteCenter.y));
     float percent = smoothstep(vignetteStart, vignetteEnd, d);
     gl_FragColor = vec4(mix(sourceImageColor.rgb, vignetteColor, percent), sourceImageColor.a);
 }
);
#endif

@implementation GPUImageVignetteFilter

@synthesize vignetteCenter = _vignetteCenter;
@synthesize vignetteColor = _vignetteColor;
@synthesize vignetteStart =_vignetteStart;
@synthesize vignetteEnd = _vignetteEnd;

#pragma mark -
#pragma mark Initialization and teardown

- (id)init;
{
    if (!(self = [super initWithFragmentShaderFromString:kGPUImageVignetteFragmentShaderString]))
    {
		return nil;
    }
    
    vignetteCenterUniform = [self.filterProgram uniformIndex:@"vignetteCenter"];
    vignetteColorUniform = [self.filterProgram uniformIndex:@"vignetteColor"];
    vignetteStartUniform = [self.filterProgram uniformIndex:@"vignetteStart"];
    vignetteEndUniform = [self.filterProgram uniformIndex:@"vignetteEnd"];
    
    self.vignetteCenter = (CGPoint){ 0.5f, 0.5f };
    self.vignetteColor = (GPUVector3){ 0.0f, 0.0f, 0.0f };
    self.vignetteStart = 0.3;
    self.vignetteEnd = 0.75;
    
    return self;
}

#pragma mark -
#pragma mark Accessors

- (void)setVignetteCenter:(CGPoint)newValue
{
    _vignetteCenter = newValue;
    
    [self setPoint:newValue forUniform:vignetteCenterUniform program:self.filterProgram];
}

- (void)setVignetteColor:(GPUVector3)newValue
{
    _vignetteColor = newValue;
    
    [self setVec3:newValue forUniform:vignetteColorUniform program:self.filterProgram];
}

- (void)setVignetteStart:(GLfloat)newValue;
{
    _vignetteStart = newValue;
    
    [self setFloat:_vignetteStart forUniform:vignetteStartUniform program:self.filterProgram];
}

- (void)setVignetteEnd:(GLfloat)newValue;
{
    _vignetteEnd = newValue;

    [self setFloat:_vignetteEnd forUniform:vignetteEndUniform program:self.filterProgram];
}

@end
