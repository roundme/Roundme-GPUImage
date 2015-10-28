#import "GPUImageFilter.h"

@interface GPUImageMotionBlurFilter : GPUImageFilter

/** A multiplier for the blur size, ranging from 0.0 on up, with a default of 1.0
 */
@property (readwrite, nonatomic) GLfloat blurSize;

/** The angular direction of the blur, in degrees. 0 degrees by default
 */
@property (readwrite, nonatomic) GLfloat blurAngle;

@end
