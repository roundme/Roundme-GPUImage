#import "GPUImageGaussianBlurPositionFilter.h"

NSString *const kGPUImageGaussianBlurPositionVertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 
 const int GAUSSIAN_SAMPLES = 9;
 
 uniform float texelWidthOffset;
 uniform float texelHeightOffset;
 varying vec2 textureCoordinate;
 varying vec2 blurCoordinates[GAUSSIAN_SAMPLES];
 
 void main()
 {
 	gl_Position = position;
 	textureCoordinate = inputTextureCoordinate.xy;
 	
 	// Calculate the positions for the blur
 	int multiplier = 0;
 	vec2 blurStep;
    vec2 singleStepOffset = vec2(texelWidthOffset, texelHeightOffset);
     
 	for (int i = 0; i < GAUSSIAN_SAMPLES; i++) {
 		multiplier = (i - ((GAUSSIAN_SAMPLES - 1) / 2));
        // Blur in x (horizontal)
        blurStep = float(multiplier) * singleStepOffset;
 		blurCoordinates[i] = inputTextureCoordinate.xy + blurStep;
 	}
 }
);

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
NSString *const kGPUImageGaussianBlurPositionFragmentShaderString = SHADER_STRING
(
 uniform sampler2D inputImageTexture;
 
 const lowp int GAUSSIAN_SAMPLES = 9;
 
 varying highp vec2 textureCoordinate;
 varying highp vec2 blurCoordinates[GAUSSIAN_SAMPLES];

 uniform highp float aspectRatio;
 uniform lowp vec2 blurCenter;
 uniform highp float blurRadius;
 
 void main() {
     highp vec2 textureCoordinateToUse = vec2(textureCoordinate.x, (textureCoordinate.y * aspectRatio + 0.5 - 0.5 * aspectRatio));
     highp float dist = distance(blurCenter, textureCoordinateToUse);

     if (dist < blurRadius)
     {
        lowp vec4 sum = vec4(0.0);
        
         sum += texture2D(inputImageTexture, blurCoordinates[0]) * 0.05;
         sum += texture2D(inputImageTexture, blurCoordinates[1]) * 0.09;
         sum += texture2D(inputImageTexture, blurCoordinates[2]) * 0.12;
         sum += texture2D(inputImageTexture, blurCoordinates[3]) * 0.15;
         sum += texture2D(inputImageTexture, blurCoordinates[4]) * 0.18;
         sum += texture2D(inputImageTexture, blurCoordinates[5]) * 0.15;
         sum += texture2D(inputImageTexture, blurCoordinates[6]) * 0.12;
         sum += texture2D(inputImageTexture, blurCoordinates[7]) * 0.09;
         sum += texture2D(inputImageTexture, blurCoordinates[8]) * 0.05;

        gl_FragColor = sum;
     }
     else
     {
         gl_FragColor = texture2D(inputImageTexture, textureCoordinate);
     }
 }
);
#else
NSString *const kGPUImageGaussianBlurPositionFragmentShaderString = SHADER_STRING
(
 uniform sampler2D inputImageTexture;
 
 const int GAUSSIAN_SAMPLES = 9;
 
 varying vec2 textureCoordinate;
 varying vec2 blurCoordinates[GAUSSIAN_SAMPLES];
 
 uniform float aspectRatio;
 uniform vec2 blurCenter;
 uniform float blurRadius;
 
 void main()
 {
     vec2 textureCoordinateToUse = vec2(textureCoordinate.x, (textureCoordinate.y * aspectRatio + 0.5 - 0.5 * aspectRatio));
     float dist = distance(blurCenter, textureCoordinateToUse);
     
     if (dist < blurRadius)
     {
         vec4 sum = vec4(0.0);
         
         sum += texture2D(inputImageTexture, blurCoordinates[0]) * 0.05;
         sum += texture2D(inputImageTexture, blurCoordinates[1]) * 0.09;
         sum += texture2D(inputImageTexture, blurCoordinates[2]) * 0.12;
         sum += texture2D(inputImageTexture, blurCoordinates[3]) * 0.15;
         sum += texture2D(inputImageTexture, blurCoordinates[4]) * 0.18;
         sum += texture2D(inputImageTexture, blurCoordinates[5]) * 0.15;
         sum += texture2D(inputImageTexture, blurCoordinates[6]) * 0.12;
         sum += texture2D(inputImageTexture, blurCoordinates[7]) * 0.09;
         sum += texture2D(inputImageTexture, blurCoordinates[8]) * 0.05;
         
         gl_FragColor = sum;
     }
     else
     {
         gl_FragColor = texture2D(inputImageTexture, textureCoordinate);
     }
 }
);
#endif

@interface GPUImageGaussianBlurPositionFilter ()

@property (readwrite, nonatomic) GLfloat aspectRatio;

@end

@implementation GPUImageGaussianBlurPositionFilter

- (id) initWithFirstStageVertexShaderFromString:(NSString *)firstStageVertexShaderString 
             firstStageFragmentShaderFromString:(NSString *)firstStageFragmentShaderString 
              secondStageVertexShaderFromString:(NSString *)secondStageVertexShaderString
            secondStageFragmentShaderFromString:(NSString *)secondStageFragmentShaderString {
    
    if (!(self = [super initWithFirstStageVertexShaderFromString:firstStageVertexShaderString ? firstStageVertexShaderString : kGPUImageGaussianBlurPositionVertexShaderString
                              firstStageFragmentShaderFromString:firstStageFragmentShaderString ? firstStageFragmentShaderString : kGPUImageGaussianBlurPositionFragmentShaderString
                               secondStageVertexShaderFromString:secondStageVertexShaderString ? secondStageVertexShaderString : kGPUImageGaussianBlurPositionVertexShaderString
                             secondStageFragmentShaderFromString:secondStageFragmentShaderString ? secondStageFragmentShaderString : kGPUImageGaussianBlurPositionFragmentShaderString])) {
        return nil;
    }
    
    aspectRatioUniform = [secondFilterProgram uniformIndex:@"aspectRatio"];
    blurCenterUniform = [secondFilterProgram uniformIndex:@"blurCenter"];
    blurRadiusUniform = [secondFilterProgram uniformIndex:@"blurRadius"];

    self.blurSize = 1.0;
    self.blurRadius = 1.0;
    self.blurCenter = CGPointMake(0.5, 0.5);
    
    return self;
}

- (id)init;
{
    return [self initWithFirstStageVertexShaderFromString:nil
                       firstStageFragmentShaderFromString:nil
                        secondStageVertexShaderFromString:nil
                      secondStageFragmentShaderFromString:nil];
}

- (void)setInputRotation:(GPUImageRotationMode)value index:(NSUInteger)index {
    [super setInputRotation:value index:index];
    [self setBlurCenter:self.blurCenter];    
}

#pragma mark - Accessors

- (void)setBlurSize:(GLfloat)newValue;
{
    _blurSize = newValue;
    
    _verticalTexelSpacing = _blurSize;
    _horizontalTexelSpacing = _blurSize;
    
    [self setupFilterForSize:[self sizeOfFBO]];
}

- (void) setBlurCenter:(CGPoint)blurCenter {
    _blurCenter = blurCenter;
    [self setPoint:rotatedPoint(blurCenter, [self getInputRotation:0]) forUniform:blurCenterUniform program:secondFilterProgram];
}

- (void) setBlurRadius:(GLfloat)blurRadius;
{
    _blurRadius = blurRadius;

    [self setFloat:_blurRadius forUniform:blurRadiusUniform program:secondFilterProgram];
}

- (void) setAspectRatio:(GLfloat)newValue {
//    _aspectRatio = newValue;
//
//    [self setFloat:_aspectRatio forUniform:aspectRatioUniform program:secondFilterProgram];
    [self setFloat:newValue forUniform:aspectRatioUniform program:secondFilterProgram];
}

@end
