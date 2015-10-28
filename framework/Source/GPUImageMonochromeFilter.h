#import "GPUImageFilter.h"

@interface GPUImageMonochromeFilter : GPUImageFilter
{
    GLint intensityUniform, filterColorUniform;
}

@property(readwrite, nonatomic) GLfloat intensity;
@property(readwrite, nonatomic) GPUVector4 color;

- (void)setColorRed:(GLfloat)redComponent green:(GLfloat)greenComponent blue:(GLfloat)blueComponent;

@end
