#import "GPUImageFilter.h"

@interface GPUImageRGBFilter : GPUImageFilter
{
    GLint redUniform;
    GLint greenUniform;
    GLint blueUniform;
}

// Normalized values by which each color channel is multiplied. The range is from 0.0 up, with 1.0 as the default.
@property (readwrite, nonatomic) GLfloat red; 
@property (readwrite, nonatomic) GLfloat green; 
@property (readwrite, nonatomic) GLfloat blue;

@end
