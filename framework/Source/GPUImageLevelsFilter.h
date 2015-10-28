#import "GPUImageFilter.h"

/**
 * Levels like Photoshop.
 *
 * The min, max, minOut and maxOut parameters are floats in the range [0, 1].
 * If you have parameters from Photoshop in the range [0, 255] you must first
 * convert them to be [0, 1].
 * The gamma/mid parameter is a float >= 0. This matches the value from Photoshop.
 *
 * If you want to apply levels to RGB as well as individual channels you need to use
 * this filter twice - first for the individual channels and then for all channels.
 */
@interface GPUImageLevelsFilter : GPUImageFilter
{
    GLint minUniform;
    GLint midUniform;
    GLint maxUniform;
    GLint minOutputUniform;
    GLint maxOutputUniform;
    
    GPUVector3 minVector, midVector, maxVector, minOutputVector, maxOutputVector;
}

/** Set levels for the red channel */
- (void)setRedMin:(GLfloat)min gamma:(GLfloat)mid max:(GLfloat)max minOut:(GLfloat)minOut maxOut:(GLfloat)maxOut;

- (void)setRedMin:(GLfloat)min gamma:(GLfloat)mid max:(GLfloat)max;

/** Set levels for the green channel */
- (void)setGreenMin:(GLfloat)min gamma:(GLfloat)mid max:(GLfloat)max minOut:(GLfloat)minOut maxOut:(GLfloat)maxOut;

- (void)setGreenMin:(GLfloat)min gamma:(GLfloat)mid max:(GLfloat)max;

/** Set levels for the blue channel */
- (void)setBlueMin:(GLfloat)min gamma:(GLfloat)mid max:(GLfloat)max minOut:(GLfloat)minOut maxOut:(GLfloat)maxOut;

- (void)setBlueMin:(GLfloat)min gamma:(GLfloat)mid max:(GLfloat)max;

/** Set levels for all channels at once */
- (void)setMin:(GLfloat)min gamma:(GLfloat)mid max:(GLfloat)max minOut:(GLfloat)minOut maxOut:(GLfloat)maxOut;
- (void)setMin:(GLfloat)min gamma:(GLfloat)mid max:(GLfloat)max;

@end

