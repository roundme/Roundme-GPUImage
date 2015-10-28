
#import "GPUImageFilter.h"

@interface GPUImageHueFilter : GPUImageFilter
{
    GLint hueAdjustUniform;
    
}
@property (nonatomic, readwrite) GLfloat hue;

@end
