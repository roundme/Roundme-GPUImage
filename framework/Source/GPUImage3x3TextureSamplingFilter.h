#import "GPUImageFilter.h"

extern NSString *const kGPUImageNearbyTexelSamplingVertexShaderString;

@interface GPUImage3x3TextureSamplingFilter : GPUImageFilter
{
    GLint texelWidthUniform, texelHeightUniform;
    
    GLfloat texelWidth, texelHeight;
    BOOL hasOverriddenImageSizeFactor;
}

// The texel width and height determines how far out to sample from this texel. By default, this is the normalized width of a pixel, but this can be overridden for different effects.
@property(readwrite, nonatomic) GLfloat texelWidth;
@property(readwrite, nonatomic) GLfloat texelHeight; 


@end
