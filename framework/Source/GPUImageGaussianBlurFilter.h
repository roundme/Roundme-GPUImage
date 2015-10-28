#import "GPUImageTwoPassTextureSamplingFilter.h"

/** A Gaussian blur filter
    Interpolated optimization based on Daniel Rákos' work at http://rastergrid.com/blog/2010/09/efficient-gaussian-blur-with-linear-sampling/
 */

@interface GPUImageGaussianBlurFilter : GPUImageTwoPassTextureSamplingFilter 
{
    BOOL shouldResizeBlurRadiusWithImageSize;
    GLfloat _blurRadiusInPixels;
}

/** A multiplier for the spacing between texels, ranging from 0.0 on up, with a default of 1.0. Adjusting this may slightly increase the blur strength, but will introduce artifacts in the result.
 */
@property (readwrite, nonatomic) GLfloat texelSpacingMultiplier;

/** A radius in pixels to use for the blur, with a default of 2.0. This adjusts the sigma variable in the Gaussian distribution function.
 */
@property (readwrite, nonatomic) GLfloat blurRadiusInPixels;

/** Setting these properties will allow the blur radius to scale with the size of the image
 */
@property (readwrite, nonatomic) GLfloat blurRadiusAsFractionOfImageWidth;
@property (readwrite, nonatomic) GLfloat blurRadiusAsFractionOfImageHeight;

/// The number of times to sequentially blur the incoming image. The more passes, the slower the filter.
@property(readwrite, nonatomic) NSUInteger blurPasses;

+ (NSString *)vertexShaderForStandardBlurOfRadius:(NSUInteger)blurRadius sigma:(GLfloat)sigma;
+ (NSString *)fragmentShaderForStandardBlurOfRadius:(NSUInteger)blurRadius sigma:(GLfloat)sigma;
+ (NSString *)vertexShaderForOptimizedBlurOfRadius:(NSUInteger)blurRadius sigma:(GLfloat)sigma;
+ (NSString *)fragmentShaderForOptimizedBlurOfRadius:(NSUInteger)blurRadius sigma:(GLfloat)sigma;

- (void)switchToVertexShader:(NSString *)newVertexShader fragmentShader:(NSString *)newFragmentShader;

@end
