#import "GPUImageGaussianBlurFilter.h"

@interface GPUImageBilateralFilter : GPUImageGaussianBlurFilter
{
    GLfloat firstDistanceNormalizationFactorUniform;
    GLfloat secondDistanceNormalizationFactorUniform;
}
// A normalization factor for the distance between central color and sample color.
@property(nonatomic, readwrite) GLfloat distanceNormalizationFactor;
@end
