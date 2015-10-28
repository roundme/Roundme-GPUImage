#import "GPUImageFilter.h"

@interface GPUImageCrosshatchFilter : GPUImageFilter
{
    GLint crossHatchSpacingUniform, lineWidthUniform;
}
// The fractional width of the image to use as the spacing for the crosshatch. The default is 0.03.
@property(readwrite, nonatomic) GLfloat crossHatchSpacing;

// A relative width for the crosshatch lines. The default is 0.003.
@property(readwrite, nonatomic) GLfloat lineWidth;

@end
