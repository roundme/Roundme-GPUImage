#import "GPUImageFilter.h"

@interface GPUImageColorPackingFilter : GPUImageFilter
{
    GLint texelWidthUniform, texelHeightUniform;
    
    GLfloat texelWidth, texelHeight;
}

@end
